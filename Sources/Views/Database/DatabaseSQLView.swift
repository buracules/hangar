import SwiftUI

private enum Constants {
  /// Six lines and the editor's padding, as in the design; it grows with the query.
  static let minimumEditorHeight: CGFloat = 124
  static let maximumEditorHeight: CGFloat = 280
}

/// The SQL editor and its result: a grid, an inline error, or the command's tag.
struct DatabaseSQLView: View {
  @Bindable var model: DatabaseModel

  var body: some View {
    VStack(spacing: 0) {
      SQLEditorView(text: $model.sql) { Task { await model.runSQL() } }
        .frame(height: editorHeight)
        .clipped()
      Divider()
      result
      footer
    }
  }

  private var editorHeight: CGFloat {
    let lines = CGFloat(max(model.sql.components(separatedBy: "\n").count, 1))
    let natural = lines * LineHeight.mono + Spacing.md
    return min(max(natural, Constants.minimumEditorHeight), Constants.maximumEditorHeight)
  }

  @ViewBuilder
  private var result: some View {
    if let error = model.sqlError {
      VStack {
        ErrorBox(message: error)
        Spacer()
      }
      .padding(Spacing.sm)
    } else if let result = model.sqlResult, !result.columns.isEmpty {
      ResultGridView(
        result: result,
        types: model.sqlColumnTypes,
        firstRowNumber: model.sqlPageRange?.lowerBound ?? 1,
        resetKey: resultKey
      )
    } else if model.sqlResult != nil {
      Text("No rows returned.")
        .foregroundStyle(Color.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      Text("Write a query and press ⌘↩.")
        .foregroundStyle(Color.tertiaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Changes with every run and page, so the grid reloads even for the same query.
  private var resultKey: String {
    let elapsed = model.sqlElapsed.map { String(describing: $0) } ?? ""
    return "\(model.history.first ?? "")|\(model.sqlPage)|\(elapsed)"
  }

  private var footer: some View {
    DatabaseFooter {
      if model.isRunningSQL {
        ProgressView().controlSize(.mini)
        Text("Running…")
      } else if model.sqlError != nil {
        StatusSymbol(kind: .error)
        Text("Query failed").foregroundStyle(Color.statusError)
      } else if let result = model.sqlResult {
        StatusSymbol(kind: .running)
        Text(verbatim: summary(result))
      }
      if let elapsed = model.sqlElapsed, !model.isRunningSQL {
        Text(verbatim: "· \(elapsed.millisecondsText)").foregroundStyle(Color.tertiaryLabel)
      }
    } trailing: {
      if let database = model.database {
        Text(verbatim: database).font(.mono(FontSize.smallMono))
      }
      if model.hasPreviousSQLPage || model.hasNextSQLPage {
        Button("Previous") { Task { await model.previousSQLPage() } }
          .disabled(!model.hasPreviousSQLPage || model.isRunningSQL)
        Button("Next") { Task { await model.nextSQLPage() } }
          .disabled(!model.hasNextSQLPage || model.isRunningSQL)
      }
    }
    .controlSize(.small)
  }

  /// "Rows 201–400" for a paged query, "3 rows" when it fits one page, or the command tag:
  /// "INSERT 0 2".
  private func summary(_ result: QueryResult) -> String {
    guard !result.columns.isEmpty else { return result.messages.last ?? "Done" }
    if let range = model.sqlPageRange, model.hasPreviousSQLPage || model.hasNextSQLPage {
      return "Rows \(range.lowerBound)–\(range.upperBound)"
    }
    let count = result.rows.count
    return "\(count)\(result.isTruncated ? "+" : "") row\(count == 1 ? "" : "s")"
  }
}
