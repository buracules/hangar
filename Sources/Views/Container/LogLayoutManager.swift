import AppKit

/// Fills `.logLineBackground` across the full width of each line fragment it covers, so an
/// ERROR line is tinted edge to edge as in the design.
final class LogLayoutManager: NSLayoutManager {
  override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    guard let storage = textStorage else { return }
    let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
    storage.enumerateAttribute(.logLineBackground, in: characters) { value, range, _ in
      guard let color = value as? NSColor else { return }
      let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
      color.setFill()
      enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
        rect.offsetBy(dx: origin.x, dy: origin.y).fill()
      }
    }
  }
}
