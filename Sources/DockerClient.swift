import Darwin
import Foundation

struct Container: Identifiable, Decodable, Sendable, Hashable {
    struct Port: Decodable, Sendable, Hashable {
        let publicPort: Int?
        let privatePort: Int
        let type: String

        enum CodingKeys: String, CodingKey {
            case publicPort = "PublicPort", privatePort = "PrivatePort", type = "Type"
        }
    }

    let id: String
    let names: [String]
    let image: String
    let state: String
    let status: String
    let labels: [String: String]?
    /// Null, not empty, when the container publishes nothing.
    let ports: [Port]?

    enum CodingKeys: String, CodingKey {
        case id = "Id", names = "Names", image = "Image", state = "State"
        case status = "Status", labels = "Labels", ports = "Ports"
    }

    var name: String {
        names.first.map { String($0.drop(while: { $0 == "/" })) } ?? String(id.prefix(12))
    }

    var composeProject: String? { labels?["com.docker.compose.project"] }
    var composeService: String? { labels?["com.docker.compose.service"] }
    var displayName: String { composeService ?? name }
    var isRunning: Bool { state == "running" }

    /// Host ports published as TCP, deduplicated (Docker lists IPv4 and IPv6 separately).
    var publishedPorts: [Int] {
        Array(Set((ports ?? []).filter { $0.type == "tcp" }.compactMap(\.publicPort))).sorted()
    }
}

enum DockerError: LocalizedError {
    case socket(Int32), connect(String, Int32), io(Int32), badResponse, http(Int, String)

    var errorDescription: String? {
        switch self {
        case .socket(let e): "socket: \(String(cString: strerror(e)))"
        case .connect(let path, let e): "\(path): \(String(cString: strerror(e)))"
        case .io(let e): "io: \(String(cString: strerror(e)))"
        case .badResponse: "Docker returned an unreadable response"
        case .http(let code, let body): "Docker \(code): \(body)"
        }
    }
}

/// Talks to the Docker Engine API over its unix socket. Requests are HTTP/1.0 so the
/// daemon answers with a plain, unchunked body and closes the connection.
struct DockerClient: Sendable {
    let socketPath: String

    static func detect() -> DockerClient? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates: [String] = []
        if let host = ProcessInfo.processInfo.environment["DOCKER_HOST"], host.hasPrefix("unix://") {
            candidates.append(String(host.dropFirst("unix://".count)))
        }
        candidates += [
            "\(home)/.docker/run/docker.sock",
            "\(home)/.orbstack/run/docker.sock",
            "\(home)/.colima/default/docker.sock",
            "/var/run/docker.sock",
        ]
        return candidates
            .first { FileManager.default.fileExists(atPath: $0) }
            .map(DockerClient.init(socketPath:))
    }

    func containers() async throws -> [Container] {
        let data = try await request("GET", "/containers/json?all=true")
        return try JSONDecoder().decode([Container].self, from: data)
    }

    func start(_ id: String) async throws { try await request("POST", "/containers/\(id)/start") }
    func stop(_ id: String) async throws { try await request("POST", "/containers/\(id)/stop?t=10") }
    func restart(_ id: String) async throws { try await request("POST", "/containers/\(id)/restart?t=10") }

    @discardableResult
    private func request(_ method: String, _ path: String) async throws -> Data {
        let socketPath = socketPath
        let (code, body) = try await Task.detached {
            try Self.send(socketPath: socketPath, method: method, path: path)
        }.value
        // 304 is "already started/stopped", which is the state the caller asked for.
        guard (200..<300).contains(code) || code == 304 else {
            let message = (try? JSONDecoder().decode([String: String].self, from: body))?["message"]
            throw DockerError.http(code, message ?? String(decoding: body, as: UTF8.self))
        }
        return body
    }

    private static func send(socketPath: String, method: String, path: String) throws -> (Int, Data) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw DockerError.socket(errno) }
        defer { close(fd) }

        // Stop and restart wait up to t=10s for the container, so leave headroom.
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw DockerError.connect(socketPath, ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes)
            buffer[pathBytes.count] = 0
        }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw DockerError.connect(socketPath, errno) }

        let request = Array("\(method) \(path) HTTP/1.0\r\nHost: docker\r\nContent-Length: 0\r\n\r\n".utf8)
        var sent = 0
        while sent < request.count {
            let n = request[sent...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            guard n > 0 else { throw DockerError.io(errno) }
            sent += n
        }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = read(fd, &buffer, buffer.count)
            if n < 0 { throw DockerError.io(errno) }
            if n == 0 { break }
            response.append(buffer, count: n)
        }

        guard let split = response.range(of: Data("\r\n\r\n".utf8)) else { throw DockerError.badResponse }
        let statusLine = String(decoding: response[..<split.lowerBound], as: UTF8.self)
            .split(separator: "\r\n").first ?? ""
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let code = Int(parts[1]) else { throw DockerError.badResponse }
        return (code, Data(response[split.upperBound...]))
    }
}
