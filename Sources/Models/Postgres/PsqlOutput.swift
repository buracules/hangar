import Foundation

/// psql's unaligned output with ASCII separators, and how to read it back. Real data
/// practically never contains these characters — unlike the commas, tabs and newlines CSV or
/// aligned output trip over — and the format works back to psql 9.6.
enum PsqlOutput {
  /// Unit separator, between fields.
  static let fieldSeparator: Character = "\u{1F}"
  /// Record separator, between rows.
  static let recordSeparator: Character = "\u{1E}"
  /// Cancel: what NULL prints as, so it stays distinct from an empty string.
  static let nullMarker = "\u{18}"

  /// The psql flags that produce this format.
  static var arguments: [String] {
    [
      "-A",
      "-F", String(fieldSeparator),
      "-R", String(recordSeparator),
      "-P", "footer=off",
      "-P", "null=\(nullMarker)",
    ]
  }

  /// psql prints each result as a header record, then data records separated by RS, then a
  /// newline. Every field but a record's last ends at US; the last ends at RS, or at the
  /// newline that closes the result — so a newline in a result's last column is ambiguous,
  /// which `PostgresClient.select` avoids with a marker column.
  static func parse(_ output: String) -> [QueryResult] {
    var results: [QueryResult] = []
    var rest = Substring(output)
    while !rest.isEmpty {
      // Header: up to RS (rows follow) or newline (no rows, or a command tag).
      guard let end = rest.firstIndex(where: { $0 == recordSeparator || $0 == "\n" }) else {
        results.append(.message(String(rest)))
        break
      }
      let header = rest[..<end]
      let hasRows = rest[end] == recordSeparator
      rest = rest[rest.index(after: end)...]
      let columns = header.split(separator: fieldSeparator, omittingEmptySubsequences: false)
        .map(String.init)
      guard hasRows else {
        results.append(headerOnly(header, columns: columns))
        continue
      }
      let (rows, remainder) = parseRows(rest, columnCount: columns.count)
      rest = remainder
      results.append(QueryResult(columns: columns, rows: rows, messages: []))
    }
    return results
  }

  /// A header with no rows: a command tag (BEGIN, INSERT 0 2, …) or an empty result.
  private static func headerOnly(_ header: Substring, columns: [String]) -> QueryResult {
    let looksLikeTag = header.allSatisfy { $0.isUppercase || $0.isNumber || $0 == " " }
    guard columns.count == 1, looksLikeTag else {
      return QueryResult(columns: columns, rows: [], messages: [])
    }
    return .message(String(header))
  }

  /// The rows of one result, and what follows them.
  private static func parseRows(
    _ text: Substring,
    columnCount: Int
  ) -> (rows: [[String?]], rest: Substring) {
    var rows: [[String?]] = []
    var row: [String?] = []
    var field = ""
    var index = text.startIndex
    while index < text.endIndex {
      let character = text[index]
      index = text.index(after: index)
      let closesLastField = character == "\n" && row.count == columnCount - 1
      if character == fieldSeparator {
        row.append(value(field))
        field = ""
      } else if character == recordSeparator || closesLastField {
        row.append(value(field))
        field = ""
        rows.append(row)
        row = []
        if character == "\n" { break }
      } else {
        field.append(character)
      }
    }
    return (rows, text[index...])
  }

  private static func value(_ field: String) -> String? { field == nullMarker ? nil : field }
}
