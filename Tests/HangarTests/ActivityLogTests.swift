import Foundation
import Testing

@testable import Hangar

@MainActor
struct ActivityLogTests {
  /// A log backed by a file in a fresh temporary folder, never the real Application Support.
  private func makeLog() -> ActivityLog {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("HangarTests-\(UUID().uuidString)", isDirectory: true)
    return ActivityLog(file: SharedFile(name: "activity.json", directory: folder))
  }

  @Test func eventsComeBackNewestFirst() {
    let log = makeLog()
    log.record("vm", outcome: .running, title: "Started")
    log.record("vm", outcome: .stopped, title: "Shut down")

    #expect(log.events(for: "vm").map(\.title) == ["Shut down", "Started"])
  }

  @Test func anObservedChangeCoveredByARecordedActionIsSkipped() {
    let log = makeLog()
    let now = Date.now
    log.record("vm", outcome: .running, title: "Started", cause: "by profile work", at: now)

    log.observe("vm", outcome: .running, title: "Started", at: now.addingTimeInterval(20))

    #expect(log.events(for: "vm").count == 1)
    #expect(log.events(for: "vm").first?.cause == "by profile work")
  }

  @Test func anObservedChangeLongAfterIsRecorded() {
    let log = makeLog()
    let now = Date.now
    log.record("vm", outcome: .running, title: "Started", at: now)

    log.observe("vm", outcome: .running, title: "Started", at: now.addingTimeInterval(600))

    #expect(log.events(for: "vm").count == 2)
  }

  @Test func eventsSurviveANewLogOnTheSameFile() {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("HangarTests-\(UUID().uuidString)", isDirectory: true)
    let file = SharedFile<[String: [ActivityEvent]]>(name: "activity.json", directory: folder)
    ActivityLog(file: file).record("db", outcome: .error, title: "Exited", detail: "code 137")

    #expect(ActivityLog(file: file).events(for: "db").first?.detail == "code 137")
  }
}
