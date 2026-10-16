import CoreGraphics

/// The 8 pt spacing grid, with a 4 pt half step. Each value names its CSS token.
enum Spacing {
  /// `--sp-0-5`
  static let xxs: CGFloat = 4
  /// `--sp-1`
  static let xs: CGFloat = 8
  /// `--sp-1-5`
  static let sm: CGFloat = 12
  /// `--sp-2`
  static let md: CGFloat = 16
  /// `--sp-3`
  static let lg: CGFloat = 24
  /// `--sp-4`
  static let xl: CGFloat = 32
  /// `--sp-6`
  static let xxl: CGFloat = 48
}
