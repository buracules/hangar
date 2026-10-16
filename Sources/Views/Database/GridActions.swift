import Foundation

/// What a result grid's context menu can do beyond copying. Nil actions are left out —
/// the SQL tab's results have no table to filter or insert into.
struct GridActions {
  /// "Copy Row as INSERT": the SQL for one row, from its values.
  var insertStatement: (([String?]) -> String)?
  /// "Filter Rows Where column = value".
  var filterWhere: ((_ column: String, _ value: String?) -> Void)?
}
