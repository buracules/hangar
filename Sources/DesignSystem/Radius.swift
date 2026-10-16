import CoreGraphics

/// Corner radii. Each value names its CSS token.
enum Radius {
  /// Port chips, tags. `--r-xs`
  static let xs: CGFloat = 4
  /// Buttons, fields, sidebar rows. `--r-sm`
  static let sm: CGFloat = 6
  /// Cards, menus, detail icons. `--r-md`
  static let md: CGFloat = 8
  /// Alerts. `--r-lg`
  static let lg: CGFloat = 12
  /// Windows. `--r-window`
  static let window: CGFloat = 10
  /// Pills: profile chips, "Jump to latest". `--r-capsule`
  static let capsule: CGFloat = 999
}
