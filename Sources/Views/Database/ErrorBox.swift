import SwiftUI

private enum Constants {
  static let lineSpacing: CGFloat = 3
  static let border: CGFloat = 0.5
}

/// Postgres's own error text, monospaced so its `LINE n:` / `^` pointer lines up.
struct ErrorBox: View {
  let message: String

  var body: some View {
    Text(verbatim: message)
      .font(.mono(FontSize.smallMono))
      .lineSpacing(Constants.lineSpacing)
      .foregroundStyle(Color.logError)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, Spacing.xs)
      .padding(.horizontal, Spacing.sm)
      .background(Color.errorBackground, in: RoundedRectangle(cornerRadius: Radius.sm))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.sm)
          .strokeBorder(Color.errorBorder, lineWidth: Constants.border)
      )
  }
}
