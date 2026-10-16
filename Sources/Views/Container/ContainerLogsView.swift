import AppKit
import SwiftUI

private enum Constants {
  static let filterWidth: CGFloat = 200
  static let flushIntervalMilliseconds = 100
}

/// A container's live output with its controls: filter, Wrap, Follow and copy. Re-attaches
/// when the container starts or restarts. `leading` sits at the start of the control row —
/// the Logs/Database tabs.
struct ContainerLogsView<Leading: View>: View {
  let container: Container
  let docker: DockerClient?
  @ViewBuilder let leading: Leading

  @State private var buffer = LogBuffer()
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
    // A new key re-attaches: another container, or this one coming back up.
    .task(id: "\(container.id)|\(container.isRunning)") {
      isFollowing = true
      await attach()
    }
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

  /// Why the stream stopped — "Container is not running", "Stream ended" — under the lines.
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

  private func attach() async {
    let buffer = buffer
    buffer.reset()
    guard let docker else {
      buffer.end("No Docker socket")
      return
    }
    let flusher = Task { @MainActor in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(Constants.flushIntervalMilliseconds))
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
