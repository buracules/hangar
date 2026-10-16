import AppKit
import SwiftUI

private enum Constants {
  static let filterWidth: CGFloat = 200
}

/// A live log with its controls — filter, Wrap, Follow, copy — and why it ended, under the
/// lines. Whoever owns `buffer` feeds it; `leading` sits at the start of the control row.
struct LogPane<Leading: View>: View {
  let buffer: LogBuffer
  @ViewBuilder let leading: Leading

  @State private var filter = ""
  @State private var isFollowing = true
  @State private var isWrapping = true

  var body: some View {
    VStack(spacing: 0) {
      controls
      Divider()
      LogTextView(
        lines: visibleLines,
        resetKey: "\(buffer.generation)|\(filter)",
        isFollowing: $isFollowing,
        isWrapping: isWrapping
      )
      .overlay(alignment: .bottom) {
        if !isFollowing {
          JumpToLatestButton { isFollowing = true }
            .padding(.bottom, Spacing.md)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .animation(Motion.ease(), value: isFollowing)
      if let reason = buffer.endReason { endStrip(reason) }
    }
    // A fresh stream starts at its newest line.
    .onChange(of: buffer.generation) { isFollowing = true }
  }

  private var controls: some View {
    HStack(spacing: Spacing.xs) {
      leading
      Spacer()
      TextField("Filter", text: $filter, prompt: Text("Filter"))
        .textFieldStyle(.roundedBorder)
        .frame(width: Constants.filterWidth)
      Toggle(isOn: $isWrapping) { Label("Wrap", systemImage: "text.alignleft") }
      Toggle(isOn: $isFollowing) { Label("Follow", systemImage: "arrow.down.to.line") }
      Button("Copy visible logs", systemImage: "doc.on.doc", action: copyVisibleLines)
        .labelStyle(.iconOnly)
    }
    .toggleStyle(.button)
    .buttonStyle(.accessoryBar)
    .font(.ui(FontSize.callout))
    .padding(.vertical, Spacing.xs)
    .padding(.leading, Spacing.lg)
    .padding(.trailing, Spacing.md)
  }

  /// Why the stream stopped — "Container is not running", "Exited with code 1".
  private func endStrip(_ reason: String) -> some View {
    VStack(spacing: 0) {
      Divider()
      Text(reason)
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(Color.tertiaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.md)
    }
    .background(Color.backgroundContent)
  }

  private var visibleLines: [LogLine] {
    filter.isEmpty
      ? buffer.lines : buffer.lines.filter { $0.text.localizedCaseInsensitiveContains(filter) }
  }

  private func copyVisibleLines() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(
      visibleLines.map(\.text).joined(separator: "\n"),
      forType: .string
    )
  }
}
