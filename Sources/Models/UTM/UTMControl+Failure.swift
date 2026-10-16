import Foundation

// MARK: - Failure

extension UTMControl {
  /// What can go wrong driving UTM.
  enum Failure: LocalizedError, Equatable {
    case commandFailed(command: String, output: String)
    case notInstalled
    case notRunning
    case appNotFound
    case didNotStart(vmName: String)
    case noIPAddress(vmName: String)
    case automationDenied

    var errorDescription: String? {
      switch self {
      case .commandFailed(let command, let output):
        output.isEmpty ? "utmctl \(command) failed." : output
      case .notInstalled: "UTM is not installed."
      case .notRunning: "UTM is not running."
      case .appNotFound: "UTM.app could not be found."
      case .didNotStart(let name): "UTM did not start \(name)."
      case .noIPAddress(let name): "\(name) reported no IP address."
      case .automationDenied:
        "macOS isn't letting Hangar control UTM. Turn on UTM under Hangar in System Settings "
          + "› Privacy & Security › Automation."
      }
    }
  }
}
