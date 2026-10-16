import Foundation

// MARK: - Failure

extension PostgresClient {
  /// What can go wrong running psql in a container.
  enum Failure: LocalizedError, Equatable {
    case psqlMissing
    case psqlExited(code: Int)
    /// psql's own message, e.g. `ERROR:  relation "x" does not exist` with its line pointer.
    case psqlError(message: String)

    var errorDescription: String? {
      switch self {
      case .psqlMissing: "psql was not found in this container."
      case .psqlExited(let code): "psql exited with code \(code)."
      case .psqlError(let message): message
      }
    }
  }
}
