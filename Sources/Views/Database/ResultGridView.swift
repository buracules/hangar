import AppKit
import SwiftUI

private enum Constants {
  static let rowHeight: CGFloat = 22
  static let headerHeight: CGFloat = 24
  static let rowNumberWidth: CGFloat = 40
  static let minimumColumnWidth: CGFloat = 60
  /// The design caps a cell at 220 pt; longer values are cut with an ellipsis.
  static let maximumColumnWidth: CGFloat = 220
  static let cellPadding: CGFloat = 16
  /// Enough rows to size a column by; measuring thousands would stall the first draw.
  static let sizingSampleRows = 50
  static let rowNumberIdentifier = NSUserInterfaceItemIdentifier("row-number")
  static let fullValueWidth: CGFloat = 420
  static let fullValueHeight: CGFloat = 240
  /// The design's cell padding, each side. `.dg td { padding: 0 8px }`
  static let cellInset: CGFloat = 8
}

/// Query results as a spreadsheet-like grid: row numbers, typed headers, NULLs, zebra rows,
/// ⌘C to copy selected rows, and a context menu for the clicked cell.
struct ResultGridView: NSViewRepresentable {
  let result: QueryResult
  let types: [String]
  /// The number shown on the first row: 201 on the second page.
  var firstRowNumber = 1
  /// Changes whenever the result is replaced.
  let resetKey: String
  var actions = GridActions()

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> NSScrollView {
    let table = ResultTableView()
    table.style = .plain
    table.rowHeight = Constants.rowHeight
    table.usesAlternatingRowBackgroundColors = true
    table.gridStyleMask = [.solidVerticalGridLineMask]
    table.gridColor = .separator
    table.allowsMultipleSelection = true
    table.allowsColumnReordering = false
    table.columnAutoresizingStyle = .noColumnAutoresizing
    table.headerView?.frame.size.height = Constants.headerHeight
    table.dataSource = context.coordinator
    table.delegate = context.coordinator
    table.menu = context.coordinator.menu
    context.coordinator.table = table

    let scrollView = NSScrollView()
    scrollView.documentView = table
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.drawsBackground = false
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let coordinator = context.coordinator
    coordinator.actions = actions
    guard coordinator.resetKey != resetKey else { return }
    coordinator.resetKey = resetKey
    coordinator.result = result
    coordinator.firstRowNumber = firstRowNumber
    coordinator.rebuildColumns(types: types)
  }

  /// Feeds the table, sizes its columns and runs its context menu.
  @MainActor
  final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    var result = QueryResult.empty
    var firstRowNumber = 1
    var resetKey = ""
    var actions = GridActions()
    weak var table: ResultTableView?
    let menu = NSMenu()

    override init() {
      super.init()
      menu.delegate = self
    }

    func rebuildColumns(types: [String]) {
      guard let table else { return }
      table.tableColumns.forEach(table.removeTableColumn)
      // Drop the old rows first: adding a column asks for cells in every visible row, and
      // with a shorter result those rows no longer exist.
      table.reloadData()
      let numbers = NSTableColumn(identifier: Constants.rowNumberIdentifier)
      numbers.title = ""
      numbers.width = Constants.rowNumberWidth
      numbers.resizingMask = []
      table.addTableColumn(numbers)
      for (index, name) in result.columns.enumerated() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
        let type = types.indices.contains(index) ? types[index] : ""
        column.headerCell.attributedStringValue = ResultGridText.header(name: name, type: type)
        column.width = width(of: index, header: column.headerCell.attributedStringValue)
        column.minWidth = Constants.minimumColumnWidth
        table.addTableColumn(column)
      }
      table.rowValues = { [weak self] row in
        guard let rows = self?.result.rows, rows.indices.contains(row) else { return [] }
        return rows[row]
      }
      table.reloadData()
      table.scrollRowToVisible(0)
    }

    private func width(of column: Int, header: NSAttributedString) -> CGFloat {
      let sample = result.rows.prefix(Constants.sizingSampleRows)
      let widest =
        sample.map { row -> CGFloat in
          let value = row.indices.contains(column) ? row[column] : nil
          return ResultGridText.cell(value).text.size().width
        }
        .max() ?? 0
      let natural = max(widest, header.size().width) + Constants.cellPadding
      return min(max(natural, Constants.minimumColumnWidth), Constants.maximumColumnWidth)
    }

    // MARK: Data source

    func numberOfRows(in tableView: NSTableView) -> Int { result.rows.count }

    func tableView(
      _ tableView: NSTableView,
      viewFor tableColumn: NSTableColumn?,
      row: Int
    ) -> NSView? {
      guard let tableColumn else { return nil }
      let cell = reusableCell(in: tableView, for: tableColumn.identifier)
      guard let field = cell.textField else { return cell }
      if tableColumn.identifier == Constants.rowNumberIdentifier {
        field.font = ResultGridText.rowNumberFont
        field.textColor = .tertiaryLabel
        field.alignment = .right
        field.stringValue = String(firstRowNumber + row)
      } else {
        let column = Int(tableColumn.identifier.rawValue) ?? 0
        let values = values(at: row) ?? []
        let content = ResultGridText.cell(values.indices.contains(column) ? values[column] : nil)
        field.attributedStringValue = content.text
        field.alignment = content.alignment
      }
      return cell
    }

    /// A cell view whose label is centred vertically with the design's side padding.
    private func reusableCell(
      in tableView: NSTableView,
      for identifier: NSUserInterfaceItemIdentifier
    ) -> NSTableCellView {
      let reused = tableView.makeView(withIdentifier: identifier, owner: nil)
      if let cell = reused as? NSTableCellView { return cell }
      let cell = NSTableCellView()
      cell.identifier = identifier
      let field = NSTextField(labelWithString: "")
      field.lineBreakMode = .byTruncatingTail
      field.translatesAutoresizingMaskIntoConstraints = false
      cell.addSubview(field)
      cell.textField = field
      let inset = Constants.cellInset
      NSLayoutConstraint.activate([
        field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: inset),
        field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -inset),
        field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      ])
      return cell
    }

    // MARK: Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
      menu.removeAllItems()
      guard let table, table.clickedRow >= 0 else { return }
      let row = table.clickedRow
      let column = table.clickedColumn - 1
      if !table.selectedRowIndexes.contains(row) {
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
      }
      let hasCell = result.columns.indices.contains(column)
      if hasCell {
        add("Copy Value", key: "c", modifiers: .command) { [weak self] in
          self?.copyValue(row, column)
        }
      }
      add("Copy Row", key: "c", modifiers: [.command, .shift]) { [weak self] in self?.copyRow(row) }
      if let insert = actions.insertStatement {
        add("Copy Row as INSERT") { [weak self] in
          guard let values = self?.values(at: row) else { return }
          Self.copy(insert(values))
        }
      }
      if hasCell {
        menu.addItem(.separator())
        let name = result.columns[column]
        if let filter = actions.filterWhere {
          add("Filter Rows Where \(name) = Value") { [weak self] in
            filter(name, self?.value(row, column))
          }
        }
        add("Show Full Value…") { [weak self] in self?.showFullValue(row, column) }
      }
    }

    private func add(
      _ title: String,
      key: String = "",
      modifiers: NSEvent.ModifierFlags = [],
      action: @escaping () -> Void
    ) {
      let item = MenuAction.item(title, action: action)
      item.keyEquivalent = key
      item.keyEquivalentModifierMask = modifiers
      menu.addItem(item)
    }

    /// The row's values, or nil once a newer result no longer has that row — menu actions
    /// run after the click, and the result can change in between.
    private func values(at row: Int) -> [String?]? {
      result.rows.indices.contains(row) ? result.rows[row] : nil
    }

    private func value(_ row: Int, _ column: Int) -> String? {
      guard let values = values(at: row) else { return nil }
      return values.indices.contains(column) ? values[column] : nil
    }

    private func copyValue(_ row: Int, _ column: Int) {
      Self.copy(value(row, column) ?? ResultGridText.null)
    }

    private func copyRow(_ row: Int) {
      guard let values = values(at: row) else { return }
      Self.copy(values.map { $0 ?? ResultGridText.null }.joined(separator: "\t"))
    }

    private func showFullValue(_ row: Int, _ column: Int) {
      guard result.columns.indices.contains(column) else { return }
      let alert = NSAlert()
      alert.messageText = result.columns[column]
      let scroll = NSTextView.scrollableTextView()
      scroll.frame.size = NSSize(width: Constants.fullValueWidth, height: Constants.fullValueHeight)
      if let text = scroll.documentView as? NSTextView {
        text.string = value(row, column) ?? ResultGridText.null
        text.font = ResultGridText.valueFont
        text.isEditable = false
      }
      alert.accessoryView = scroll
      alert.addButton(withTitle: "Copy")
      alert.addButton(withTitle: "Close")
      if alert.runModal() == .alertFirstButtonReturn { copyValue(row, column) }
    }

    private static func copy(_ text: String) {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    }
  }
}
