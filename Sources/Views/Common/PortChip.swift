import SwiftUI

private enum Constants {
  static let height: CGFloat = 18
  static let horizontalPadding: CGFloat = 6
}

/// A published port, `:5433`, that opens `http://localhost:5433` when clicked.
struct PortChip: View {
  let port: Int
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      // Verbatim: a port is not a quantity, so no "5.433" grouping in any locale.
      Text(verbatim: ":\(port)")
        .font(.mono(FontSize.smallMono))
        .foregroundStyle(Color.accentText)
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(height: Constants.height)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.xs))
    }
    .buttonStyle(.plain)
    .help("Open http://localhost:\(String(port))")
    .accessibilityLabel("Open port \(String(port)) in the browser")
  }
}
