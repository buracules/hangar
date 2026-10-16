import Foundation

/// The text attributes an ANSI SGR sequence can set.
struct LogStyle: Equatable, Sendable {
  var foreground: LogColor?
  var background: LogColor?
  var isBold = false
  var isDim = false
  var isUnderlined = false
}
