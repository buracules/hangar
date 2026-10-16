import SwiftUI

private enum Constants {
  static let headerHeight: CGFloat = 24
  static let rowHeight: CGFloat = 22
  static let cellPadding: CGFloat = 8
  static let ruleWidth: CGFloat = 0.5
}

/// A small, content-sized table in the design's grid style — header band, hairline rules,
/// zebra rows — for lists short enough to show whole, like a table's columns or indexes.
struct DesignTable<Row: Identifiable, Cell: View>: View {
  let columns: [String]
  let rows: [Row]
  @ViewBuilder let cell: (Row, Int) -> Cell

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
      GridRow {
        ForEach(columns.indices, id: \.self) { index in
          Text(columns[index])
            .font(.ui(FontSize.subheadline, weight: .semibold))
            .foregroundStyle(Color.secondaryLabel)
            .frame(maxWidth: index == columns.count - 1 ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, Constants.cellPadding)
            .frame(height: Constants.headerHeight)
            .background(Color.backgroundHeader)
        }
      }
      .overlay(alignment: .bottom) { Color.strongSeparator.frame(height: Constants.ruleWidth) }
      ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
        GridRow {
          ForEach(columns.indices, id: \.self) { index in
            cell(row, index)
              .lineLimit(1)
              .frame(maxWidth: index == columns.count - 1 ? .infinity : nil, alignment: .leading)
              .padding(.horizontal, Constants.cellPadding)
              .frame(height: Constants.rowHeight)
              .background(offset.isMultiple(of: 2) ? Color.clear : Color.zebraStripe)
          }
        }
      }
    }
  }
}
