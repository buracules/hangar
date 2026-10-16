import AppKit

/// The editor's text view: ⌘↩ runs the query instead of inserting a newline.
final class SQLTextView: NSTextView {
  var onRun: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    let isReturn = event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter
    if isReturn, event.modifierFlags.contains(.command) {
      onRun?()
    } else {
      super.keyDown(with: event)
    }
  }

  /// The hardware key codes this view listens for.
  private enum KeyCode {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
  }
}
