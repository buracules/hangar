import Foundation
import Testing

@testable import Hangar

struct LogLevelTests {
  @Test(arguments: [
    ("2026-10-16 15:10:54 UTC [29] ERROR:  relation \"x\" does not exist", LogLevel.error),
    ("FATAL: out of memory", .error),
    (#"{"level":"warn","msg":"slow"}"#, .warning),
    ("level=error msg=boom", .error),
    ("WARNING: disk almost full", .warning),
    ("2026-10-16T15:10:54Z DEBUG tick", .debug),
  ])
  func aLineAnnouncesItsLevel(line: String, level: LogLevel) {
    #expect(LogLevel.detect(in: line) == level)
  }

  @Test(arguments: ["INFO no errors here, errors=0", "an error happened in prose", "plain line"])
  func proseIsNotALevel(line: String) {
    #expect(LogLevel.detect(in: line) == nil)
  }
}
