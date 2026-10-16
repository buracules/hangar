import AppKit

// MARK: - Logs

extension NSAttributedString.Key {
  /// A colour to fill behind a whole log line, edge to edge — not just behind its glyphs,
  /// which is all `.backgroundColor` does. Drawn by `LogLayoutManager`.
  static let logLineBackground = NSAttributedString.Key("HangarLogLineBackground")
}
