import SwiftUI

private enum Constants {
  static let titleSpacing: CGFloat = 6
  static let titleInset: CGFloat = 12
  static let outline: CGFloat = 0.5
  /// Rows' separators start after the status symbol.
  static let separatorInset: CGFloat = 34
}

/// A titled card of member rows: "Virtual Machines", "Containers".
struct ProfileMemberSection<Title: View, Rows: View>: View {
  @ViewBuilder let title: Title
  @ViewBuilder let rows: Rows

  var body: some View {
    VStack(alignment: .leading, spacing: Constants.titleSpacing) {
      title
        .font(.ui(FontSize.subheadline, weight: .semibold))
        .foregroundStyle(Color.tertiaryLabel)
        .padding(.leading, Constants.titleInset)
      VStack(spacing: 0) {
        Group(subviews: rows) { subviews in
          ForEach(subviews.indices, id: \.self) { index in
            if index > 0 { Divider().padding(.leading, Constants.separatorInset) }
            subviews[index]
          }
        }
      }
      .background(Color.backgroundCard, in: RoundedRectangle(cornerRadius: Radius.md))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.md)
          .strokeBorder(Color.strongSeparator, lineWidth: Constants.outline)
      )
    }
  }
}
