import Foundation

/// The state shared by the menu bar app and the CLI. JSON rather than UserDefaults: the CLI
/// runs through a symlink, outside the app bundle, and would get a different defaults
/// domain. Profiles are also meant to be hand-editable.
enum SharedFiles {
  static let profiles = SharedFile<[Profile]>(name: "profiles.json")
  static let knownVMs = SharedFile<[KnownVM]>(name: "known-vms.json")
  static let activity = SharedFile<[String: [ActivityEvent]]>(name: "activity.json")
}
