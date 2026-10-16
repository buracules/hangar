import Foundation

private enum Constants {
  static let libraryPath = "Library/Containers/\(UTMControl.bundleIdentifier)/Data/Documents"
  static let bundleExtension = "utm"
  static let configFile = "config.plist"
  static let informationKey = "Information"
  static let uuidKey = "UUID"
  static let nameKey = "Name"
  static let backendKey = "Backend"
  static let systemKey = "System"
  static let architectureKey = "Architecture"
  static let cpuCountKey = "CPUCount"
  static let memoryKey = "MemorySize"
}

// MARK: - Library

extension UTMControl {
  /// VMs in UTM's default library, read straight from their bundles so it works while UTM
  /// is closed. Every VM is stopped then: VMs run inside UTM and die with it. Touching
  /// UTM's container triggers macOS's "access data from other apps" prompt once.
  static func libraryVMs() -> [VirtualMachine] {
    libraryBundles().compactMap(vm(inBundle:))
  }

  /// How a VM in the default library is configured; nil when its bundle is elsewhere or
  /// cannot be read.
  static func configuration(forVM id: String) -> VMConfiguration? {
    for bundle in libraryBundles() {
      guard let plist = config(in: bundle),
        let info = plist[Constants.informationKey] as? [String: Any],
        info[Constants.uuidKey] as? String == id
      else { continue }
      let system = plist[Constants.systemKey] as? [String: Any] ?? [:]
      return VMConfiguration(
        backend: plist[Constants.backendKey] as? String ?? "",
        architecture: system[Constants.architectureKey] as? String,
        cpuCount: system[Constants.cpuCountKey] as? Int,
        memoryMiB: system[Constants.memoryKey] as? Int
      )
    }
    return nil
  }

  private static func libraryBundles() -> [URL] {
    let library = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(Constants.libraryPath)
    let bundles = try? FileManager.default.contentsOfDirectory(
      at: library,
      includingPropertiesForKeys: nil
    )
    return (bundles ?? []).filter { $0.pathExtension == Constants.bundleExtension }
  }

  private static func config(in bundle: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: bundle.appendingPathComponent(Constants.configFile))
    else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
  }

  /// The VM a `.utm` bundle describes, from its `config.plist`.
  private static func vm(inBundle bundle: URL) -> VirtualMachine? {
    guard let info = config(in: bundle)?[Constants.informationKey] as? [String: Any],
      let uuid = info[Constants.uuidKey] as? String
    else { return nil }
    let fallbackName = bundle.deletingPathExtension().lastPathComponent
    return .stopped(id: uuid, name: info[Constants.nameKey] as? String ?? fallbackName)
  }
}
