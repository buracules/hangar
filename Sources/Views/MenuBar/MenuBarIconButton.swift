import SwiftUI

private enum Constants {
  /// The design's small `.tbb` buttons in panel rows.
  static let size: CGFloat = 22
  static let iconSize: CGFloat = 11
}

/// A borderless icon button in a menu bar panel row: start, stop, suspend.
struct MenuBarIconButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  init(_ title: String, systemImage: String, action: @escaping () -> Void) {
    self.title = title
    self.systemImage = systemImage
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: Constants.iconSize, weight: .medium))
        .frame(width: Constants.size, height: Constants.size)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .foregroundStyle(Color.secondaryLabel)
    .help(title)
    .accessibilityLabel(title)
  }
}
