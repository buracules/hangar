import Foundation

/// A named set of VMs and containers started and stopped together.
struct Profile: Identifiable, Codable, Hashable, Sendable {
  var id = UUID()
  var name: String
  /// UTM VM UUIDs.
  var vmIDs: [String]
  /// Container names rather than ids: `docker compose up` recreates containers with new
  /// ids but the same name.
  var containerNames: [String]
}
