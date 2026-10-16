import Foundation

/// One port of a container, published to the host or only exposed.
struct ContainerPort: Decodable, Sendable, Hashable {
  /// The host port; nil when the port is only exposed.
  let publicPort: Int?
  let privatePort: Int
  /// `tcp` or `udp`.
  let type: String
}
