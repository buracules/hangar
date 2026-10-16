import AppKit
import SwiftUI

/// A SQL editor: line numbers, syntax colours from the design's `sql-*` tokens, SF Mono.
struct SQLEditorView: NSViewRepresentable {
  @Binding var text: String
  let onRun: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  func makeNSView(context: Context) -> NSScrollView {
    let textView = SQLTextView()
    textView.isRichText = false
    textView.allowsUndo = true
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.font = SQLHighlighter.font
    textView.textColor = .label
    textView.backgroundColor = .backgroundEditor
    textView.insertionPointColor = .controlAccentColor
    textView.textContainerInset = NSSize(width: Spacing.xs, height: Spacing.xs)
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.textContainer?.widthTracksTextView = true
    textView.delegate = context.coordinator
    textView.onRun = onRun
    textView.string = text
    SQLHighlighter.apply(to: textView)

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.verticalRulerView = LineNumberRuler(textView: textView)
    scrollView.hasVerticalRuler = true
    scrollView.rulersVisible = true
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? SQLTextView else { return }
    context.coordinator.text = $text
    textView.onRun = onRun
    // Only when the change came from outside (History), so typing keeps the cursor.
    if textView.string != text {
      textView.string = text
      SQLHighlighter.apply(to: textView)
      scrollView.verticalRulerView?.needsDisplay = true
    }
  }

  /// Keeps the binding in step with typing and re-colours as the text changes.
  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>

    init(text: Binding<String>) { self.text = text }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text.wrappedValue = textView.string
      SQLHighlighter.apply(to: textView)
      textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }
  }
}
