import Darwin
import Foundation

private enum Constants {
  /// 64 KiB.
  static let readBufferSize = 65_536
  static let headerTerminator = Data("\r\n\r\n".utf8)
  static let lineBreak = "\r\n"
  /// HTTP/1.0 so the daemon answers with a plain, unchunked body and closes the connection.
  static let httpVersion = "HTTP/1.0"
  static let host = "docker"
  static let jsonContentType = "application/json"
  /// "HTTP/1.0 200 OK": the code is the second word.
  static let statusCodeIndex = 1
}

/// Raw HTTP over the Docker unix socket: connect, write a request, read the status line.
enum DockerSocket {
  /// Sends one request and reads the response to the end. Blocks; call it off the main actor.
  static func send(
    socketPath: String,
    method: String,
    path: String,
    body: Data?,
    timeoutSeconds: Int
  ) throws -> (code: Int, body: Data) {
    let fd = try connect(socketPath: socketPath, timeoutSeconds: timeoutSeconds)
    defer { Darwin.close(fd) }
    try writeRequest(fd: fd, method: method, path: path, body: body)

    var response = Data()
    var buffer = [UInt8](repeating: 0, count: Constants.readBufferSize)
    while true {
      let count = read(fd, &buffer, buffer.count)
      if count < 0 { throw DockerClient.Failure.io(errno: errno) }
      if count == 0 { break }
      response.append(buffer, count: count)
    }
    guard let split = response.range(of: Constants.headerTerminator) else {
      throw DockerClient.Failure.badResponse
    }
    return (try statusCode(response[..<split.lowerBound]), Data(response[split.upperBound...]))
  }

  /// A connected socket. `timeoutSeconds` 0 blocks reads indefinitely.
  static func connect(socketPath: String, timeoutSeconds: Int) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw DockerClient.Failure.socket(errno: errno) }
    var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(socketPath.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
      Darwin.close(fd)
      throw DockerClient.Failure.connect(path: socketPath, errno: ENAMETOOLONG)
    }
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
      buffer.copyBytes(from: pathBytes)
      buffer[pathBytes.count] = 0
    }
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard connected == 0 else {
      let code = errno
      Darwin.close(fd)
      throw DockerClient.Failure.connect(path: socketPath, errno: code)
    }
    return fd
  }

  /// Writes the request line, headers and body.
  static func writeRequest(fd: Int32, method: String, path: String, body: Data? = nil) throws {
    var head = [
      "\(method) \(path) \(Constants.httpVersion)",
      "Host: \(Constants.host)",
      "Content-Length: \(body?.count ?? 0)",
    ]
    if body != nil { head.append("Content-Type: \(Constants.jsonContentType)") }
    let terminator = Constants.lineBreak + Constants.lineBreak
    let text = head.joined(separator: Constants.lineBreak) + terminator
    let request = Array(text.utf8) + Array(body ?? Data())
    var sent = 0
    while sent < request.count {
      let count = request[sent...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
      guard count > 0 else { throw DockerClient.Failure.io(errno: errno) }
      sent += count
    }
  }

  /// The status code from the response head.
  static func statusCode(_ head: Data) throws -> Int {
    let text = String(bytes: head, encoding: .utf8) ?? ""
    let statusLine = text.split(separator: Constants.lineBreak).first ?? ""
    let words = statusLine.split(separator: " ")
    guard words.indices.contains(Constants.statusCodeIndex),
      let code = Int(words[Constants.statusCodeIndex])
    else { throw DockerClient.Failure.badResponse }
    return code
  }

  /// Where the response head ends in `data`, if it has arrived.
  static func headEnd(in data: Data) -> Range<Data.Index>? {
    data.range(of: Constants.headerTerminator)
  }

  static let readBufferSize = Constants.readBufferSize
}
