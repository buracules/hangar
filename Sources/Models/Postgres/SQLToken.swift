import Foundation

/// A stretch of SQL the editor colours.
struct SQLToken: Equatable {
  /// What the stretch is.
  enum Kind: Equatable {
    case keyword
    case string
    case number
    case function
    case comment
  }

  let range: NSRange
  let kind: Kind
}
