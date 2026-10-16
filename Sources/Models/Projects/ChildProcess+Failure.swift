import Foundation

// MARK: - Failure

extension ChildProcess {
  /// Why a command could not be started.
  enum Failure: LocalizedError {
    case couldNotStart(String)

    var errorDescription: String? {
      switch self {
      case .couldNotStart(let reason): "The command could not be started: \(reason)."
      }
    }
  }
}
