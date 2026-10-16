import Darwin
import Foundation

// MARK: - Failure

extension DockerClient {
  /// What can go wrong talking to the Docker socket.
  enum Failure: LocalizedError {
    case socket(errno: Int32)
    case connect(path: String, errno: Int32)
    case io(errno: Int32)
    case badResponse
    case http(code: Int, message: String)

    /// An HTTP error, with Docker's JSON `message` when the body carries one.
    static func http(code: Int, body: Data) -> Failure {
      let message = (try? JSONDecoder().decode([String: String].self, from: body))?["message"]
      return .http(code: code, message: message ?? String(bytes: body, encoding: .utf8) ?? "")
    }

    var errorDescription: String? {
      switch self {
      case .socket(let code): "Could not open a socket: \(Self.describe(code))."
      case .connect(let path, let code): "Could not connect to \(path): \(Self.describe(code))."
      case .io(let code): "Lost the connection to Docker: \(Self.describe(code))."
      case .badResponse: "Docker returned a response that could not be read."
      case .http(let code, let message): "Docker answered \(code): \(message)"
      }
    }

    private static func describe(_ code: Int32) -> String { String(cString: strerror(code)) }
  }
}
