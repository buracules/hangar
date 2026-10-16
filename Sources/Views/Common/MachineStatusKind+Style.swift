import SwiftUI

// MARK: - Style

extension MachineStatus.Kind {
  /// The shape, as the handoff names them.
  var symbolName: String {
    switch self {
    case .running: "circle.fill"
    case .paused: "circle.lefthalf.filled"
    case .busy: "circle.dotted"
    case .stopped: "circle"
    case .error: "xmark"
    case .unhealthy: "exclamationmark.triangle.fill"
    }
  }

  /// The shape's colour.
  var color: Color {
    switch self {
    case .running: .statusRunning
    case .paused: .statusPaused
    case .busy: .statusBusy
    case .stopped: .statusStopped
    case .error: .statusError
    case .unhealthy: .statusUnhealthy
    }
  }

  /// The word's colour: a stopped machine's word is plain secondary text, not grey-on-grey.
  var wordColor: Color { self == .stopped ? .secondaryLabel : color }
}
