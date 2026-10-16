import Foundation

/// A colour a program asked for in its output.
enum LogColor: Equatable, Sendable {
  /// The xterm 256-colour palette; 0–15 are the standard and bright colours.
  case indexed(Int)
  case rgb(red: UInt8, green: UInt8, blue: UInt8)
}
