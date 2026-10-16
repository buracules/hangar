import SwiftUI

private enum Constants {
  static let height: CGFloat = 26
  static let shadowOpacity = 0.22
  static let shadowRadius: CGFloat = 14
  static let shadowOffset: CGFloat = 4
}

/// The pill that appears when Follow is paused by scrolling up.
struct JumpToLatestButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Spacing.xxs) {
        Text("Jump to latest")
        Image(systemName: "arrow.down")
      }
      .font(.ui(FontSize.callout, weight: .medium))
      .foregroundStyle(Color.onAccent)
      .padding(.horizontal, Spacing.sm)
      .frame(height: Constants.height)
      .background(Color.accentColor, in: Capsule())
      .shadow(
        color: .black.opacity(Constants.shadowOpacity),
        radius: Constants.shadowRadius,
        y: Constants.shadowOffset
      )
    }
    .buttonStyle(.plain)
    .keyboardShortcut(.downArrow, modifiers: .command)
  }
}
