import Foundation

/// Opacities for states. Label shades are colours (`Color.secondaryLabel` …), not these.
/// Each value names its CSS token.
enum Opacity {
  /// Disabled controls. `--op-disabled`
  static let disabled = 0.3
  /// Hover overlays. `--op-hover`
  static let hover = 0.05
  /// Pressed overlays. `--op-pressed`
  static let pressed = 0.1
}
