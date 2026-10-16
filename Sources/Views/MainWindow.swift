import SwiftUI

/// What the sidebar can select. Containers by name: a recreated container keeps its name,
/// not its id, so the selection survives `docker compose up`.
enum SidebarItem: Hashable {
  case profile(UUID)
  case vm(String)
  case container(String)
}

struct MainWindow: View {
  let store: HangarStore
  @State private var selection: SidebarItem?

  var body: some View {
    NavigationSplitView {
      Sidebar(store: store, selection: $selection)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
    } detail: {
      detail
    }
    .toolbar {
      ToolbarItem {
        Button {
          Task { await store.refresh() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r")
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let error = store.lastError {
        HStack(alignment: .top) {
          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
          Text(error).textSelection(.enabled)
          Spacer()
          Button {
            store.lastError = nil
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(10)
        .background(.bar)
      }
    }
    .frame(minWidth: 860, minHeight: 540)
    // A Dock icon and ⌘-Tab only while the window is open; closing it leaves the menu bar app.
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate()
    }
    .onDisappear { NSApp.setActivationPolicy(.accessory) }
  }

  @ViewBuilder
  private var detail: some View {
    switch selection {
    case .profile(let id):
      if let profile = store.profiles.first(where: { $0.id == id }) {
        ProfileDetail(profile: profile, store: store, selection: $selection)
      } else {
        Unavailable(text: "This profile was deleted.")
      }
    case .vm(let id):
      if let vm = store.vms.first(where: { $0.id == id }) {
        VMDetail(vm: vm, store: store)
      } else {
        Unavailable(text: "This VM is no longer in UTM.")
      }
    case .container(let name):
      if let container = store.containers.first(where: { $0.name == name }) {
        ContainerDetail(container: container, store: store)
      } else {
        Unavailable(text: "This container no longer exists.")
      }
    case nil:
      ContentUnavailableView(
        "Nothing selected",
        systemImage: "square.stack.3d.up",
        description: Text("Pick a profile, VM or container from the sidebar.")
      )
    }
  }
}

private struct Unavailable: View {
  let text: String
  var body: some View {
    ContentUnavailableView(
      "Gone",
      systemImage: "questionmark.square.dashed",
      description: Text(text)
    )
  }
}

// MARK: - Sidebar

private struct Sidebar: View {
  let store: HangarStore
  @Binding var selection: SidebarItem?
  @State private var collapsed: Set<String> = []

  var body: some View {
    List(selection: $selection) {
      Section {
        ForEach(store.profiles) { profile in
          let members = store.members(of: profile)
          Row(
            color: members.statusColor,
            title: profile.name,
            detail: "\(members.runningCount)/\(members.total)"
          )
          .tag(SidebarItem.profile(profile.id))
        }
      } header: {
        HStack {
          Text("Profiles")
          Spacer()
          Button {
            selection = .profile(store.createEmptyProfile().id)
          } label: {
            Image(systemName: "plus")
          }
          .buttonStyle(.borderless)
          .help("New profile")
        }
      }

      Section(store.isUTMRunning ? "Virtual Machines" : "Virtual Machines · UTM closed") {
        if case .offline(let reason) = store.utmState { Text(reason).foregroundStyle(.secondary) }
        if case .missing = store.utmState {
          Text("UTM is not installed").foregroundStyle(.secondary)
        }
        ForEach(store.vms) { vm in
          Row(color: vm.statusColor, title: vm.name, detail: vm.isRunning ? nil : vm.status)
            .tag(SidebarItem.vm(vm.id))
        }
      }

      Section("Containers") {
        if case .offline(let reason) = store.dockerState {
          Text(reason).foregroundStyle(.secondary)
        }
        if case .missing = store.dockerState {
          Text("No Docker socket found").foregroundStyle(.secondary)
        }
        ForEach(store.composeGroups) { group in
          DisclosureGroup(isExpanded: expansion(group.id)) {
            ForEach(group.containers) { container in
              containerRow(container)
            }
          } label: {
            Row(
              color: group.runningCount > 0 ? .green : .secondary,
              title: group.id,
              detail: "\(group.runningCount)/\(group.containers.count)",
              systemImage: "square.stack.3d.up"
            )
          }
        }
        ForEach(store.standaloneContainers) { container in
          containerRow(container)
        }
      }
    }
    .listStyle(.sidebar)
  }

  private func containerRow(_ container: Container) -> some View {
    Row(
      color: container.statusColor,
      title: container.displayName,
      detail: container.isRunning ? nil : container.state
    )
    .tag(SidebarItem.container(container.name))
  }

  private func expansion(_ id: String) -> Binding<Bool> {
    Binding(
      get: { !collapsed.contains(id) },
      set: { if $0 { collapsed.remove(id) } else { collapsed.insert(id) } }
    )
  }

  private struct Row: View {
    let color: Color
    let title: String
    var detail: String?
    var systemImage: String?

    var body: some View {
      HStack(spacing: 8) {
        if let systemImage {
          Image(systemName: systemImage).foregroundStyle(.secondary)
        } else {
          StatusDot(color: color)
        }
        Text(title).lineLimit(1)
        Spacer()
        if let detail {
          Text(detail).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}

// MARK: - Shared detail chrome

private struct DetailHeader<Actions: View>: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let color: Color
  @ViewBuilder let actions: Actions

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 28))
        .foregroundStyle(.secondary)
        .frame(width: 40)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.title2.weight(.semibold)).lineLimit(1).textSelection(.enabled)
        HStack(spacing: 6) {
          StatusDot(color: color)
          Text(subtitle).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer()
      HStack(spacing: 8) { actions }
    }
    .padding(16)
  }
}

private struct InfoRow<Value: View>: View {
  let label: String
  @ViewBuilder let value: Value

  init(_ label: String, @ViewBuilder value: () -> Value) {
    self.label = label
    self.value = value()
  }

  var body: some View {
    GridRow(alignment: .firstTextBaseline) {
      Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
      value.gridColumnAlignment(.leading)
    }
  }
}

// MARK: - VM

private struct VMDetail: View {
  let vm: VirtualMachine
  let store: HangarStore
  @State private var addresses: Result<[String], Error>?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      DetailHeader(
        systemImage: "desktopcomputer",
        title: vm.name,
        subtitle: vm.status,
        color: vm.statusColor
      ) {
        if store.busy.contains(vm.id) || vm.isTransitioning {
          ProgressView().controlSize(.small)
        } else if vm.isRunning {
          Button("Suspend") { store.suspendVM(vm) }
          Button("Shut Down") { store.stopVM(vm) }
          Button("Force Stop", role: .destructive) { store.stopVM(vm, force: true) }
        } else {
          Button(vm.isPaused ? "Resume" : "Start") { store.startVM(vm) }
            .keyboardShortcut(.defaultAction)
        }
      }
      Divider()
      Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
        InfoRow("UUID") { Text(vm.id).font(.body.monospaced()).textSelection(.enabled) }
        InfoRow("IP address") { addressView }
        InfoRow("Profiles") {
          MembershipChips(store: store, contains: { $0.vmIDs.contains(vm.id) }) {
            store.toggle(vm, in: $0)
          }
        }
      }
      .padding(16)
      if !store.isUTMRunning {
        Text("UTM is closed. Starting this VM opens UTM in the background, hidden.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
      }
      Spacer()
    }
    .task(id: "\(vm.id)|\(vm.status)") { await loadAddresses() }
  }

  @ViewBuilder
  private var addressView: some View {
    if !vm.isRunning {
      Text("—").foregroundStyle(.secondary)
    } else {
      switch addresses {
      case nil:
        ProgressView().controlSize(.small)
      case .success(let ips) where ips.isEmpty:
        Text("None reported").foregroundStyle(.secondary)
      case .success(let ips):
        VStack(alignment: .leading, spacing: 2) {
          ForEach(ips, id: \.self) { Text($0).font(.body.monospaced()).textSelection(.enabled) }
        }
      case .failure:
        Text("Unavailable — needs the QEMU guest agent in the VM").foregroundStyle(.secondary)
      }
    }
  }

  private func loadAddresses() async {
    addresses = nil
    guard vm.isRunning, let utm = store.utm else { return }
    do {
      addresses = .success(try await utm.ipAddresses(vm.id))
    } catch {
      addresses = .failure(error)
    }
  }
}

// MARK: - Container

private struct ContainerDetail: View {
  let container: Container
  let store: HangarStore

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      DetailHeader(
        systemImage: "shippingbox",
        title: container.displayName,
        subtitle: container.status,
        color: container.statusColor
      ) {
        if store.busy.contains(container.id) {
          ProgressView().controlSize(.small)
        } else if container.isRunning {
          Button("Restart") { store.restart(container) }
          Button("Stop") { store.stop(container) }
        } else {
          Button("Start") { store.start(container) }
            .keyboardShortcut(.defaultAction)
        }
      }
      Divider()
      Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
        InfoRow("Name") { Text(container.name).textSelection(.enabled) }
        InfoRow("Image") { Text(container.image).textSelection(.enabled) }
        InfoRow("ID") {
          Text(container.id.prefix(12)).font(.body.monospaced()).textSelection(.enabled)
        }
        if let project = container.composeProject {
          InfoRow("Compose") { Text("\(project) · \(container.composeService ?? "?")") }
        }
        if !container.publishedPorts.isEmpty {
          InfoRow("Ports") {
            HStack {
              ForEach(container.publishedPorts, id: \.self) { port in
                Button("localhost:\(String(port))") { store.openPort(port) }
                  .buttonStyle(.link)
                  .disabled(!container.isRunning)
              }
            }
          }
        }
        InfoRow("Profiles") {
          MembershipChips(store: store, contains: { $0.containerNames.contains(container.name) }) {
            store.toggle(container, in: $0)
          }
        }
      }
      .padding(16)
      Divider()
      ContainerLogs(container: container, docker: store.docker)
    }
  }
}

/// The profiles something belongs to, as chips; the menu adds or removes it from any.
private struct MembershipChips: View {
  let store: HangarStore
  let contains: (Profile) -> Bool
  let toggle: (Profile) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(store.profiles.filter(contains)) { profile in
        Text(profile.name)
          .font(.callout)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
      }
      Menu {
        ProfileMembershipMenu(store: store, contains: contains, toggle: toggle)
      } label: {
        Image(systemName: "plus.circle")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .help("Add to or remove from profiles")
    }
  }
}

// MARK: - Profile

private struct ProfileDetail: View {
  let profile: Profile
  let store: HangarStore
  @Binding var selection: SidebarItem?
  @State private var name = ""
  @State private var confirmingDelete = false

  var body: some View {
    let members = store.members(of: profile)
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "square.stack.3d.up")
          .font(.system(size: 28))
          .foregroundStyle(.secondary)
          .frame(width: 40)
        VStack(alignment: .leading, spacing: 3) {
          TextField("Profile name", text: $name)
            .textFieldStyle(.plain)
            .font(.title2.weight(.semibold))
            .onSubmit { store.renameProfile(profile, to: name) }
          HStack(spacing: 6) {
            StatusDot(color: members.statusColor)
            Text("\(members.runningCount) of \(members.total) up").foregroundStyle(.secondary)
          }
        }
        Spacer()
        if store.busy.contains(profile.id.uuidString) {
          ProgressView().controlSize(.small)
        } else {
          if members.runningCount > 0 {
            Button("Stop All") { store.stopProfile(profile) }
          }
          if !members.areAllUp && members.total > 0 {
            Button("Start All") { store.startProfile(profile) }
              .keyboardShortcut(.defaultAction)
          }
        }
      }
      .padding(16)
      Divider()
      List {
        Section("Virtual Machines") {
          if profile.vmIDs.isEmpty { Text("None").foregroundStyle(.secondary) }
          ForEach(profile.vmIDs, id: \.self) { id in
            let vm = store.vms.first { $0.id == id }
            MemberRow(
              color: vm?.statusColor ?? .red,
              title: vm?.name ?? "Missing VM",
              detail: vm?.status ?? id,
              busy: store.busy.contains(id)
            ) {
              selection = .vm(id)
            } remove: {
              store.removeVM(id: id, from: profile)
            }
          }
        }
        Section("Containers") {
          if profile.containerNames.isEmpty { Text("None").foregroundStyle(.secondary) }
          ForEach(profile.containerNames, id: \.self) { name in
            let container = store.containers.first { $0.name == name }
            MemberRow(
              color: container?.statusColor ?? .red,
              title: name,
              detail: container?.state ?? "missing",
              busy: container.map { store.busy.contains($0.id) } ?? false
            ) {
              selection = .container(name)
            } remove: {
              store.removeContainer(named: name, from: profile)
            }
          }
        }
      }
      .listStyle(.inset)
      Divider()
      HStack {
        addMenu
        Spacer()
        Button("Delete Profile…", role: .destructive) { confirmingDelete = true }
      }
      .padding(12)
    }
    .onAppear { name = profile.name }
    .onChange(of: profile.id) { name = profile.name }
    .confirmationDialog("Delete \(profile.name)?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) {
        selection = nil
        store.deleteProfile(profile)
      }
    } message: {
      Text("Only the profile is deleted. Its VMs and containers are left as they are.")
    }
  }

  private var addMenu: some View {
    let vms = store.vms.filter { !profile.vmIDs.contains($0.id) }
    let containers = store.containers.filter { !profile.containerNames.contains($0.name) }
      .sorted { $0.name < $1.name }
    return Menu("Add Member") {
      Section("Virtual Machines") {
        ForEach(vms) { vm in Button(vm.name) { store.toggle(vm, in: profile) } }
      }
      Section("Containers") {
        ForEach(containers) { container in
          Button(container.name) { store.toggle(container, in: profile) }
        }
      }
    }
    .fixedSize()
    .disabled(vms.isEmpty && containers.isEmpty)
  }

  private struct MemberRow: View {
    let color: Color
    let title: String
    let detail: String
    let busy: Bool
    let open: () -> Void
    let remove: () -> Void

    var body: some View {
      HStack(spacing: 8) {
        StatusDot(color: color)
        Button(title, action: open).buttonStyle(.link).foregroundStyle(.primary)
        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        Spacer()
        if busy { ProgressView().controlSize(.small) }
        Button(action: remove) {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .help("Remove from profile")
      }
    }
  }
}
