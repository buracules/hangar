import SwiftUI

private enum Constants {
  static let iconSize: CGFloat = 13
  static let groupIconSize: CGFloat = 14
}

/// One sidebar row: a leading mark, the name, and a short trailing detail.
struct SidebarRow: View {
  /// What sits before the name.
  enum Leading {
    case status(MachineStatus.Kind)
    case profile
    case group
  }

  let leading: Leading
  let name: String
  var trailing = ""
  /// Ports read better in monospace.
  var isTrailingMono = false
  var isEmphasized = false

  var body: some View {
    HStack(spacing: Spacing.xs) {
      leadingMark
      Text(name)
        .fontWeight(isEmphasized ? .medium : .regular)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: Spacing.xxs)
      if !trailing.isEmpty {
        Text(verbatim: trailing)
          .font(isTrailingMono ? .mono(FontSize.caption) : .ui(FontSize.subheadline))
          .foregroundStyle(Color.secondaryLabel)
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var leadingMark: some View {
    switch leading {
    case .status(let kind):
      StatusSymbol(kind: kind)
    case .profile:
      Image(systemName: "rectangle.stack")
        .font(.system(size: Constants.iconSize))
        .foregroundStyle(Color.accentText)
    case .group:
      Image(systemName: "shippingbox")
        .font(.system(size: Constants.groupIconSize))
        .foregroundStyle(Color.secondaryLabel)
    }
  }
}
