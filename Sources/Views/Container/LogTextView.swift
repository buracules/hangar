import AppKit
import SwiftUI

private enum Constants {
  /// How close to the bottom still counts as "at the bottom".
  static let bottomTolerance: CGFloat = 8
}

/// An NSTextView rather than a SwiftUI list: selection spans lines, and appending is cheap.
///
/// Follow behaves like a chat: new lines keep the view pinned to the bottom, scrolling up to
/// read pauses it (and leaves the position alone), and scrolling back down resumes it.
struct LogTextView: NSViewRepresentable {
  let lines: [LogLine]
  /// Changes whenever the lines are replaced rather than appended to.
  let resetKey: String
  @Binding var isFollowing: Bool
  let isWrapping: Bool

  /// What the view last showed, so an update only appends what is new.
  @MainActor
  final class Coordinator {
    var resetKey = ""
    var shownLineCount = 0
    var isWrapping: Bool?
    var isFollowing: Binding<Bool>
    /// Set while we change the text, so only the user's own scrolling toggles follow.
    var isUpdating = false
    var observer: NSObjectProtocol?

    init(isFollowing: Binding<Bool>) { self.isFollowing = isFollowing }

    func scrolled(_ scrollView: LogScrollView) {
      guard !isUpdating, !scrollView.isPinning, let document = scrollView.documentView else {
        return
      }
      let isAtBottom =
        scrollView.contentView.bounds.maxY >= document.frame.maxY - Constants.bottomTolerance
      if isFollowing.wrappedValue != isAtBottom { isFollowing.wrappedValue = isAtBottom }
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(isFollowing: $isFollowing) }

  func makeNSView(context: Context) -> LogScrollView {
    let textView = Self.makeTextView()
    let scrollView = LogScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false

    let coordinator = context.coordinator
    scrollView.contentView.postsBoundsChangedNotifications = true
    coordinator.observer = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: scrollView.contentView,
      queue: .main
    ) { [weak coordinator, weak scrollView] _ in
      MainActor.assumeIsolated {
        if let scrollView { coordinator?.scrolled(scrollView) }
      }
    }
    return scrollView
  }

  static func dismantleNSView(_ scrollView: LogScrollView, coordinator: Coordinator) {
    if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) }
  }

  func updateNSView(_ scrollView: LogScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView,
      let storage = textView.textStorage
    else { return }
    let state = context.coordinator
    state.isFollowing = $isFollowing
    scrollView.isFollowing = isFollowing
    state.isUpdating = true
    defer { state.isUpdating = false }

    if state.isWrapping != isWrapping {
      Self.setWrapping(isWrapping, scrollView, textView)
      state.isWrapping = isWrapping
    }
    if state.resetKey != resetKey || lines.count < state.shownLineCount {
      storage.setAttributedString(LogStyler.attributed(lines[...], continuing: false))
    } else if lines.count > state.shownLineCount {
      let new = lines[state.shownLineCount...]
      storage.append(LogStyler.attributed(new, continuing: state.shownLineCount != 0))
    }
    state.resetKey = resetKey
    state.shownLineCount = lines.count
    if isFollowing { scrollView.pinToBottom() }
  }

  /// TextKit 1 on purpose: TextKit 2 estimates the height of text it has not laid out yet,
  /// so on a long log the scroller jumps and "scroll to end" stops short. The custom layout
  /// manager draws the edge-to-edge ERROR backgrounds.
  private static func makeTextView() -> NSTextView {
    let storage = NSTextStorage()
    let layoutManager = LogLayoutManager()
    layoutManager.backgroundLayoutEnabled = false
    storage.addLayoutManager(layoutManager)
    let container = NSTextContainer(containerSize: .zero)
    // Padding inside each line fragment, not a text inset, so line backgrounds reach the edges.
    container.lineFragmentPadding = Spacing.md
    layoutManager.addTextContainer(container)

    let textView = NSTextView(frame: .zero, textContainer: container)
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.drawsBackground = true
    textView.backgroundColor = .backgroundContent
    textView.textContainerInset = NSSize(width: 0, height: Spacing.xs)
    textView.typingAttributes = LogStyler.baseAttributes
    textView.isVerticallyResizable = true
    textView.minSize = .zero
    let unlimited = CGFloat.greatestFiniteMagnitude
    textView.maxSize = NSSize(width: unlimited, height: unlimited)
    textView.autoresizingMask = [.width]
    return textView
  }

  private static func setWrapping(
    _ wraps: Bool,
    _ scrollView: NSScrollView,
    _ textView: NSTextView
  ) {
    guard let container = textView.textContainer else { return }
    let unlimited = CGFloat.greatestFiniteMagnitude
    scrollView.hasHorizontalScroller = !wraps
    textView.isHorizontallyResizable = !wraps
    container.widthTracksTextView = wraps
    if wraps {
      container.containerSize = NSSize(width: scrollView.contentSize.width, height: unlimited)
      textView.frame.size.width = scrollView.contentSize.width
    } else {
      container.containerSize = NSSize(width: unlimited, height: unlimited)
      textView.maxSize = NSSize(width: unlimited, height: unlimited)
    }
  }
}
