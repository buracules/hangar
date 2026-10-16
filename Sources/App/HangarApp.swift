import SwiftUI

private enum Constants {
  static let windowID = "main"
  static let windowTitle = "Hangar"
  static let defaultWindowWidth: CGFloat = 1000
  static let defaultWindowHeight: CGFloat = 640
  static let idleIcon = "shippingbox"
  static let activeIcon = "shippingbox.fill"
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
      // The label is alive for the app's lifetime, so polling starts at launch.
      Image(systemName: store.runningCount > 0 ? Constants.activeIcon : Constants.idleIcon)
        .task { store.startPolling() }
    }
    .menuBarExtraStyle(.window)

    Window(Constants.windowTitle, id: Constants.windowID) {
      MainWindow(store: store)
    }
    // A menu bar app: the window opens only when asked for, never at launch.
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
    .defaultSize(width: Constants.defaultWindowWidth, height: Constants.defaultWindowHeight)
  }
}
