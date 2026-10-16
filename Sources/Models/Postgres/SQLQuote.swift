import Foundation

/// Quoting for values Hangar builds into SQL itself.
enum SQLQuote {
  /// A double-quoted identifier: `my "table"` → `"my ""table"""`.
  static func identifier(_ name: String) -> String {
    "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  /// A single-quoted string literal: `it's` → `'it''s'`.
  static func literal(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
  }
}
