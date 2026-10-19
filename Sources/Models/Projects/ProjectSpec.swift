import Foundation

/// How to run a project, from its `.hangar.json` with the gaps filled in by detection.
struct ProjectSpec: Equatable, Sendable {
  /// Where the command came from.
  enum Source: Equatable, Sendable {
    case config
    case detected
    /// No command could be worked out; the project needs a `.hangar.json`.
    case none
  }

  let name: String
  /// "Next.js", "Vite", "Node", "Django", "FastAPI", "Python" or "Custom".
  let kind: String
  let command: String?
  let source: Source
  /// The port it is asked to use; nil when nothing suggests one.
  let port: Int?
  /// Whether the port is fixed by the config — then a taken port is a conflict rather than a
  /// reason to pick another.
  let isPortFixed: Bool
  /// Appended to the command with the port number when the tool ignores `PORT`:
  /// `--port`.
  let portFlag: String?
  let openPath: String
  /// `<name>.localhost`, from the config's `hostname` or the project's name.
  let hostname: String
  let healthCheck: String?
  let autoOpen: Bool
  let restartOnCrash: Bool
  let env: [String: String]

  /// The command to run on `port`, with the port flag added when the tool needs one.
  func launchCommand(port: Int?) -> String? {
    guard let command else { return nil }
    guard let port, let portFlag else { return command }
    return [command, portFlag, String(port)].filter { !$0.isEmpty }.joined(separator: " ")
  }
}
