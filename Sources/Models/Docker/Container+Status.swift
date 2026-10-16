import Foundation

// MARK: - Status

extension Container {
  /// The result of a container's health check, as `docker ps` reports it.
  enum Health: String, Sendable {
    case healthy
    case unhealthy
    case starting
  }

  /// From the status text: `Up 2 hours (healthy)`, `Up 3 seconds (health: starting)`.
  /// Nil when the image has no health check.
  var health: Health? {
    if status.contains("(healthy)") { return .healthy }
    if status.contains("(unhealthy)") { return .unhealthy }
    if status.contains("(health: starting)") { return .starting }
    return nil
  }

  /// From the status text of a stopped container: `Exited (137) 2 days ago` → 137.
  var exitCode: Int? {
    guard let match = status.firstMatch(of: /^Exited \((-?\d+)\)/) else { return nil }
    return Int(match.1)
  }

  /// How long the status says it has been up or down, without the extras:
  /// `Up 2 hours (healthy)` → `Up 2 hours`, `Exited (0) 3 minutes ago` → `3 minutes ago`.
  var statusDetail: String {
    let health = /\s*\((healthy|unhealthy|health: starting|Paused)\)$/
    return status.replacing(health, with: "").replacing(/^Exited \(-?\d+\)\s*/, with: "")
  }

  /// The derived on-screen status.
  var machineStatus: MachineStatus { MachineStatus(self) }
}
