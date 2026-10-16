import Foundation

/// What a VM's `config.plist` says about how it runs.
struct VMConfiguration: Equatable, Sendable {
  /// `QEMU` (emulation or virtualisation through QEMU) or `Apple` (Virtualization.framework).
  let backend: String
  /// `aarch64`, `x86_64` …; nil for Apple VMs, which always match the host.
  let architecture: String?
  /// Nil or 0 when UTM picks the count itself.
  let cpuCount: Int?
  let memoryMiB: Int?
}
