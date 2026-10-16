import Foundation

private enum Constants {
  static let fromHangar = "from Hangar"
}

// MARK: - Activity

extension HangarStore {
  /// Why Hangar acted, as the timeline says it: "from Hangar", "by profile work".
  enum Cause {
    static let hangar = Constants.fromHangar
    static let cli = "from the CLI"
    static func profile(_ name: String) -> String { "by profile \(name)" }
  }

  /// Records a status change noticed on refresh, unless an action already explains it.
  /// The very first refresh only takes note of where everything stands.
  func noteStatusChanges() {
    let current = Dictionary(
      vms.map { ($0.id, MachineStatus($0)) } + containers.map { ($0.id, $0.machineStatus) }
    ) { first, _ in first }
    defer { lastStatusKinds = current.mapValues(\.kind) }
    guard !lastStatusKinds.isEmpty else { return }
    for (id, status) in current {
      guard let previous = lastStatusKinds[id], previous != status.kind,
        let event = observedEvent(to: status, isVM: vms.contains { $0.id == id }, id: id)
      else { continue }
      activity.observe(id, outcome: event.outcome, title: event.title, detail: event.detail)
    }
  }

  /// How a change reads in the timeline; nil for passing states like starting.
  private func observedEvent(to status: MachineStatus, isVM: Bool, id: String) -> ActivityEvent? {
    let event = { (outcome: ActivityEvent.Outcome, title: String, detail: String?) in
      ActivityEvent(date: .now, outcome: outcome, title: title, detail: detail)
    }
    switch status.kind {
    case .running: return event(.running, "Started", nil)
    case .paused: return event(.paused, isVM ? "Suspended" : "Paused", nil)
    case .stopped: return event(.stopped, isVM ? "Shut down" : "Stopped", nil)
    case .error:
      let code = containers.first { $0.id == id }?.exitCode.map { "code \($0)" }
      return event(.error, status.word, code)
    case .unhealthy: return event(.error, "Became unhealthy", "failing its health check")
    case .busy: return nil
    }
  }
}
