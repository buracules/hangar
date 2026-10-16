import Foundation

/// A table column as the Structure tab shows it.
struct ColumnInfo: Hashable, Sendable {
  /// A constraint the column takes part in.
  enum Key: Hashable, Sendable {
    case primaryKey
    case unique
    /// Points at `table.column`.
    case foreignKey(String)
  }

  let name: String
  /// `bigint`, `text`, `timestamp with time zone` …
  let type: String
  /// Postgres's internal name, compact enough for a grid header: `int8`, `timestamptz`.
  let shortType: String
  let isNullable: Bool
  /// The default expression; nil when there is none.
  let defaultValue: String?
  let keys: [Key]
}
