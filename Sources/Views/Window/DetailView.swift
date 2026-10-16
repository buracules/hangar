import SwiftUI

/// The selected item's detail, or why there is none.
struct DetailView: View {
  let store: HangarStore
  @Binding var selection: SidebarItem?

  var body: some View {
    switch selection {
    case .profile(let id):
      if let profile = store.profiles.first(where: { $0.id == id }) {
        ProfileDetailView(profile: profile, store: store, selection: $selection)
      } else {
        gone("This profile was deleted.")
      }
    case .vm(let id):
      if let vm = store.vms.first(where: { $0.id == id }) {
        VMDetailView(vm: vm, store: store)
      } else {
        gone("This VM is no longer in UTM.")
      }
    case .container(let name):
      if let container = store.containers.first(where: { $0.name == name }) {
        ContainerDetailView(container: container, store: store)
      } else {
        gone("This container no longer exists.")
      }
    case nil:
      ContentUnavailableView(
        "Nothing selected",
        systemImage: "square.stack.3d.up",
        description: Text("Pick a profile, VM or container from the sidebar.")
      )
    }
  }

  private func gone(_ text: String) -> some View {
    ContentUnavailableView(
      "Gone",
      systemImage: "questionmark.square.dashed",
      description: Text(text)
    )
  }
}
