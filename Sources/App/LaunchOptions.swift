import AppKit

private enum Constants {
  static let openWindowKey = "HangarOpenWindowAtLaunch"
  static let selectKey = "HangarSelect"
  static let appearanceKey = "HangarAppearance"
  static let tabKey = "HangarTab"
  static let sqlKey = "HangarSQL"
  static let lightAppearance = "light"
  static let darkAppearance = "dark"
  static let profilePrefix = "profile:"
  static let vmPrefix = "vm:"
  static let containerPrefix = "container:"
}

/// Developer switches for screenshots and UI work, read from launch arguments, e.g.
/// `open Hangar.app --args -HangarOpenWindowAtLaunch YES -HangarSelect container:db`.
/// Launch arguments land in the argument domain of UserDefaults, which nothing persists.
enum LaunchOptions {
  /// Whether to open the main window right away instead of waiting for the menu bar.
  static var opensWindowAtLaunch: Bool {
    UserDefaults.standard.bool(forKey: Constants.openWindowKey)
  }

  /// The sidebar item to select at launch: `profile:<name>`, `vm:<name>` or
  /// `container:<name>`.
  static var selection: (kind: SelectionKind, name: String)? {
    guard let value = UserDefaults.standard.string(forKey: Constants.selectKey) else {
      return nil
    }
    let prefixes: [(String, SelectionKind)] = [
      (Constants.profilePrefix, .profile),
      (Constants.vmPrefix, .vm),
      (Constants.containerPrefix, .container),
    ]
    for (prefix, kind) in prefixes where value.hasPrefix(prefix) {
      return (kind, String(value.dropFirst(prefix.count)))
    }
    return nil
  }

  /// `-HangarAppearance light|dark` forces a theme regardless of the system setting, so
  /// both themes can be screenshotted.
  static var appearance: NSAppearance? {
    switch UserDefaults.standard.string(forKey: Constants.appearanceKey) {
    case Constants.lightAppearance: NSAppearance(named: .aqua)
    case Constants.darkAppearance: NSAppearance(named: .darkAqua)
    default: nil
    }
  }

  /// `-HangarTab database|structure|sql` opens a container on its Database tab, in that view.
  static var databaseView: DatabaseModel.Tab? {
    switch UserDefaults.standard.string(forKey: Constants.tabKey) {
    case "database", "data": .data
    case "structure": .structure
    case "sql": .sql
    default: nil
    }
  }

  /// `-HangarSQL "<query>"` fills the SQL editor and runs it once connected.
  static var sql: String? { UserDefaults.standard.string(forKey: Constants.sqlKey) }

  /// What a `-HangarSelect` value names.
  enum SelectionKind {
    case profile
    case vm
    case container
  }
}
