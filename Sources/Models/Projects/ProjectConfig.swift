import Foundation

/// A project's `.hangar.json`: how to run it, where it listens and how to check on it. Every
/// field is optional; what is missing is detected from the folder.
struct ProjectConfig: Codable, Equatable, Sendable {
  /// The name shown in Hangar; the folder name otherwise.
  var name: String?
  /// A shell command, run with zsh in the project folder: `pnpm dev`.
  var command: String?
  /// The port it should listen on, also passed as `PORT`.
  var port: Int?
  /// Where Hangar's proxy serves it: `canvas.localhost`; `<name>.localhost` by default.
  var hostname: String?
  /// The path Open in Browser goes to: `/`.
  var openPath: String?
  /// A path that answers 2xx while the app is healthy: `/api/health`.
  var healthCheck: String?
  /// Open the browser once the port answers.
  var autoOpen: Bool?
  /// Start it again after it exits with an error.
  var restartOnCrash: Bool?
  /// Extra environment variables.
  var env: [String: String]?
}
