import AppKit

private enum Constants {
  /// The gutter of the design's editor.
  static let width: CGFloat = 32
  static let trailingPadding: CGFloat = 10
}

/// Line numbers beside a text view, in the design's quiet gutter colour.
final class LineNumberRuler: NSRulerView {
  private weak var textView: NSTextView?

  init(textView: NSTextView) {
    self.textView = textView
    super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
    ruleThickness = Constants.width
    clientView = textView
  }

  @available(*, unavailable)
  required init(coder: NSCoder) {
    fatalError("LineNumberRuler is created in code")
  }

  override func drawHashMarksAndLabels(in rect: NSRect) {
    guard let textView, let layoutManager = textView.layoutManager,
      let container = textView.textContainer
    else { return }
    NSColor.backgroundEditor.setFill()
    bounds.fill()
    let text = textView.string as NSString
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: FontSize.mono, weight: .regular),
      .foregroundColor: NSColor.quaternaryLabel,
    ]
    let visibleGlyphs = layoutManager.glyphRange(
      forBoundingRect: textView.visibleRect,
      in: container
    )
    let visibleCharacters = layoutManager.characterRange(
      forGlyphRange: visibleGlyphs,
      actualGlyphRange: nil
    )
    let textBefore = text.substring(to: visibleCharacters.location)
    var lineNumber = textBefore.components(separatedBy: "\n").count
    var index = visibleCharacters.location
    let offset = convert(NSPoint.zero, from: textView).y + textView.textContainerInset.height
    repeat {
      let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
      let glyph = layoutManager.glyphIndexForCharacter(at: lineRange.location)
      let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      let label = String(lineNumber) as NSString
      let size = label.size(withAttributes: attributes)
      let x = ruleThickness - size.width - Constants.trailingPadding
      label.draw(at: NSPoint(x: x, y: fragment.minY + offset), withAttributes: attributes)
      lineNumber += 1
      index = NSMaxRange(lineRange)
    } while index < NSMaxRange(visibleCharacters)
  }
}
