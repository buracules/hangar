import AppKit

private enum Constants {
  /// Below this width the view has not been laid out yet; pinning would measure nonsense.
  static let minimumLayoutWidth: CGFloat = 40
}

/// Pins itself to the bottom while following — after new text, and after any resize,
/// including the first layout, when the view only then learns its real width.
final class LogScrollView: NSScrollView {
  var isFollowing = true
  /// True while we scroll, so the scroll observer can tell our scrolling from the user's.
  private(set) var isPinning = false

  override func layout() {
    super.layout()
    if isFollowing { pinToBottom() }
  }

  /// Scrolls to the very end, after laying out everything so the end is final.
  func pinToBottom() {
    guard contentSize.width > Constants.minimumLayoutWidth,
      let textView = documentView as? NSTextView,
      let layoutManager = textView.layoutManager,
      let container = textView.textContainer
    else { return }
    isPinning = true
    defer { isPinning = false }
    // Lay everything out now, so the height — and with it the bottom — is final before
    // anything is drawn; otherwise the view visibly chases a bottom that keeps moving.
    layoutManager.ensureLayout(for: container)
    textView.sizeToFit()
    let bottom = max(0, textView.frame.height - contentView.bounds.height)
    contentView.scroll(to: NSPoint(x: contentView.bounds.origin.x, y: bottom))
    reflectScrolledClipView(contentView)
  }
}
