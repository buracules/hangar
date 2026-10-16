import AppKit
import SwiftUI

private enum Constants {
  static let whereFieldWidth: CGFloat = 220
  static let whereFieldMinimumWidth: CGFloat = 120
  static let historyPreviewLength = 60
  static let whereLabel = "WHERE"
}

/// The right side of the Database tab: Data / Structure / SQL over the open table.
struct DatabaseContentView: View {
  @Bindable var model: DatabaseModel

  var body: some View {
    VStack(spacing: 0) {
      controls
      Divider()
      switch model.tab {
      case .data: DatabaseDataView(model: model)
      case .structure: DatabaseStructureView(model: model)
      case .sql: DatabaseSQLView(model: model)
      }
    }
  }

  private var controls: some View {
    HStack(spacing: Spacing.xs) {
      Picker("View", selection: $model.tab) {
        ForEach(DatabaseModel.Tab.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .controlSize(.small)
      .fixedSize()
      Text(verbatim: heading)
        .font(.mono(weight: .semibold))
        .lineLimit(1)
        .truncationMode(.head)
        .layoutPriority(-1)
        .padding(.leading, Spacing.xxs)
      Spacer()
      switch model.tab {
      case .data: dataControls
      case .structure: structureControls
      case .sql: sqlControls
      }
    }
    .padding(.vertical, Spacing.xs)
    .padding(.horizontal, Spacing.sm)
  }

  private var heading: String {
    if model.tab == .sql { return "Query \(model.history.count + 1)" }
    guard let table = model.selectedTable else { return "" }
    return "\(table.schema).\(table.name)"
  }

  private var dataControls: some View {
    HStack(spacing: Spacing.xs) {
      TextField(
        Constants.whereLabel,
        text: $model.whereClause,
        prompt: Text(verbatim: "WHERE role = 'admin'")
      )
        .font(.mono(FontSize.smallMono))
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: Constants.whereFieldMinimumWidth, maxWidth: Constants.whereFieldWidth)
        .onSubmit { Task { await model.applyWhere() } }
        .help("A SQL condition for the rows, as after WHERE")
      Button("Reload rows", systemImage: "arrow.clockwise") { Task { await model.loadRows() } }
        .labelStyle(.iconOnly)
        .buttonStyle(.accessoryBar)
    }
  }

  private var structureControls: some View {
    HStack(spacing: Spacing.xs) {
      Text(verbatim: structureSummary)
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(Color.secondaryLabel)
      Button("Copy column names", systemImage: "doc.on.doc") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
          model.columns.map(\.name).joined(separator: ", "),
          forType: .string
        )
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.accessoryBar)
    }
  }

  /// "9 columns · 3 indexes · 1 foreign key".
  private var structureSummary: String {
    let foreignKeys = model.columns.flatMap(\.keys).filter {
      if case .foreignKey = $0 { true } else { false }
    }
    return [
      counted(model.columns.count, "column"),
      counted(model.indexes.count, "index", plural: "indexes"),
      counted(foreignKeys.count, "foreign key"),
    ]
    .joined(separator: " · ")
  }

  private func counted(_ count: Int, _ noun: String, plural: String? = nil) -> String {
    "\(count) \(count == 1 ? noun : plural ?? noun + "s")"
  }

  private var sqlControls: some View {
    HStack(spacing: Spacing.xs) {
      Menu("History") {
        ForEach(model.history, id: \.self) { query in
          let preview = query.replacingOccurrences(of: "\n", with: " ")
          Button(String(preview.prefix(Constants.historyPreviewLength))) { model.sql = query }
        }
        if model.history.isEmpty { Text("No queries yet") }
      }
      .controlSize(.small)
      .fixedSize()
      Button {
        Task { await model.runSQL() }
      } label: {
        Label("Run ⌘↩", systemImage: "play.fill")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .keyboardShortcut(.return, modifiers: .command)
      .disabled(model.isRunningSQL)
    }
  }
}
