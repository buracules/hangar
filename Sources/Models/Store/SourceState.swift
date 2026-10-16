import Foundation

/// Whether a source of machines — UTM or Docker — can be read.
enum SourceState: Equatable {
  case loading
  case ready
  /// Installed but not reachable (Docker daemon down, utmctl failing), with the reason.
  case offline(String)
  /// Not installed at all.
  case missing
}
