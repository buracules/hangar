import SwiftUI

private enum Constants {
  static let numberLocale = Locale(identifier: "en_US_POSIX")
}

/// The open table's rows, a page at a time.
struct DatabaseDataView: View {
  let model: DatabaseModel

  var body: some View {
    VStack(spacing: 0) {
      if let error = model.rowsError {
        ErrorBox(message: error)
          .padding(Spacing.sm)
        Spacer()
      } else if let rows = model.rows {
        ResultGridView(
          result: rows,
          types: model.rowColumnTypes,
          firstRowNumber: (model.pageRange?.lowerBound ?? 1),
          resetKey: resetKey,
          actions: actions
        )
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      footer
    }
  }

  private var resetKey: String {
    let table = model.selectedTable?.qualifiedName ?? ""
    return "\(table)|\(model.page)|\(model.whereClause)|\(model.rows?.rows.count ?? 0)"
  }

  private var actions: GridActions {
    GridActions(
      insertStatement: { [model] values in
        guard let table = model.selectedTable else { return "" }
        return SQLBuilder.insert(into: table, columns: model.rows?.columns ?? [], values: values)
      },
      filterWhere: { [model] column, value in
        Task { await model.filterRows(column: column, value: value) }
      }
    )
  }

  private var footer: some View {
    DatabaseFooter {
      if let range = model.pageRange {
        Text(verbatim: "Rows \(range.lowerBound)–\(range.upperBound)")
        if model.whereClause.isEmpty, let estimate = model.selectedTable?.estimatedRows {
          Text(verbatim: "of ~\(estimate.formatted(.number.locale(Constants.numberLocale)))")
            .foregroundStyle(Color.tertiaryLabel)
        }
      } else if model.rows != nil {
        Text("No rows")
      }
      if let elapsed = model.rowsElapsed {
        Text(verbatim: "· \(elapsed.millisecondsText)").foregroundStyle(Color.tertiaryLabel)
      }
    } trailing: {
      Button("Previous") { Task { await model.previousPage() } }
        .disabled(!model.hasPreviousPage || model.isLoadingRows)
      Button("Next") { Task { await model.nextPage() } }
        .disabled(!model.hasNextPage || model.isLoadingRows)
    }
    .controlSize(.small)
  }
}
