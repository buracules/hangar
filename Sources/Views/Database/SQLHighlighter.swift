import AppKit

/// Colours SQL in a text view from `SQLTokenizer`'s tokens.
@MainActor
enum SQLHighlighter {
  static let font = NSFont.monospacedSystemFont(ofSize: FontSize.mono, weight: .regular)
  private static let keywordFont = NSFont.monospacedSystemFont(
    ofSize: FontSize.mono,
    weight: .semibold
  )

  /// Re-colours the whole text. Editors hold a query, not a dump, so this stays cheap.
  static func apply(to textView: NSTextView) {
    guard let storage = textView.textStorage else { return }
    let whole = NSRange(location: 0, length: storage.length)
    storage.beginEditing()
    storage.setAttributes([.font: font, .foregroundColor: NSColor.label], range: whole)
    for token in SQLTokenizer.tokens(in: storage.string) {
      storage.addAttributes(attributes(for: token.kind), range: token.range)
    }
    storage.endEditing()
  }

  private static func attributes(for kind: SQLToken.Kind) -> [NSAttributedString.Key: Any] {
    switch kind {
    case .keyword: [.foregroundColor: NSColor.sqlKeyword, .font: keywordFont]
    case .string: [.foregroundColor: NSColor.sqlString]
    case .number: [.foregroundColor: NSColor.sqlNumber]
    case .function: [.foregroundColor: NSColor.sqlFunction]
    case .comment: [.foregroundColor: NSColor.tertiaryLabel]
    }
  }
}
