import Foundation

private enum Constants {
  static let dockerHostVariable = "DOCKER_HOST"
  static let unixScheme = "unix://"
  /// Where Docker Desktop, OrbStack and Colima put their sockets, relative to home, tried
  /// in this order after DOCKER_HOST.
  static let homeSocketPaths = [
    ".docker/run/docker.sock",
    ".orbstack/run/docker.sock",
    ".colima/default/docker.sock",
  ]
  static let systemSocketPath = "/var/run/docker.sock"
  /// Seconds stop and restart give a container before killing it, Docker's own default.
  static let stopGraceSeconds = 10
  static let defaultLogTail = 500
  /// Leaves headroom for stop and restart, which wait up to `stopGraceSeconds`.
  static let requestTimeoutSeconds = 30
  static let successCodes = 200..<300
  /// "Already started/stopped" — the state the caller asked for.
  static let notModified = 304
}

/// Talks to the Docker Engine API over its unix socket.
struct DockerClient: Sendable {
  let socketPath: String

  /// The first socket that exists: DOCKER_HOST, then the usual Docker Desktop, OrbStack and
  /// Colima locations, then the system one.
  static func detect() -> DockerClient? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    var candidates: [String] = []
    if let host = ProcessInfo.processInfo.environment[Constants.dockerHostVariable],
      host.hasPrefix(Constants.unixScheme)
    {
      candidates.append(String(host.dropFirst(Constants.unixScheme.count)))
    }
    candidates += Constants.homeSocketPaths.map { "\(home)/\($0)" }
    candidates.append(Constants.systemSocketPath)
    return
      candidates
      .first { FileManager.default.fileExists(atPath: $0) }
      .map(DockerClient.init(socketPath:))
  }

  /// Every container, running or not.
  func containers() async throws -> [Container] {
    let data = try await request("GET", "/containers/json?all=true")
    return try JSONDecoder.docker.decode([Container].self, from: data)
  }

  func start(_ id: String) async throws {
    try await request("POST", "/containers/\(id)/start")
  }

  func stop(_ id: String) async throws {
    try await request("POST", "/containers/\(id)/stop?t=\(Constants.stopGraceSeconds)")
  }

  func restart(_ id: String) async throws {
    try await request("POST", "/containers/\(id)/restart?t=\(Constants.stopGraceSeconds)")
  }

  /// A container's output: the last `tail` lines, then — when following — everything new
  /// until the container stops or the consumer cancels. Docker prefixes every line with its
  /// time; `LogDecoder` turns the raw bytes into lines.
  func logs(
    _ id: String,
    tail: Int = Constants.defaultLogTail,
    follow: Bool = true
  ) -> AsyncThrowingStream<Data, Error> {
    let query = "stdout=1&stderr=1&timestamps=1&follow=\(follow ? 1 : 0)&tail=\(tail)"
    return stream("/containers/\(id)/logs?\(query)")
  }

  /// The container's environment, which is where database images keep their credentials.
  func environment(_ id: String) async throws -> [String: String] {
    let data = try await request("GET", "/containers/\(id)/json")
    let entries = try JSONDecoder.docker.decode(ContainerInspect.self, from: data).config.env ?? []
    let pairs = entries.compactMap { entry in
      entry.firstIndex(of: "=")
        .map {
          (String(entry[..<$0]), String(entry[entry.index(after: $0)...]))
        }
    }
    return Dictionary(pairs) { _, last in last }
  }

  /// One request and its whole response body; non-2xx answers throw.
  @discardableResult
  func request(
    _ method: String,
    _ path: String,
    body: Data? = nil,
    timeoutSeconds: Int = Constants.requestTimeoutSeconds
  ) async throws -> Data {
    let socketPath = socketPath
    let (code, responseBody) =
      try await Task.detached {
        try DockerSocket.send(
          socketPath: socketPath,
          method: method,
          path: path,
          body: body,
          timeoutSeconds: timeoutSeconds
        )
      }
      .value
    guard Constants.successCodes.contains(code) || code == Constants.notModified else {
      throw Failure.http(code: code, body: responseBody)
    }
    return responseBody
  }
}

/// The part of `GET /containers/{id}/json` Hangar reads.
private struct ContainerInspect: Decodable {
  let config: ContainerConfig
}

/// A container's configuration; `env` holds `NAME=value` entries.
private struct ContainerConfig: Decodable {
  let env: [String]?
}
