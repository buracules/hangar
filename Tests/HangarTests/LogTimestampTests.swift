import Foundation
import Testing

@testable import Hangar

struct LogTimestampTests {
  @Test func dockerTimeKeepsFractionalSeconds() throws {
    let time = try #require(LogTimestamp.dockerTime("2026-10-16T15:10:56.1Z"))

    #expect(abs(time.timeIntervalSince1970 - 1_792_163_456.1) < 0.001)
  }

  @Test(arguments: ["hello", "2026-10-16", "not-a-timestampZ"])
  func otherTokensAreNotDockerTimes(token: String) {
    #expect(LogTimestamp.dockerTime(Substring(token)) == nil)
  }

  @Test(arguments: [
    ("2026-10-16 15:10:54.505 UTC [29] LOG:  ready", "[29] LOG:  ready"),
    ("2026-10-16T15:10:54Z DEBUG tick", "DEBUG tick"),
    ("[2026-10-16 15:10:54,505] INFO start", "INFO start"),
  ])
  func aProgramsOwnTimestampIsMeasuredWithItsSpace(line: String, rest: String) {
    let length = LogTimestamp.ownTimestampLength(in: line)

    #expect(String(line.utf16.dropFirst(length)) == rest)
  }

  @Test func aLineWithoutATimestampMeasuresZero() {
    #expect(LogTimestamp.ownTimestampLength(in: "VITE ready") == 0)
  }
}
