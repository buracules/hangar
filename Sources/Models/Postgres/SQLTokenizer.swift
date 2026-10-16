import Foundation

/// Finds the parts of SQL the editor colours. Comments and strings are matched first, so a
/// keyword inside them stays uncoloured.
enum SQLTokenizer {
  static func tokens(in text: String) -> [SQLToken] {
    let pattern = #/
      (--[^\n]*|\/\*[\s\S]*?\*\/)
      | ('(?:[^']|'')*'?)
      | (\b\d+(?:\.\d+)?\b)
      | ([A-Za-z_][A-Za-z0-9_]*)
      /#
    var tokens: [SQLToken] = []
    for match in text.matches(of: pattern) {
      let kind: SQLToken.Kind?
      if match.1 != nil {
        kind = .comment
      } else if match.2 != nil {
        kind = .string
      } else if match.3 != nil {
        kind = .number
      } else if let word = match.4 {
        kind = wordKind(word, endingAt: match.range.upperBound, in: text)
      } else {
        kind = nil
      }
      if let kind { tokens.append(SQLToken(range: NSRange(match.range, in: text), kind: kind)) }
    }
    return tokens
  }

  /// A keyword, a function call, or nothing to colour.
  private static func wordKind(
    _ word: Substring,
    endingAt end: String.Index,
    in text: String
  ) -> SQLToken.Kind? {
    if keywords.contains(word.uppercased()) { return .keyword }
    return isCall(after: end, in: text) ? .function : nil
  }

  /// Whether the word just before `index` is called: `count(`, `now (`.
  private static func isCall(after index: String.Index, in text: String) -> Bool {
    text[index...].first { !$0.isWhitespace } == "("
  }

  private static let keywords: Set<String> = [
    "ADD", "ALL", "ALTER", "AND", "ANY", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASCADE", "CASE",
    "CAST", "CHECK", "COLUMN", "COMMIT", "CONSTRAINT", "CREATE", "CROSS", "DEFAULT", "DELETE",
    "DESC", "DISTINCT", "DO", "DROP", "ELSE", "END", "EXCEPT", "EXISTS", "EXPLAIN", "FALSE",
    "FETCH", "FOR", "FOREIGN", "FROM", "FULL", "GRANT", "GROUP", "HAVING", "ILIKE", "IN", "INDEX",
    "INNER", "INSERT", "INTERSECT", "INTO", "IS", "JOIN", "KEY", "LATERAL", "LEFT", "LIKE",
    "LIMIT", "NOT", "NULL", "OFFSET", "ON", "OR", "ORDER", "OUTER", "OVER", "PARTITION", "PRIMARY",
    "REFERENCES", "RETURNING", "RIGHT", "ROLLBACK", "SELECT", "SET", "TABLE", "THEN", "TO", "TRUE",
    "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "USING", "VALUES", "VIEW", "WHEN", "WHERE", "WINDOW",
    "WITH",
  ]
}
