import Foundation

// MARK: - Failure

extension HangarStore {
  /// What can go wrong across several machines at once.
  enum Failure: LocalizedError, Equatable {
    case dockerUnreachable
    case dockerMissing
    case couldNotSaveProfiles(reason: String)
    /// Some members of a profile failed; one "name: reason" line each.
    case someMembersFailed([String])

    var errorDescription: String? {
      switch self {
      case .dockerUnreachable: "Docker is not reachable."
      case .dockerMissing: "No Docker socket was found."
      case .couldNotSaveProfiles(let reason): "Could not save profiles: \(reason)"
      case .someMembersFailed(let lines): lines.joined(separator: "\n")
      }
    }
  }
}
