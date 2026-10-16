import Foundation

private enum Constants {
  static let composeProjectLabel = "com.docker.compose.project"
  static let composeServiceLabel = "com.docker.compose.service"
  static let runningState = "running"
  static let restartingState = "restarting"
  static let tcp = "tcp"
  /// Docker's own short form of a container id.
  static let shortIDLength = 12
}

/// A container as `GET /containers/json` reports it; decode with `JSONDecoder.docker`.
struct Container: Identifiable, Decodable, Sendable, Hashable {
  let id: String
  let names: [String]
  let image: String
  let state: String
  let status: String
  let labels: [String: String]?
  /// Null, not empty, when the container publishes nothing.
  let ports: [ContainerPort]?

  /// The name without Docker's leading slash; the short id if it has none.
  var name: String {
    names.first.map { String($0.drop { $0 == "/" }) } ?? shortID
  }

  /// The first characters of the id, as `docker ps` shows it.
  var shortID: String { String(id.prefix(Constants.shortIDLength)) }

  /// The compose project this container belongs to, if any.
  var composeProject: String? { labels?[Constants.composeProjectLabel] }

  /// The compose service it runs, if any.
  var composeService: String? { labels?[Constants.composeServiceLabel] }

  /// The service name inside a compose project, the container name otherwise.
  var displayName: String { composeService ?? name }

  var isRunning: Bool { state == Constants.runningState }
  var isRestarting: Bool { state == Constants.restartingState }

  /// Host ports published as TCP, deduplicated (Docker lists IPv4 and IPv6 separately).
  var publishedPorts: [Int] {
    Array(Set((ports ?? []).filter { $0.type == Constants.tcp }.compactMap(\.publicPort))).sorted()
  }
}
