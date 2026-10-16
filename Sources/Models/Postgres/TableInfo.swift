import Foundation

private enum Constants {
  static let viewKinds: Set<String> = ["v", "m"]
}

/// A table, view or materialized view in a database.
struct TableInfo: Hashable, Sendable {
  let schema: String
  let name: String
  /// pg_class.relkind: r table, p partitioned, v view, m materialized view, f foreign.
  let kind: String
  /// Postgres's planner estimate, not an exact count.
  let estimatedRows: Int
  /// Total size including indexes and TOAST, human-readable ("4096 kB").
  let size: String

  /// `"schema"."name"`, safe to put in SQL.
  var qualifiedName: String { SQLQuote.identifier(schema) + "." + SQLQuote.identifier(name) }

  var isView: Bool { Constants.viewKinds.contains(kind) }
}
