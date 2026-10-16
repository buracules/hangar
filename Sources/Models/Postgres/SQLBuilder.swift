import Foundation

private enum Constants {
  static let null = "NULL"
}

/// SQL Hangar writes for the user: rows copied as INSERTs, and row filters.
enum SQLBuilder {
  /// `INSERT INTO "public"."users" ("id", "email") VALUES ('1042', 'ada@hermes.dev');`
  /// Every value is a quoted literal; Postgres casts it to the column's type.
  static func insert(into table: TableInfo, columns: [String], values: [String?]) -> String {
    let names = columns.map(SQLQuote.identifier).joined(separator: ", ")
    let literals = values.map { $0.map(SQLQuote.literal) ?? Constants.null }.joined(separator: ", ")
    return "INSERT INTO \(table.qualifiedName) (\(names)) VALUES (\(literals));"
  }

  /// `"email" = 'ada@hermes.dev'`, or `"deleted_at" IS NULL` for a NULL value.
  static func equals(column: String, value: String?) -> String {
    let name = SQLQuote.identifier(column)
    guard let value else { return "\(name) IS NULL" }
    return "\(name) = \(SQLQuote.literal(value))"
  }
}
