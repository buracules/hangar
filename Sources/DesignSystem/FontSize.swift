import CoreGraphics

/// The type scale, in points. SF Pro for UI text, SF Mono for logs, SQL, IDs, ports and
/// grid values. Each value names its CSS token.
enum FontSize {
  /// `--fs-title1`
  static let title1: CGFloat = 22
  /// Detail header names. `--fs-title2`
  static let title2: CGFloat = 17
  /// Toolbar titles, empty-state headings. `--fs-title3`
  static let title3: CGFloat = 15
  /// Body text. `--fs-body`
  static let body: CGFloat = 13
  /// Statuses, info labels, segmented controls. `--fs-callout`
  static let callout: CGFloat = 12
  /// Section headers, counts, toolbar subtitles. `--fs-sub`
  static let subheadline: CGFloat = 11
  /// Tags. `--fs-caption`
  static let caption: CGFloat = 10
  /// Logs, SQL, grid values. `--fs-mono`
  static let mono: CGFloat = 12
  /// Port chips, row numbers, error boxes. `--fs-mono-sm`
  static let smallMono: CGFloat = 11
}
