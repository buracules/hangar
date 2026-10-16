import Foundation

/// How severe a log line is, as far as its text says.
enum LogLevel: Sendable {
  case error
  case warning
  case debug

  /// The level a line announces: an uppercase word (`ERROR`, `WARN:`), or a `level=` /
  /// `"level":` field in structured logs. Lowercase prose like "no errors" does not count.
  static func detect(in text: String) -> LogLevel? {
    if text.contains(/\b(ERROR|FATAL|PANIC|CRITICAL|CRIT)\b/)
      || text.contains(/(?i)level"?\s*[=:]\s*"?(error|fatal|panic|critical)\b/)
    {
      return .error
    }
    if text.contains(/\b(WARN|WARNING)\b/)
      || text.contains(/(?i)level"?\s*[=:]\s*"?(warn|warning)\b/)
    {
      return .warning
    }
    if text.contains(/\b(DEBUG|TRACE)\b/)
      || text.contains(/(?i)level"?\s*[=:]\s*"?(debug|trace)\b/)
    {
      return .debug
    }
    return nil
  }
}
