import Foundation

// MARK: - Stamping

extension LogLine {
  /// A plain line Hangar writes itself, such as the command it ran: `$ pnpm dev`.
  static func note(_ text: String, at time: Date = .now) -> LogLine {
    LogLine(
      text: text,
      runs: [LogRun(text: text, style: LogStyle())],
      isStderr: false,
      level: .debug,
      time: time,
      timestampLength: 0
    )
  }

  /// The line as read from a local process: stamped with when it arrived, and marked
  /// stderr when it came from there.
  func stamped(at time: Date, isStderr: Bool) -> LogLine {
    LogLine(
      text: text,
      runs: runs,
      isStderr: isStderr,
      level: level,
      time: time,
      timestampLength: timestampLength
    )
  }
}
