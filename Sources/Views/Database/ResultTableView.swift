import AppKit

/// A table view that copies its selected rows, tab-separated, on ⌘C.
final class ResultTableView: NSTableView {
  /// The values of a row, for copying.
  var rowValues: ((Int) -> [String?])?

  @objc func copy(_ sender: Any?) {
    guard let rowValues, !selectedRowIndexes.isEmpty else { return }
    let text =
      selectedRowIndexes
      .map { rowValues($0).map { $0 ?? ResultGridText.null }.joined(separator: "\t") }
      .joined(separator: "\n")
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
