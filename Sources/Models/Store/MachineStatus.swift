import Foundation

private enum Constants {
  static let running = "Running"
  static let paused = "Paused"
  static let stopped = "Stopped"
  static let exited = "Exited"
  static let unhealthy = "Unhealthy"
  static let starting = "Starting"
  static let restarting = "Restarting"
  static let created = "Created"
  static let removing = "Removing"
  static let dead = "Dead"
}

/// The status language every screen shares: each state has a shape, a colour and a word.
struct MachineStatus: Equatable, Sendable {
  /// Which of the six shapes and colours a status uses.
  enum Kind: Equatable, Sendable {
    /// ● Up and well.
    case running
    /// ◐ Suspended or paused.
    case paused
    /// ◌ Starting, stopping, restarting — on its way somewhere.
    case busy
    /// ○ Down, as intended.
    case stopped
    /// ✕ Crashed: exited with an error, or dead.
    case error
    /// ▲ Running but failing its health check.
    case unhealthy
  }

  let kind: Kind
  /// What the status is called on screen: "Running", "Exited", "Starting" …
  let word: String

  /// A VM's status from utmctl's word.
  init(_ vm: VirtualMachine) {
    switch true {
    case vm.isRunning: self.init(kind: .running, word: Constants.running)
    case vm.isPaused: self.init(kind: .paused, word: Constants.paused)
    case vm.isTransitioning: self.init(kind: .busy, word: vm.status.capitalized)
    default: self.init(kind: .stopped, word: Constants.stopped)
    }
  }

  /// A container's status from its state, health check and exit code.
  init(_ container: Container) {
    switch container.state {
    case "running": self = Self.running(health: container.health)
    case "paused": self.init(kind: .paused, word: Constants.paused)
    case "restarting": self.init(kind: .busy, word: Constants.restarting)
    case "removing": self.init(kind: .busy, word: Constants.removing)
    case "created": self.init(kind: .stopped, word: Constants.created)
    case "dead": self.init(kind: .error, word: Constants.dead)
    default:
      if (container.exitCode ?? 0) != 0 {
        self.init(kind: .error, word: Constants.exited)
      } else {
        self.init(kind: .stopped, word: Constants.stopped)
      }
    }
  }

  init(kind: Kind, word: String) {
    self.kind = kind
    self.word = word
  }

  /// A running container is only as well as its health check says.
  private static func running(health: Container.Health?) -> MachineStatus {
    switch health {
    case .unhealthy: MachineStatus(kind: .unhealthy, word: Constants.unhealthy)
    case .starting: MachineStatus(kind: .busy, word: Constants.starting)
    case .healthy, nil: MachineStatus(kind: .running, word: Constants.running)
    }
  }
}
