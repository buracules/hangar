import SwiftUI

private enum Constants {
  /// `--ease: cubic-bezier(.2, .8, .2, 1)` — a quick start that settles softly.
  static let easeX1 = 0.2
  static let easeY1 = 0.8
  static let easeX2 = 0.2
  static let easeY2 = 1.0
}

/// Durations and the easing curve. Each value names its CSS token.
enum Motion {
  /// Hover and press feedback. `--dur-fast`
  static let fast = 0.12
  /// Most transitions. `--dur-base`
  static let base = 0.2
  /// Panels and larger moves. `--dur-slow`
  static let slow = 0.32
  /// One turn of the ◌ starting/stopping symbol. `--dur-spin`
  static let spin = 1.2

  /// The design's curve over `duration` seconds.
  static func ease(_ duration: Double = base) -> Animation {
    .timingCurve(
      Constants.easeX1,
      Constants.easeY1,
      Constants.easeX2,
      Constants.easeY2,
      duration: duration
    )
  }
}
