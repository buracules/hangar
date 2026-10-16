import Foundation

private enum Constants {
  static let started = "started"
  static let stopped = "stopped"
  static let paused = "paused"
  static let transitional: Set<String> = ["starting", "pausing", "resuming", "stopping"]
}

/// A UTM virtual machine as `utmctl list` reports it.
struct VirtualMachine: Identifiable, Sendable, Hashable {
  let id: String
  let name: String
  /// utmctl's word: stopped, starting, started, pausing, paused, resuming, stopping.
  let status: String

  /// A VM known to be stopped — every VM is while UTM is closed.
  static func stopped(id: String, name: String) -> VirtualMachine {
    VirtualMachine(id: id, name: name, status: Constants.stopped)
  }

  var isRunning: Bool { status == Constants.started }
  var isStopped: Bool { status == Constants.stopped }
  var isPaused: Bool { status == Constants.paused }
  var isTransitioning: Bool { Constants.transitional.contains(status) }
}
