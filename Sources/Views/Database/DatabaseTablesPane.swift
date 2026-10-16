import SwiftUI

private enum Constants {
  static let width: CGFloat = 256
  static let iconSize: CGFloat = 13
  static let viewTag = "view"
  static let significantDigits = 1...2
  static let thousands = "K"
  static let shortThousands = "k"
  /// "~12k", not "~12 B": the estimate reads as a developer's shorthand in any locale.
  static let numberLocale = Locale(identifier: "en_US_POSIX")
}

/// The left column: database picker, table filter, and tables grouped by schema.
struct DatabaseTablesPane: View {
  @Bindable var model: DatabaseModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
      databasePicker
      TextField("Filter tables", text: $model.tableFilter, prompt: Text("Filter tables"))
        .textFieldStyle(.roundedBorder)
      tableList
    }
    .padding(.vertical, Spacing.sm)
    .padding(.horizontal, Spacing.xs)
    .frame(width: Constants.width)
    .background(Color.backgroundPane)
  }

  private var databasePicker: some View {
    Picker("Database", selection: databaseBinding) {
      ForEach(model.databases, id: \.self) { name in
        Label(name, systemImage: "cylinder").tag(Optional(name))
      }
    }
    .labelsHidden()
  }

  private var databaseBinding: Binding<String?> {
    Binding(
      get: { model.database },
      set: { name in
        guard let name else { return }
        Task { await model.selectDatabase(name) }
      }
    )
  }

  @ViewBuilder
  private var tableList: some View {
    if model.tables.isEmpty {
      Text("No tables")
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(Color.secondaryLabel)
        .padding(.horizontal, Spacing.xxs)
      Spacer()
    } else {
      List(selection: tableBinding) {
        ForEach(model.tablesBySchema, id: \.schema) { group in
          Section {
            ForEach(group.tables, id: \.self) { tableRow($0) }
          } header: {
            HStack {
              Text(group.schema)
              Spacer()
              Text(verbatim: String(group.tables.count)).monospacedDigit()
            }
          }
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
    }
  }

  private var tableBinding: Binding<TableInfo?> {
    Binding(
      get: { model.selectedTable },
      set: { table in
        guard let table, table != model.selectedTable else { return }
        Task { await model.selectTable(table) }
      }
    )
  }

  private func tableRow(_ table: TableInfo) -> some View {
    HStack(spacing: Spacing.xs) {
      Image(systemName: table.isView ? "eye" : "tablecells")
        .font(.system(size: Constants.iconSize))
        .foregroundStyle(table.isView ? Color.ansiMagenta : Color.accentText)
      Text(table.name)
        .italic(table.isView)
        .lineLimit(1)
      Spacer(minLength: Spacing.xxs)
      Text(verbatim: table.isView ? Constants.viewTag : summary(table))
        .font(.ui(FontSize.caption))
        .foregroundStyle(Color.secondaryLabel)
        .monospacedDigit()
    }
    .tag(Optional(table))
  }

  /// `~12k · 4 MB`: Postgres's row estimate, rounded, and the size on disk.
  private func summary(_ table: TableInfo) -> String {
    let style = IntegerFormatStyle<Int>.number
      .notation(.compactName)
      .precision(.significantDigits(Constants.significantDigits))
      .locale(Constants.numberLocale)
    // "12k" as developers write it; millions stay "1.4M".
    let rows = table.estimatedRows.formatted(style)
      .replacingOccurrences(of: Constants.thousands, with: Constants.shortThousands)
    return "~\(rows) · \(table.size)"
  }
}
