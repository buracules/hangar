import Foundation

/// One result of running SQL: a table of rows, or messages (command tags, notices).
struct QueryResult: Sendable {
  var columns: [String]
  /// Cell values in column order; nil is SQL NULL.
  var rows: [[String?]]
  var messages: [String]
  /// More rows existed than were fetched.
  var isTruncated = false

  /// A result that is only a message.
  static func message(_ text: String) -> QueryResult {
    QueryResult(columns: [], rows: [], messages: [text])
  }

  /// No columns, no rows, no messages.
  static let empty = QueryResult(columns: [], rows: [], messages: [])
}
