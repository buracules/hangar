import SwiftUI

/// One binary, two faces: with a CLI command it runs that and exits, otherwise it is the
/// menu bar app.
@main
enum Entry {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard CLI.handles(arguments) else {
            HangarApp.main()
            return
        }
        Task { @MainActor in
            exit(await CLI.run(arguments))
        }
        dispatchMain()
    }
}

struct HangarApp: App {
    @State private var store = TrayStore()

    var body: some Scene {
        MenuBarExtra {
            TrayPanel(store: store)
        } label: {
            // The label is alive for the app's lifetime, so polling starts at launch.
            Image(systemName: store.runningCount > 0 ? "shippingbox.fill" : "shippingbox")
                .task { store.startPolling() }
        }
        .menuBarExtraStyle(.window)
    }
}
