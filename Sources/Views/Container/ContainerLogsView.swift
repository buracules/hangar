import SwiftUI

private enum Constants {
  static let flushIntervalMilliseconds = 100
}

/// A container's live output. Re-attaches when the container starts or restarts. `leading`
/// sits at the start of the control row — the Logs/Database tabs.
struct ContainerLogsView<Leading: View>: View {
  let container: Container
  let docker: DockerClient?
  @ViewBuilder let leading: Leading

  @State private var buffer = LogBuffer()

  var body: some View {
    LogPane(buffer: buffer) { leading }
      // A new key re-attaches: another container, or this one coming back up.
      .task(id: "\(container.id)|\(container.isRunning)") { await attach() }
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
