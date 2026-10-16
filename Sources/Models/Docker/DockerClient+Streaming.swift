import Darwin
import Foundation

private enum Constants {
  static let ok = 200
  /// Blocks reads indefinitely: a log follow can be quiet for minutes.
  static let noTimeout = 0
}

// MARK: - Streaming

extension DockerClient {
  /// A long-lived GET whose body is yielded as it arrives. It reads on its own thread, since
  /// a follow can block for minutes; cancelling shuts the socket down to unblock the read.
  func stream(_ path: String) -> AsyncThrowingStream<Data, Error> {
    let socketPath = socketPath
    return AsyncThrowingStream { continuation in
      let socket = StreamSocket()
      continuation.onTermination = { _ in socket.shutdown() }
      Thread {
        do {
          let fd = try DockerSocket.connect(
            socketPath: socketPath,
            timeoutSeconds: Constants.noTimeout
          )
          guard socket.adopt(fd) else { return }
          try DockerSocket.writeRequest(fd: fd, method: "GET", path: path)
          try Self.relay(fd: fd, to: continuation)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
        socket.close()
      }
      .start()
    }
  }

  /// Reads the response: once the head shows 200, every body chunk goes to `continuation`;
  /// any other status collects the body and throws it as the error.
  private static func relay(
    fd: Int32,
    to continuation: AsyncThrowingStream<Data, Error>.Continuation
  ) throws {
    var head = Data()
    var code: Int?
    var errorBody = Data()
    var buffer = [UInt8](repeating: 0, count: DockerSocket.readBufferSize)
    while true {
      let count = read(fd, &buffer, buffer.count)
      if count <= 0 { break }
      let chunk = Data(buffer[0..<count])
      if let code {
        if code == Constants.ok { continuation.yield(chunk) } else { errorBody.append(chunk) }
        continue
      }
      head.append(chunk)
      guard let split = DockerSocket.headEnd(in: head) else { continue }
      let parsed = try DockerSocket.statusCode(head[..<split.lowerBound])
      code = parsed
      let rest = Data(head[split.upperBound...])
      if parsed == Constants.ok {
        if !rest.isEmpty { continuation.yield(rest) }
      } else {
        errorBody.append(rest)
      }
    }
    if let code, code != Constants.ok { throw Failure.http(code: code, body: errorBody) }
  }
}
