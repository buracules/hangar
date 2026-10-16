import Foundation
import Testing

@testable import Hangar

struct ActivityTimeTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
    return calendar
  }

  /// Friday 16 October 2026, 14:30 in Istanbul.
  private var now: Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 14, minute: 30))
      ?? .now
  }

  private func label(minutesAgo: Double) -> String {
    ActivityTime.label(for: now.addingTimeInterval(-minutesAgo * 60), now: now, calendar: calendar)
  }

  @Test func todayShowsTheClock() {
    #expect(label(minutesAgo: 10) == "14:20")
  }

  @Test func yesterdayShowsYest() {
    #expect(label(minutesAgo: 20 * 60) == "Yest.")
  }

  @Test func thisWeekShowsTheWeekday() {
    #expect(label(minutesAgo: 4 * 24 * 60) == "Mon")
  }

  @Test func olderShowsTheDate() {
    #expect(label(minutesAgo: 13 * 24 * 60) == "3 Oct")
  }

  @Test func uptimeUsesTheTwoLargestUnits() {
    #expect(
      ActivityTime.uptime(since: now.addingTimeInterval(-192 * 60), now: now) == "Up 3 h 12 min"
    )
    #expect(ActivityTime.uptime(since: now.addingTimeInterval(-5 * 60), now: now) == "Up 5 min")
    #expect(
      ActivityTime.uptime(since: now.addingTimeInterval(-52 * 3600), now: now) == "Up 2 d 4 h"
    )
  }

  @Test func configurationReadsLikeTheDesign() {
    let qemu = VMConfiguration(
      backend: "QEMU",
      architecture: "aarch64",
      cpuCount: 4,
      memoryMiB: 8192
    )
    #expect(qemu.backendText == "QEMU · aarch64")
    #expect(qemu.resourcesText == "4 cores · 8 GB memory")

    let apple = VMConfiguration(backend: "Apple", architecture: nil, cpuCount: 0, memoryMiB: 3000)
    #expect(apple.backendText == "Apple")
    #expect(apple.resourcesText == "3000 MB memory")
  }
}
