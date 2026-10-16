import Foundation
import Observation

private enum Constants {
  static let eventsPerMachine = 50
  /// An observed change this soon after a recorded event with the same outcome is the
  /// same happening — the recorded one already says why.
  static let duplicateWindow: TimeInterval = 60
}

/// What happened to each machine, newest first, kept in `activity.json` so the menu bar app
/// and the CLI add to the same history and it survives restarts.
@MainActor
@Observable
final class ActivityLog {
  private(set) var events: [String: [ActivityEvent]]
  private let file: SharedFile<[String: [ActivityEvent]]>

  init(file: SharedFile<[String: [ActivityEvent]]> = SharedFiles.activity) {
    self.file = file
    events = file.load() ?? [:]
  }

  /// The machine's events, newest first.
  func events(for machineID: String) -> [ActivityEvent] { events[machineID] ?? [] }

  /// Records something Hangar did, with who asked: "Started", "by profile work".
  func record(
    _ machineID: String,
    outcome: ActivityEvent.Outcome,
    title: String,
    cause: String? = nil,
    detail: String? = nil,
    at date: Date = .now
  ) {
    let event = ActivityEvent(
      date: date,
      outcome: outcome,
      title: title,
      cause: cause,
      detail: detail
    )
    append(event, to: machineID)
  }

  /// Records a change noticed on refresh, unless a recorded event already covers it.
  func observe(
    _ machineID: String,
    outcome: ActivityEvent.Outcome,
    title: String,
    detail: String? = nil,
    at date: Date = .now
  ) {
    let isCovered = events(for: machineID)
      .contains {
        $0.outcome == outcome && date.timeIntervalSince($0.date) < Constants.duplicateWindow
      }
    guard !isCovered else { return }
    record(machineID, outcome: outcome, title: title, detail: detail, at: date)
  }

  private func append(_ event: ActivityEvent, to machineID: String) {
    // Re-read first: the CLI may have added events since this process last looked.
    var stored = file.load() ?? events
    var list = stored[machineID] ?? []
    list.insert(event, at: 0)
    stored[machineID] = Array(list.prefix(Constants.eventsPerMachine))
    events = stored
    try? file.save(stored)
  }
}
