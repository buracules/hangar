import Foundation

// MARK: - Failure

extension CLI {
  /// Why a command could not run.
  enum Failure: LocalizedError, Equatable {
    /// The command was used wrongly; the message says how to use it.
    case usage(String)

    var errorDescription: String? {
      switch self {
      case .usage(let message): message
      }
    }
  }
}
