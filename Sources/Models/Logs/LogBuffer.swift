import Foundation
import Observation

private enum Constants {
  /// Lines kept per stream; a chatty container cannot grow the buffer beyond this.
  static let capacity = 5000
  /// What is kept when the cap is hit — trimming in batches avoids a redraw on every line.
  static let trimmedCount = 4000
}

/// The lines of one log stream. Incoming lines are staged and flushed on a short timer, so a
/// burst — the initial tail especially — reaches the screen as one update instead of dozens.
@MainActor
@Observable
final class LogBuffer {
  private(set) var lines: [LogLine] = []
  /// Bumped whenever lines are replaced or dropped rather than appended, so the text view
  /// knows to redraw instead of appending.
  private(set) var generation = 0
  /// Why the stream stopped, once it has.
  private(set) var endReason: String?

  @ObservationIgnored private var staged: [LogLine] = []

  /// Empties the buffer for a new stream.
  func reset() {
    lines = []
    staged = []
    endReason = nil
    generation += 1
  }

  /// Holds lines until the next `flush()`.
  func stage(_ new: [LogLine]) { staged += new }

  /// Publishes staged lines, trimming the oldest when over capacity.
  func flush() {
    guard !staged.isEmpty else { return }
    lines += staged
    staged = []
    if lines.count > Constants.capacity {
      lines.removeFirst(lines.count - Constants.trimmedCount)
      generation += 1
    }
  }

  /// Marks the stream finished, publishing whatever was still staged.
  func end(_ reason: String) {
    flush()
    endReason = reason
  }
}
