import Foundation

private enum Constants {
  static let databaseLimit = 1000
  static let tableLimit = 10_000
  static let columnLimit = 2000
  static let defaultKind = "r"

  static let databasesSQL =
    "SELECT datname FROM pg_database WHERE NOT datistemplate AND datallowconn ORDER BY 1"

  static let tablesSQL = """
    SELECT n.nspname, c.relname, c.relkind::text, GREATEST(c.reltuples, 0)::bigint,
           pg_size_pretty(pg_total_relation_size(c.oid))
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r', 'p', 'v', 'm', 'f')
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
    ORDER BY 1, 2
    """

  /// Columns of the table named by `$table`, a regclass literal.
  static let columnsSQL = """
    SELECT a.attname AS column, format_type(a.atttypid, a.atttypmod) AS type,
           CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END AS nullable,
           pg_get_expr(d.adbin, d.adrelid) AS "default",
           (SELECT string_agg(CASE con.contype WHEN 'p' THEN 'PRIMARY KEY'
                                               WHEN 'u' THEN 'UNIQUE'
                                               WHEN 'f' THEN 'FK → ' || confrelid::regclass::text
                              END, ', ')
            FROM pg_constraint con
            WHERE con.conrelid = a.attrelid AND a.attnum = ANY(con.conkey)
              AND con.contype IN ('p', 'u', 'f')) AS keys
    FROM pg_attribute a
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE a.attrelid = $table::regclass AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
    """
  static let tablePlaceholder = "$table"
}

// MARK: - Catalog

extension PostgresClient {
  /// Databases a client can connect to.
  func databases() async throws -> [String] {
    try await select(Constants.databasesSQL, limit: Constants.databaseLimit)
      .rows.compactMap { $0.first ?? nil }
  }

  /// Tables, views and materialized views outside the system schemas.
  func tables(in database: String) async throws -> [TableInfo] {
    let result = try await select(
      Constants.tablesSQL,
      database: database,
      limit: Constants.tableLimit
    )
    return result.rows.map(tableInfo(from:))
  }

  /// A table's columns with type, nullability, default and keys.
  func columns(of table: TableInfo, in database: String) async throws -> QueryResult {
    let sql = Constants.columnsSQL.replacingOccurrences(
      of: Constants.tablePlaceholder,
      with: SQLQuote.literal(table.qualifiedName)
    )
    return try await select(sql, database: database, limit: Constants.columnLimit)
  }

  /// A page of a table's rows, in storage order.
  func rows(
    of table: TableInfo,
    in database: String,
    limit: Int,
    offset: Int
  ) async throws
    -> QueryResult
  {
    try await select(
      "SELECT * FROM \(table.qualifiedName)",
      database: database,
      limit: limit,
      offset: offset
    )
  }

  /// A `tablesSQL` row: schema, name, kind, estimated rows, size.
  private func tableInfo(from row: [String?]) -> TableInfo {
    let field = { (column: TableColumn) in
      row.indices.contains(column.rawValue) ? row[column.rawValue] ?? "" : ""
    }
    let kind = field(.kind)
    return TableInfo(
      schema: field(.schema),
      name: field(.name),
      kind: kind.isEmpty ? Constants.defaultKind : kind,
      estimatedRows: Int(field(.estimatedRows)) ?? 0,
      size: field(.size)
    )
  }
}

/// The column order of `tablesSQL`.
private enum TableColumn: Int {
  case schema
  case name
  case kind
  case estimatedRows
  case size
}
