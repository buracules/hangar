import SwiftUI

/// "Add Member": VMs and containers not in the profile yet, containers grouped by compose
/// project, plus whole compose projects at once.
struct ProfileAddMemberMenu: View {
  let profile: Profile
  let store: HangarStore

  var body: some View {
    Menu("Add Member") {
      Menu("Virtual Machines") {
        ForEach(vms) { vm in
          Button(vm.name) { store.add(vm, to: profile) }
        }
        if vms.isEmpty { Text("All VMs are members") }
      }
      Menu("Containers") { containersMenu }
      Button("Projects — coming soon") {}.disabled(true)
    }
    .fixedSize()
  }

  private var vms: [VirtualMachine] {
    store.vms.filter { !profile.vmIDs.contains($0.id) }
  }

  private func isCandidate(_ container: Container) -> Bool {
    !profile.containerNames.contains(container.name)
  }

  private var groups: [ComposeGroup] {
    store.composeGroups.filter { $0.containers.contains(where: isCandidate) }
  }

  @ViewBuilder
  private var containersMenu: some View {
    ForEach(groups) { group in
      Section(group.id) {
        ForEach(group.containers.filter(isCandidate)) { containerButton($0) }
      }
    }
    let standalone = store.standaloneContainers.filter(isCandidate)
    if !standalone.isEmpty {
      Divider()
      ForEach(standalone) { containerButton($0) }
    }
    if groups.isEmpty && standalone.isEmpty { Text("All containers are members") }
    if !groups.isEmpty {
      Divider()
      Menu("Add Whole Compose Project") {
        ForEach(groups) { group in
          Button(group.id) { store.add(group, to: profile) }
        }
      }
    }
  }

  private func containerButton(_ container: Container) -> some View {
    Button {
      store.add(container, to: profile)
    } label: {
      Label(container.name, systemImage: container.machineStatus.kind.symbolName)
    }
  }
}
