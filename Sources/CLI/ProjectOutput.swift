import Foundation

/// A project in `--json` output: where it is and how Hangar would run it.
struct ProjectOutput: Encodable {
  let name: String
  let path: String
  let kind: String
  let command: String?
  /// "config", "detected" or "none".
  let commandSource: String
  let port: Int?

  @MainActor
  init(_ project: Project, _ store: HangarStore) {
    let spec = store.spec(for: project)
    name = spec.name
    path = project.path
    kind = spec.kind
    command = spec.launchCommand(port: spec.port)
    switch spec.source {
    case .config: commandSource = "config"
    case .detected: commandSource = "detected"
    case .none: commandSource = "none"
    }
    port = spec.port
  }
}
