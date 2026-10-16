import SwiftUI

private enum Constants {
  static let iconSize: CGFloat = 30
  static let messageWidth: CGFloat = 300
}

/// The Database tab's centred states: an icon, a heading, a line of explanation, actions.
struct DatabaseEmptyState<Actions: View>: View {
  let systemImage: String
  let title: String
  let message: String
  @ViewBuilder var actions: Actions

  var body: some View {
    VStack(spacing: Spacing.xs) {
      Image(systemName: systemImage)
        .font(.system(size: Constants.iconSize, weight: .light))
        .foregroundStyle(Color.tertiaryLabel)
        .accessibilityHidden(true)
      Text(title)
        .font(.ui(FontSize.title3, weight: .semibold))
        .padding(.top, Spacing.xxs)
      Text(message)
        .font(.ui(FontSize.callout))
        .foregroundStyle(Color.secondaryLabel)
        .multilineTextAlignment(.center)
        .frame(maxWidth: Constants.messageWidth)
      HStack(spacing: Spacing.xs) { actions }
        .padding(.top, Spacing.xs)
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
