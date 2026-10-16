import SwiftUI

// MARK: - Tokens

extension Font {
  /// SF Pro at a `FontSize` token.
  static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }

  /// SF Mono, for logs, SQL, IDs, ports and grid values only.
  static func mono(_ size: CGFloat = FontSize.mono, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }
}
