import Foundation

// MARK: - Summary

extension ProfileMembers {
  /// What is holding the profile back: "portal-api isn't running", "db and 2 more aren't
  /// running". Nil when everything is up or there is nothing in it.
  var notRunningSummary: String? {
    let names =
      vms.filter { !$0.isRunning }.map(\.name)
      + containers.filter { !$0.isRunning }.map(\.name)
    guard let first = names.first else {
      guard missing > 0 else { return nil }
      return missing == 1 ? "1 member is missing" : "\(missing) members are missing"
    }
    return names.count == 1
      ? "\(first) isn't running" : "\(first) and \(names.count - 1) more aren't running"
  }
}
