import SwiftUI

/// The thin status bar under a result: counts and timing on the left, controls on the right.
struct DatabaseFooter<Leading: View, Trailing: View>: View {
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: Spacing.xs) {
        leading
        Spacer()
        trailing
      }
      .font(.ui(FontSize.subheadline))
      .foregroundStyle(Color.secondaryLabel)
      .padding(.vertical, Spacing.xs)
      .padding(.horizontal, Spacing.sm)
    }
  }
}
