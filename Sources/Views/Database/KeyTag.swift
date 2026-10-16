import SwiftUI

private enum Constants {
  static let height: CGFloat = 16
  static let horizontalPadding: CGFloat = 5
  static let tracking: CGFloat = 0.2
  static let primaryKeyTintOpacity = 0.12
}

/// A column constraint tag in the Structure tab: PRIMARY KEY, UNIQUE, FK → table.column.
struct KeyTag: View {
  let key: ColumnInfo.Key

  var body: some View {
    Text(verbatim: title)
      .font(.ui(FontSize.caption, weight: .semibold))
      .tracking(Constants.tracking)
      .foregroundStyle(foreground)
      .padding(.horizontal, Constants.horizontalPadding)
      .frame(height: Constants.height)
      .background(background, in: RoundedRectangle(cornerRadius: Radius.xs))
  }

  private var title: String {
    switch key {
    case .primaryKey: "PRIMARY KEY"
    case .unique: "UNIQUE"
    case .foreignKey(let target): "FK → \(target)"
    }
  }

  private var foreground: Color {
    switch key {
    case .primaryKey: .statusBusy
    case .unique: .secondaryLabel
    case .foreignKey: .accentText
    }
  }

  private var background: Color {
    switch key {
    case .primaryKey: .statusBusy.opacity(Constants.primaryKeyTintOpacity)
    case .unique: .controlFill
    case .foreignKey: .accentSoft
    }
  }
}
