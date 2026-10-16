import Foundation

// MARK: - Identifiable

extension ColumnInfo: Identifiable {
  /// Column names are unique within a table.
  var id: String { name }
}
