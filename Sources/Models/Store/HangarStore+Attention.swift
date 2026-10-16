import Foundation

// MARK: - Attention

extension HangarStore {
  /// A profile member has crashed or turned unhealthy — the menu bar icon shows the alert
  /// badge. Containers outside profiles do not count: old exited ones would keep it lit.
  var needsAttention: Bool {
    let troubled: Set<MachineStatus.Kind> = [.error, .unhealthy]
    return profiles.contains { profile in
      members(of: profile).containers.contains { troubled.contains($0.machineStatus.kind) }
    }
  }
}
