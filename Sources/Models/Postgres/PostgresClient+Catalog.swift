import Foundation

private enum Constants {
  static let databaseLimit = 1000
  static let tableLimit = 10_000
  static let columnLimit = 2000
  static let indexLimit = 500
  static let defaultKind = "r"
  static let tablePlaceholder = "$table"
  static let keySeparator: Character = ";"
  static let primaryKeyCode = "p"
  static let uniqueCode = "u"
  static let foreignKeyPrefix = "f:"
  static let trueValue = "t"
  static let temporaryView = "hangar_columns"

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

  /// Name, full type, short type, nullable, default and key codes (`p`, `u`,
  /// `f:table.column`, joined with `;`) of the table named by `$table`.
  static let columnsSQL = """
    SELECT a.attname, format_type(a.atttypid, a.atttypmod), t.typname, NOT a.attnotnull,
           pg_get_expr(d.adbin, d.adrelid),
           (SELECT string_agg(
                     CASE con.contype
                       WHEN 'p' THEN 'p'
                       WHEN 'u' THEN 'u'
                       WHEN 'f' THEN 'f:' || con.confrelid::regclass::text || '.' || (
                         SELECT ref.attname FROM pg_attribute ref
                         WHERE ref.attrelid = con.confrelid
                           AND ref.attnum = con.confkey[array_position(con.conkey, a.attnum)])
                     END, ';')
            FROM pg_constraint con
            WHERE con.conrelid = a.attrelid AND a.attnum = ANY(con.conkey)
              AND con.contype IN ('p', 'u', 'f'))
    FROM pg_attribute a
    JOIN pg_type t ON t.oid = a.atttypid
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE a.attrelid = $table::regclass AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
    """

  /// Name, columns (`(org_id)`), method, uniqueness and size of the indexes on `$table`.
  static let indexesSQL = """
    SELECT i.relname,
           regexp_replace(pg_get_indexdef(ix.indexrelid), '^.* USING \\w+ ', ''),
           am.amname, ix.indisunique, pg_size_pretty(pg_relation_size(ix.indexrelid))
    FROM pg_index ix
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_am am ON am.oid = i.relam
    WHERE ix.indrelid = $table::regclass
    ORDER BY 1
    """
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

  /// A table's columns with types, nullability, defaults and keys.
  func columns(of table: TableInfo, in database: String) async throws -> [ColumnInfo] {
    let result = try await select(
      sql(Constants.columnsSQL, for: table),
      database: database,
      limit: Constants.columnLimit
    )
    return result.rows.map(columnInfo(from:))
  }

  /// A table's indexes.
  func indexes(of table: TableInfo, in database: String) async throws -> [IndexInfo] {
    let result = try await select(
      sql(Constants.indexesSQL, for: table),
      database: database,
      limit: Constants.indexLimit
    )
    return result.rows.map { row in
      let row = Row(row)
      return IndexInfo(
        name: row.text(IndexField.name),
        columns: row.text(IndexField.columns),
        method: row.text(IndexField.method),
        isUnique: row.text(IndexField.isUnique) == Constants.trueValue,
        size: row.text(IndexField.size)
      )
    }
  }

  /// A page of a table's rows in storage order, optionally narrowed by a WHERE clause the
  /// user typed.
  func rows(
    of table: TableInfo,
    in database: String,
    where filter: String = "",
    limit: Int,
    offset: Int
  ) async throws -> QueryResult {
    let condition = filter.trimmingCharacters(in: .whitespacesAndNewlines)
    let whereClause = condition.isEmpty ? "" : " WHERE \(condition)"
    return try await select(
      "SELECT * FROM \(table.qualifiedName)\(whereClause)",
      database: database,
      limit: limit,
      offset: offset
    )
  }

  /// The short type of each column a single query returns, read through a temporary view
  /// that disappears with the psql session. Empty when the query cannot back a view, such
  /// as one with duplicate column names.
  func columnTypes(ofQuery query: String, in database: String) async -> [String] {
    let view = Constants.temporaryView
    let script = """
      CREATE TEMP VIEW \(view) AS \(query);
      SELECT t.typname FROM pg_attribute a JOIN pg_type t ON t.oid = a.atttypid
      WHERE a.attrelid = '\(view)'::regclass AND a.attnum > 0 ORDER BY a.attnum;
      """
    let results = (try? await run(script, database: database)) ?? []
    return results.last { !$0.columns.isEmpty }?.rows.compactMap { $0.first ?? nil } ?? []
  }

  /// The psql version inside the container: `17.2`.
  func psqlVersion() async -> String? {
    let result = try? await docker.exec(containerID, ["psql", "--version"])
    let output = result.flatMap { String(bytes: $0.stdout, encoding: .utf8) } ?? ""
    return output.firstMatch(of: /(\d+(?:\.\d+)*)/).map { String($0.1) }
  }

  private func sql(_ template: String, for table: TableInfo) -> String {
    template.replacingOccurrences(
      of: Constants.tablePlaceholder,
      with: SQLQuote.literal(table.qualifiedName)
    )
  }

  private func tableInfo(from values: [String?]) -> TableInfo {
    let row = Row(values)
    let kind = row.text(TableField.kind)
    return TableInfo(
      schema: row.text(TableField.schema),
      name: row.text(TableField.name),
      kind: kind.isEmpty ? Constants.defaultKind : kind,
      estimatedRows: Int(row.text(TableField.estimatedRows)) ?? 0,
      size: row.text(TableField.size)
    )
  }

  private func columnInfo(from values: [String?]) -> ColumnInfo {
    let row = Row(values)
    let keys = row.text(ColumnField.keys)
      .split(separator: Constants.keySeparator)
      .compactMap { code -> ColumnInfo.Key? in
        switch code {
        case Constants.primaryKeyCode: .primaryKey
        case Constants.uniqueCode: .unique
        default:
          code.hasPrefix(Constants.foreignKeyPrefix)
            ? .foreignKey(String(code.dropFirst(Constants.foreignKeyPrefix.count))) : nil
        }
      }
    return ColumnInfo(
      name: row.text(ColumnField.name),
      type: row.text(ColumnField.fullType),
      shortType: row.text(ColumnField.shortType),
      isNullable: row.text(ColumnField.isNullable) == Constants.trueValue,
      defaultValue: row.value(ColumnField.defaultValue),
      keys: keys
    )
  }
}

/// A result row read by field position.
private struct Row {
  let values: [String?]

  init(_ values: [String?]) { self.values = values }

  func value<Field: RawRepresentable<Int>>(_ field: Field) -> String? {
    values.indices.contains(field.rawValue) ? values[field.rawValue] : nil
  }

  func text<Field: RawRepresentable<Int>>(_ field: Field) -> String { value(field) ?? "" }
}

/// The column order of `tablesSQL`.
private enum TableField: Int {
  case schema
  case name
  case kind
  case estimatedRows
  case size
}

/// The column order of `columnsSQL`.
private enum ColumnField: Int {
  case name
  case fullType
  case shortType
  case isNullable
  case defaultValue
  case keys
}

/// The column order of `indexesSQL`.
private enum IndexField: Int {
  case name
  case columns
  case method
  case isUnique
  case size
}
