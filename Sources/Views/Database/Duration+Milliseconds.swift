import Foundation

private enum Constants {
  static let millisecondsPerSecond = 1000.0
  static let attosecondsPerMillisecond = 1e15
}

// MARK: - Milliseconds

extension Duration {
  /// `34 ms`, as result footers show timing.
  var millisecondsText: String {
    let seconds = Double(components.seconds) * Constants.millisecondsPerSecond
    let fraction = Double(components.attoseconds) / Constants.attosecondsPerMillisecond
    return "\(Int((seconds + fraction).rounded())) ms"
  }
}
