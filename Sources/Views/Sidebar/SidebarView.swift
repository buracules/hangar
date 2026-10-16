import SwiftUI

private enum Constants {
  static let emptyLineSpacing: CGFloat = 2
}

/// Profiles, VMs and containers. Compose projects fold their containers away; search
/// narrows every section to matching names.
struct SidebarView: View {
  let store: HangarStore
  @Binding var selection: SidebarItem?
  let searchText: String

  @State private var collapsedGroups: Set<String> = []

  var body: some View {
    List(selection: $selection) {
      profilesSection
      vmsSection
      containersSection
    }
    .listStyle(.sidebar)
  }

  // MARK: Profiles

  private var profilesSection: some View {
    Section {
      if store.profiles.isEmpty {
        emptyState(
          "Group machines you start together.",
          action: "New Profile…",
          perform: newProfile
        )
      }
      ForEach(store.profiles.filter { matches($0.name) }) { profile in
        let members = store.members(of: profile)
        SidebarRow(
          leading: .profile,
          name: profile.name,
          trailing: "\(members.runningCount)/\(members.total)"
        )
        .tag(SidebarItem.profile(profile.id))
      }
    } header: {
      HStack {
        Text("Profiles")
        Spacer()
        Button(action: newProfile) {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
        .help("New profile")
        .accessibilityLabel("New profile")
      }
    }
  }

  private func newProfile() {
    selection = .profile(store.createEmptyProfile().id)
  }

  // MARK: VMs

  private var vmsSection: some View {
    Section("Virtual Machines") {
      switch store.utmState {
      case .missing:
        emptyState("UTM is not installed.", action: nil, perform: {})
      case .offline(let reason):
        emptyState(reason, action: "Open UTM", perform: openUTM)
      case .loading, .ready:
        if store.vms.isEmpty, store.utmState == .ready {
          emptyState("No VMs found in UTM.", action: "Open UTM", perform: openUTM)
        }
        ForEach(store.vms.filter { matches($0.name) }) { vm in
          let status = MachineStatus(vm)
          SidebarRow(
            leading: .status(status.kind),
            name: vm.name,
            trailing: status.kind == .stopped || status.kind == .running ? "" : status.word
          )
          .tag(SidebarItem.vm(vm.id))
        }
      }
    }
  }

  private func openUTM() {
    store.openApp(bundleIdentifier: UTMControl.bundleIdentifier)
  }

  // MARK: Containers

  private var containersSection: some View {
    Section("Containers") {
      switch store.dockerState {
      case .missing, .offline:
        emptyState("Docker isn’t running.", action: "Start Docker", perform: openDocker)
      case .loading, .ready:
        if store.containers.isEmpty, store.dockerState == .ready {
          emptyState("No containers yet.", action: nil, perform: {})
        }
        ForEach(store.composeGroups) { group in
          let members = group.containers.filter { matches($0.name) || matches(group.id) }
          if !members.isEmpty {
            DisclosureGroup(isExpanded: expansion(of: group.id)) {
              ForEach(members) { containerRow($0) }
            } label: {
              SidebarRow(
                leading: .group,
                name: group.id,
                trailing: "\(group.runningCount)/\(group.containers.count)",
                isEmphasized: true
              )
            }
          }
        }
        ForEach(store.standaloneContainers.filter { matches($0.name) }) { containerRow($0) }
      }
    }
  }

  private func containerRow(_ container: Container) -> some View {
    let status = container.machineStatus
    let port = container.publishedPorts.first
    let trailing: String
    switch status.kind {
    case .running: trailing = port.map { ":\($0)" } ?? ""
    case .stopped: trailing = ""
    default: trailing = status.word
    }
    return SidebarRow(
      leading: .status(status.kind),
      name: container.name,
      trailing: trailing,
      isTrailingMono: status.kind == .running
    )
    .tag(SidebarItem.container(container.name))
  }

  private func openDocker() {
    store.openApp(bundleIdentifier: Self.dockerBundleIdentifier)
  }

  private static let dockerBundleIdentifier = "com.docker.docker"

  private func expansion(of group: String) -> Binding<Bool> {
    Binding(
      get: { !collapsedGroups.contains(group) || !searchText.isEmpty },
      set: { isOpen in
        if isOpen { collapsedGroups.remove(group) } else { collapsedGroups.insert(group) }
      }
    )
  }

  // MARK: Shared

  private func matches(_ name: String) -> Bool {
    searchText.isEmpty || name.localizedCaseInsensitiveContains(searchText)
  }

  /// A section's empty state: a short reason, and the one thing that would fix it.
  private func emptyState(
    _ text: String,
    action: String?,
    perform: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: Constants.emptyLineSpacing) {
      Text(text).foregroundStyle(Color.secondaryLabel)
      if let action {
        Button(action, action: perform)
          .buttonStyle(.link)
      }
    }
    .font(.ui(FontSize.subheadline))
    .selectionDisabled()
  }
}
