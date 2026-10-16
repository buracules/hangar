import Foundation

// MARK: - Project

extension MachineStatus {
  /// A project run's status.
  init(_ state: ProjectRun.State) {
    switch state {
    case .stopped: self.init(kind: .stopped, word: "Stopped")
    case .starting: self.init(kind: .busy, word: "Starting")
    case .running: self.init(kind: .running, word: "Running")
    case .unhealthy: self.init(kind: .unhealthy, word: "Unhealthy")
    case .stopping: self.init(kind: .busy, word: "Stopping")
    case .crashed: self.init(kind: .error, word: "Crashed")
    case .failed: self.init(kind: .error, word: "Couldn't start")
    }
  }
}
