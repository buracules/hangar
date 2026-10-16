import AppKit

/// A menu item that runs a closure, for menus built in code.
final class MenuAction: NSObject {
  private let action: () -> Void

  private init(_ action: @escaping () -> Void) { self.action = action }

  /// An item that runs `action` when chosen. The item keeps its target alive.
  @MainActor
  static func item(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
    let target = MenuAction(action)
    let item = NSMenuItem(title: title, action: #selector(run), keyEquivalent: "")
    item.target = target
    item.representedObject = target
    return item
  }

  @objc private func run() { action() }
}
