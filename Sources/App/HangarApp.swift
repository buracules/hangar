import SwiftUI

private enum Constants {
  static let windowID = "main"
  static let windowTitle = "Hangar"
  /// The design's window size.
  static let defaultWindowWidth: CGFloat = 1280
  static let defaultWindowHeight: CGFloat = 820
  /// Template images from the design: outline when idle, the door filled when anything runs.
  static let idleIcon = "MenuBarIcon"
  static let activeIcon = "MenuBarIconUp"
}

/// The menu bar extra and the main window, sharing one store.
struct HangarApp: App {
  /// The id `openWindow` uses to bring up the main window.
  static let mainWindowID = Constants.windowID

  @State private var store = HangarStore()

  var body: some Scene {
    MenuBarExtra {
      TrayPanel(store: store)
    } label: {
      MenuBarLabel(store: store)
    }
    .menuBarExtraStyle(.window)

    Window(Constants.windowTitle, id: Constants.windowID) {
      MainWindowView(store: store)
    }
    // A menu bar app: the window opens only when asked for, never at launch.
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
    .defaultSize(width: Constants.defaultWindowWidth, height: Constants.defaultWindowHeight)
  }
}

/// The menu bar icon. It is alive for the app's lifetime, so it starts polling at launch —
/// and opens the main window then if `LaunchOptions` asks for it.
private struct MenuBarLabel: View {
  let store: HangarStore
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Image(store.runningCount > 0 ? Constants.activeIcon : Constants.idleIcon)
      .task {
        if let appearance = LaunchOptions.appearance { NSApp.appearance = appearance }
        store.startPolling()
        if LaunchOptions.opensWindowAtLaunch { openWindow(id: Constants.windowID) }
      }
  }
}
