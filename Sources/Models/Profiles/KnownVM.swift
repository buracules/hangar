import Foundation

/// A VM as last reported by UTM, so it can be listed while UTM is closed.
struct KnownVM: Codable, Equatable, Sendable {
  let id: String
  let name: String
}
