import Foundation

/// The outcome of one health check request.
struct HealthCheckResult: Equatable, Sendable {
  /// The HTTP status, or nil when nothing answered in time.
  let statusCode: Int?
  let milliseconds: Int
  let date: Date
}
