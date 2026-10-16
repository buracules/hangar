import Foundation

// MARK: - Kind

extension ActivityEvent.Outcome {
  /// The status shape an event draws in the timeline.
  var kind: MachineStatus.Kind {
    switch self {
    case .running: .running
    case .paused: .paused
    case .busy: .busy
    case .stopped: .stopped
    case .error: .error
    }
  }
}
