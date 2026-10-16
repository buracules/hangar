import Foundation

/// A stretch of a log line that shares one style.
struct LogRun: Sendable {
  var text: String
  var style: LogStyle
}
