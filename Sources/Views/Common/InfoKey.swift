import SwiftUI

private enum Constants {
  /// The key column of the design's info form.
  static let width: CGFloat = 96
}

/// A right-aligned label in a detail's info grid: "Name", "Image", "Ports" …
struct InfoKey: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.ui(FontSize.callout))
      .foregroundStyle(Color.secondaryLabel)
      .frame(width: Constants.width, alignment: .trailing)
  }
}
