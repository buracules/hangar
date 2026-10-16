import SwiftUI

private enum Constants {
  static let nullableYes = "yes"
  static let nullableNo = "no"
  static let noDefault = "—"
  static let unique = "unique"
  static let separator = " · "
  static let columnHeaders = ["Column", "Type", "Nullable", "Default", "Keys"]
  static let indexHeaders = ["Name", "Columns", "Method", "Size"]
  static let typeAbbreviations = [
    "timestamp with time zone": "timestamptz",
    "timestamp without time zone": "timestamp",
    "time with time zone": "timetz",
    "character varying": "varchar",
  ]
}

/// The open table's columns with their keys, then its indexes — both sized to their content.
struct DatabaseStructureView: View {
  let model: DatabaseModel

  var body: some View {
    // Vertical only: the tables take the pane's width, so the last column stretches.
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 0) {
        DesignTable(columns: Constants.columnHeaders, rows: model.columns) { column, index in
          columnCell(column, StructureColumn(rawValue: index))
        }
        Text("Indexes")
          .font(.ui(FontSize.subheadline, weight: .semibold))
          .foregroundStyle(Color.tertiaryLabel)
          .padding(.top, Spacing.md)
          .padding(.bottom, Spacing.xxs)
          .padding(.horizontal, Spacing.sm)
        DesignTable(columns: Constants.indexHeaders, rows: model.indexes) { index, field in
          indexCell(index, IndexColumn(rawValue: field))
        }
      }
      .padding(.bottom, Spacing.md)
    }
  }

  @ViewBuilder
  private func columnCell(_ column: ColumnInfo, _ field: StructureColumn?) -> some View {
    switch field {
    case .name:
      Text(column.name).font(.mono(weight: .semibold))
    case .type:
      Text(displayType(column.type)).font(.mono()).foregroundStyle(Color.secondaryLabel)
    case .nullable:
      Text(column.isNullable ? Constants.nullableYes : Constants.nullableNo)
        .font(.ui(FontSize.callout))
        .foregroundStyle(column.isNullable ? Color.label : Color.tertiaryLabel)
    case .defaultValue:
      defaultValue(column)
    case .keys:
      HStack(spacing: Spacing.xxs) {
        ForEach(column.keys, id: \.self) { KeyTag(key: $0) }
      }
    case nil:
      EmptyView()
    }
  }

  @ViewBuilder
  private func indexCell(_ index: IndexInfo, _ field: IndexColumn?) -> some View {
    switch field {
    case .name: Text(index.name).font(.mono())
    case .columns: Text(index.columns).font(.mono())
    case .method:
      Text(index.isUnique ? index.method + Constants.separator + Constants.unique : index.method)
        .font(.mono())
        .foregroundStyle(Color.secondaryLabel)
    case .size: Text(index.size).font(.mono())
    case nil: EmptyView()
    }
  }

  @ViewBuilder
  private func defaultValue(_ column: ColumnInfo) -> some View {
    if let value = column.defaultValue {
      Text(value).font(.mono())
    } else if column.isNullable {
      Text(ResultGridText.null).italic().foregroundStyle(Color.tertiaryLabel)
    } else {
      Text(verbatim: Constants.noDefault).foregroundStyle(Color.tertiaryLabel)
    }
  }

  /// The shorter names developers write: `timestamptz`, not `timestamp with time zone`.
  private func displayType(_ type: String) -> String {
    Constants.typeAbbreviations.reduce(type) {
      $0.replacingOccurrences(of: $1.key, with: $1.value)
    }
  }
}

/// The order of `Constants.columnHeaders`.
private enum StructureColumn: Int {
  case name
  case type
  case nullable
  case defaultValue
  case keys
}

/// The order of `Constants.indexHeaders`.
private enum IndexColumn: Int {
  case name
  case columns
  case method
  case size
}
