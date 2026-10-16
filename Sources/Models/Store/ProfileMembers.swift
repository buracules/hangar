import Foundation

/// A profile's members as they exist right now.
struct ProfileMembers {
  let vms: [VirtualMachine]
  let containers: [Container]
  /// Members that no longer exist (VM deleted, container removed).
  let missing: Int

  var runningCount: Int {
    vms.filter(\.isRunning).count + containers.filter(\.isRunning).count
  }

  var total: Int { vms.count + containers.count }

  /// Every member exists and is running.
  var areAllUp: Bool { total > 0 && runningCount == total }
}
