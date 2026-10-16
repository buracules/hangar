import AppKit

private enum Constants {
  static let headerTypeSpacer = "  "
}

/// How grid cells and headers read: SF Mono values, an italic "NULL", right-aligned numbers,
/// and headers with the column's type after its name.
@MainActor
enum ResultGridText {
  static let null = "NULL"
  static let valueFont = NSFont.monospacedSystemFont(ofSize: FontSize.mono, weight: .regular)
  static let rowNumberFont = NSFont.monospacedSystemFont(
    ofSize: FontSize.smallMono,
    weight: .regular
  )
  static let nullFont: NSFont = {
    let base = NSFont.systemFont(ofSize: FontSize.callout)
    let italic = base.fontDescriptor.withSymbolicTraits(.italic)
    return NSFont(descriptor: italic, size: FontSize.callout) ?? base
  }()

  /// A cell's text and how it should be aligned.
  static func cell(_ value: String?) -> (text: NSAttributedString, alignment: NSTextAlignment) {
    guard let value else {
      let text = NSAttributedString(
        string: null,
        attributes: [.font: nullFont, .foregroundColor: NSColor.tertiaryLabel]
      )
      return (text, .left)
    }
    // One line per cell; the full value is a right-click away.
    let line = value.replacingOccurrences(of: "\n", with: " ↵ ")
    let alignment: NSTextAlignment = isNumber(value) ? .right : .left
    // Alignment in the paragraph style: an attributed string overrides the field's own.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    let text = NSAttributedString(
      string: line,
      attributes: [.font: valueFont, .foregroundColor: NSColor.label, .paragraphStyle: paragraph]
    )
    return (text, alignment)
  }

  /// `email  text`: the name in semibold, the type quieter.
  static func header(name: String, type: String) -> NSAttributedString {
    let header = NSMutableAttributedString(
      string: name,
      attributes: [
        .font: NSFont.systemFont(ofSize: FontSize.subheadline, weight: .semibold),
        .foregroundColor: NSColor.secondaryLabel,
      ]
    )
    if !type.isEmpty {
      header.append(
        NSAttributedString(
          string: Constants.headerTypeSpacer + type,
          attributes: [
            .font: NSFont.systemFont(ofSize: FontSize.subheadline),
            .foregroundColor: NSColor.tertiaryLabel,
          ]
        )
      )
    }
    return header
  }

  private static func isNumber(_ value: String) -> Bool {
    !value.isEmpty && Double(value) != nil
  }
}
