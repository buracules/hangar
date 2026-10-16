import Foundation

// MARK: - Identifiable

extension IndexInfo: Identifiable {
  /// Index names are unique within a schema.
  var id: String { name }
}
