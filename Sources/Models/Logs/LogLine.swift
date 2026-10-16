import Foundation

/// One line of output, already split into styled runs. `text` is the plain line, for
/// filtering and copying.
struct LogLine: Sendable {
  let text: String
  let runs: [LogRun]
  let isStderr: Bool
  let level: LogLevel?
  /// When Docker received the line.
  let time: Date?
  /// UTF-16 length of the program's own leading timestamp and the space after it, 0 if
  /// there is none. Redundant next to `time`, so it is hidden when that is known.
  let timestampLength: Int

  /// Whether the program coloured this line itself; if so, its colours win over ours.
  var hasOwnColor: Bool { runs.contains { $0.style.foreground != nil } }
}
