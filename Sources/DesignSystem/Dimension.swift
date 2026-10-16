import CoreGraphics

/// Fixed sizes of rows, controls and panes. Each value names its CSS token.
enum Dimension {
  /// Sidebar and list rows. `--h-row`
  static let row: CGFloat = 28
  /// Two-line rows: menu bar panel VMs and containers. `--h-row-2`
  static let tallRow: CGFloat = 36
  /// Push buttons. `--h-control`
  static let control: CGFloat = 24
  /// Small buttons. `--h-control-sm`
  static let smallControl: CGFloat = 20
  /// The window toolbar. `--h-toolbar`
  static let toolbar: CGFloat = 52
  /// The sidebar column. `--w-sidebar`
  static let sidebarWidth: CGFloat = 232
  /// The menu bar panel. `--w-popover`
  static let popoverWidth: CGFloat = 360
}
