import SwiftUI

// Pieces shared by the menu bar panel and the main window.

extension VirtualMachine {
  var statusColor: Color {
    isRunning ? .green : isPaused ? .yellow : isTransitioning ? .orange : .secondary
  }
}

extension Container {
  var statusColor: Color { isRunning ? .green : isRestarting ? .orange : .secondary }
}

extension ProfileMembers {
  var statusColor: Color { areAllUp ? .green : runningCount > 0 ? .yellow : .secondary }
}

struct StatusDot: View {
  let color: Color
  var body: some View {
    Circle().fill(color).frame(width: 8, height: 8)
  }
}

struct IconButton: View {
  let systemImage: String
  let help: String
  let action: () -> Void

  init(_ systemImage: String, help: String, action: @escaping () -> Void) {
    self.systemImage = systemImage
    self.help = help
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage).frame(width: 18, height: 18)
    }
    .buttonStyle(.borderless)
    .help(help)
  }
}

struct ProfileMembershipMenu: View {
  let store: HangarStore
  let contains: (Profile) -> Bool
  let toggle: (Profile) -> Void

  var body: some View {
    if store.profiles.isEmpty {
      Text("No profiles yet")
    } else {
      Section("Profiles") {
        ForEach(store.profiles) { profile in
          Toggle(
            profile.name,
            isOn: Binding(get: { contains(profile) }, set: { _ in toggle(profile) })
          )
        }
      }
    }
  }
}
