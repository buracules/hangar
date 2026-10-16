import Foundation

private enum Constants {
  static let libraryPath = "Library/Containers/\(UTMControl.bundleIdentifier)/Data/Documents"
  static let bundleExtension = "utm"
  static let configFile = "config.plist"
  static let informationKey = "Information"
  static let uuidKey = "UUID"
  static let nameKey = "Name"
}

// MARK: - Library

extension UTMControl {
  /// VMs in UTM's default library, read straight from their bundles so it works while UTM
  /// is closed. Every VM is stopped then: VMs run inside UTM and die with it. Touching
  /// UTM's container triggers macOS's "access data from other apps" prompt once.
  static func libraryVMs() -> [VirtualMachine] {
    let library = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(Constants.libraryPath)
    let bundles = try? FileManager.default.contentsOfDirectory(
      at: library,
      includingPropertiesForKeys: nil
    )
    return (bundles ?? [])
      .filter { $0.pathExtension == Constants.bundleExtension }
      .compactMap(vm(inBundle:))
  }

  /// The VM a `.utm` bundle describes, from its `config.plist`.
  private static func vm(inBundle bundle: URL) -> VirtualMachine? {
    guard let data = try? Data(contentsOf: bundle.appendingPathComponent(Constants.configFile)),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let info = (plist as? [String: Any])?[Constants.informationKey] as? [String: Any],
      let uuid = info[Constants.uuidKey] as? String
    else { return nil }
    let fallbackName = bundle.deletingPathExtension().lastPathComponent
    return .stopped(id: uuid, name: info[Constants.nameKey] as? String ?? fallbackName)
  }
}
