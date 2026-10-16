import Foundation

/// An index on a table.
struct IndexInfo: Hashable, Sendable {
  let name: String
  /// The indexed columns or expressions, as Postgres writes them: `(org_id)`.
  let columns: String
  /// The access method: `btree`, `gin`, `hash` …
  let method: String
  let isUnique: Bool
  /// Human-readable size: `288 kB`.
  let size: String
}
