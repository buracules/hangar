import AppKit
import SwiftUI

/// A container's live output, re-attached when the container starts or restarts.
struct ContainerLogs: View {
  let container: Container
  let docker: DockerClient?
  @State private var buffer = LogBuffer()
  @State private var filter = ""
  @State private var follow = true
  @State private var wrap = true

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Text("Logs").font(.headline)
        if let ended = buffer.endReason {
          Text(ended).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer()
        TextField("Filter", text: $filter)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 220)
        Toggle("Wrap", isOn: $wrap)
          .toggleStyle(.checkbox)
        Toggle("Follow", isOn: $follow)
          .toggleStyle(.checkbox)
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(
            visibleLines.map(\.text).joined(separator: "\n"),
            forType: .string
          )
        } label: {
          Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help("Copy the visible lines")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      LogTextView(
        lines: visibleLines,
        resetKey: "\(buffer.generation)|\(filter)",
        follow: $follow,
        wrap: wrap
      )
      .overlay(alignment: .bottomTrailing) {
        if !follow {
          Button {
            follow = true
          } label: {
            Label("Jump to latest", systemImage: "arrow.down")
          }
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
          .padding(14)
        }
      }
    }
    // A new key re-attaches: another container, or this one coming back up.
    .task(id: "\(container.id)|\(container.isRunning)") {
      follow = true
      await attach()
    }
  }

  private var visibleLines: [LogLine] {
    filter.isEmpty
      ? buffer.lines : buffer.lines.filter { $0.text.localizedCaseInsensitiveContains(filter) }
  }

  private func attach() async {
    let buffer = buffer
    buffer.reset()
    guard let docker else {
      buffer.end("No Docker socket")
      return
    }
    let flusher = Task { @MainActor in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        buffer.flush()
      }
    }
    defer { flusher.cancel() }
    var decoder = LogDecoder()
    do {
      for try await chunk in docker.logs(container.id) {
        buffer.stage(decoder.feed(chunk))
      }
      if !Task.isCancelled {
        buffer.end(container.isRunning ? "Stream ended" : "Container is not running")
      }
    } catch {
      if !Task.isCancelled { buffer.end(error.localizedDescription) }
    }
  }
}

/// Pins itself to the bottom while following — after new text, and after any resize,
/// including the first layout, when the view only then learns its real width.
private final class LogScrollView: NSScrollView {
  var follow = true
  /// True while we scroll, so the scroll observer can tell our scrolling from the user's.
  private(set) var isPinning = false

  override func layout() {
    super.layout()
    if follow { pinToBottom() }
  }

  func pinToBottom() {
    guard contentSize.width > 40, let textView = documentView as? NSTextView,
      let layoutManager = textView.layoutManager, let container = textView.textContainer
    else { return }
    isPinning = true
    defer { isPinning = false }
    // Lay everything out now, so the height — and with it the bottom — is final before
    // anything is drawn; otherwise the view visibly chases a bottom that keeps moving.
    layoutManager.ensureLayout(for: container)
    textView.sizeToFit()
    let y = max(0, textView.frame.height - contentView.bounds.height)
    contentView.scroll(to: NSPoint(x: contentView.bounds.origin.x, y: y))
    reflectScrolledClipView(contentView)
  }
}

/// An NSTextView rather than a SwiftUI list: selection spans lines, and appending is cheap.
///
/// Follow behaves like a chat: new lines keep the view pinned to the bottom, scrolling up to
/// read pauses it (and leaves the position alone), and scrolling back down resumes it.
private struct LogTextView: NSViewRepresentable {
  let lines: [LogLine]
  let resetKey: String
  @Binding var follow: Bool
  let wrap: Bool

  @MainActor
  final class Coordinator {
    var resetKey = ""
    var count = 0
    var wrap: Bool?
    var follow: Binding<Bool>
    /// Set while we change the text, so only the user's own scrolling toggles follow.
    var updating = false
    var observer: NSObjectProtocol?

    init(follow: Binding<Bool>) { self.follow = follow }

    func scrolled(_ scrollView: LogScrollView) {
      guard !updating, !scrollView.isPinning, let document = scrollView.documentView else { return }
      let atBottom = scrollView.contentView.bounds.maxY >= document.frame.maxY - 8
      if follow.wrappedValue != atBottom { follow.wrappedValue = atBottom }
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(follow: $follow) }

  func makeNSView(context: Context) -> LogScrollView {
    // TextKit 1 on purpose: TextKit 2 estimates the height of text it has not laid out
    // yet, so on a long log the scroller jumps and "scroll to end" stops short.
    let textView = NSTextView(usingTextLayoutManager: false)
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.drawsBackground = true
    textView.backgroundColor = .textBackgroundColor
    textView.textContainerInset = NSSize(width: 10, height: 8)
    textView.font = LogStyler.font
    textView.isVerticallyResizable = true
    textView.minSize = .zero
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: .greatestFiniteMagnitude
    )
    textView.autoresizingMask = [.width]
    textView.layoutManager?.backgroundLayoutEnabled = false

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
    guard let textView = scrollView.documentView as? NSTextView, let storage = textView.textStorage
    else { return }
    let state = context.coordinator
    state.follow = $follow
    scrollView.follow = follow
    state.updating = true
    defer { state.updating = false }

    if state.wrap != wrap {
      setWrapping(wrap, scrollView, textView)
      state.wrap = wrap
    }
    if state.resetKey != resetKey || lines.count < state.count {
      storage.setAttributedString(LogStyler.attributed(lines[...], continuing: false))
    } else if lines.count > state.count {
      storage.append(LogStyler.attributed(lines[state.count...], continuing: state.count > 0))
    }
    state.resetKey = resetKey
    state.count = lines.count
    if follow { scrollView.pinToBottom() }
  }

  private func setWrapping(_ wrap: Bool, _ scrollView: NSScrollView, _ textView: NSTextView) {
    guard let container = textView.textContainer else { return }
    scrollView.hasHorizontalScroller = !wrap
    textView.isHorizontallyResizable = !wrap
    container.widthTracksTextView = wrap
    if wrap {
      container.containerSize = NSSize(
        width: scrollView.contentSize.width,
        height: .greatestFiniteMagnitude
      )
      textView.frame.size.width = scrollView.contentSize.width
    } else {
      container.containerSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: .greatestFiniteMagnitude
      )
      textView.maxSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: .greatestFiniteMagnitude
      )
    }
  }
}

/// How log lines look: the program's own ANSI colours when it sent any, otherwise a colour
/// for the level, with a leading timestamp dimmed.
@MainActor
private enum LogStyler {
  static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
  static let boldFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)

  static func attributed(_ lines: ArraySlice<LogLine>, continuing: Bool) -> NSAttributedString {
    let out = NSMutableAttributedString()
    let newline = NSAttributedString(string: "\n", attributes: [.font: font])
    for (offset, line) in lines.enumerated() {
      if continuing || offset > 0 { out.append(newline) }
      out.append(attributed(line))
    }
    return out
  }

  private static func attributed(_ line: LogLine) -> NSAttributedString {
    let own = line.hasOwnColor
    let base: NSColor = own ? .textColor : levelColor(line.level)
    let out = NSMutableAttributedString()
    for run in line.runs {
      out.append(
        NSAttributedString(string: run.text, attributes: attributes(run.style, base: base))
      )
    }
    let ownTimestamp = NSRange(location: 0, length: line.timestampLength)
    if let time = line.time {
      if line.timestampLength > 0, line.timestampLength <= out.length {
        out.deleteCharacters(in: ownTimestamp)
      }
      out.insert(
        NSAttributedString(
          string: format(time) + "  ",
          attributes: [
            .font: font, .foregroundColor: NSColor.tertiaryLabelColor,
          ]
        ),
        at: 0
      )
    } else if !own, line.level != .debug, line.timestampLength > 0,
      line.timestampLength <= out.length
    {
      out.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: ownTimestamp)
    }
    return out
  }

  /// Local time; lines from an earlier day also say which day.
  private static func format(_ time: Date) -> String {
    Calendar.current.isDateInToday(time)
      ? timeFormatter.string(from: time) : dayTimeFormatter.string(from: time)
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private static let dayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    formatter.dateFormat = formatter.dateFormat + " HH:mm:ss"
    return formatter
  }()

  private static func levelColor(_ level: LogLevel?) -> NSColor {
    switch level {
    case .error: .systemRed
    case .warning: .systemOrange
    case .debug: .secondaryLabelColor
    case nil: .textColor
    }
  }

  private static func attributes(_ style: LogStyle, base: NSColor) -> [NSAttributedString.Key: Any]
  {
    var color = style.foreground.map(nsColor) ?? base
    if style.isDim { color = color.withAlphaComponent(0.6) }
    var attributes: [NSAttributedString.Key: Any] = [
      .font: style.isBold ? boldFont : font,
      .foregroundColor: color,
    ]
    if let background = style.background {
      attributes[.backgroundColor] = nsColor(background).withAlphaComponent(0.3)
    }
    if style.isUnderlined { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
    return attributes
  }

  /// The 16 basic colours map to system colours so they read in light and dark mode alike;
  /// black and white become label colours rather than vanishing into the background.
  private static func nsColor(_ color: LogColor) -> NSColor {
    switch color {
    case .rgb(let r, let g, let b):
      return NSColor(
        srgbRed: CGFloat(r) / 255,
        green: CGFloat(g) / 255,
        blue: CGFloat(b) / 255,
        alpha: 1
      )
    case .indexed(let index):
      switch index {
      case 0: return .labelColor
      case 1, 9: return .systemRed
      case 2, 10: return .systemGreen
      case 3, 11: return .systemOrange
      case 4, 12: return .systemBlue
      case 5, 13: return .systemPurple
      case 6, 14: return .systemTeal
      case 7: return .secondaryLabelColor
      case 8: return .tertiaryLabelColor
      case 15: return .labelColor
      case 16...231:
        let n = index - 16
        let level = { (v: Int) -> CGFloat in v == 0 ? 0 : CGFloat(55 + v * 40) / 255 }
        return NSColor(
          srgbRed: level(n / 36),
          green: level(n / 6 % 6),
          blue: level(n % 6),
          alpha: 1
        )
      default:
        let gray = CGFloat(8 + (index - 232) * 10) / 255
        return NSColor(white: gray, alpha: 1)
      }
    }
  }
}
