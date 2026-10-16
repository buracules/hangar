import SwiftUI

// Temporary: the VM and profile details as they were before the design pass. Each moves to
// its own design-built view in a later slice, and this file goes away.
// swiftlint:disable no_magic_numbers line_length

// MARK: - Shared detail chrome

private struct LegacyDetailHeader<Actions: View>: View {
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

private struct LegacyInfoRow<Value: View>: View {
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

struct LegacyVMDetail: View {
  let vm: VirtualMachine
  let store: HangarStore
  @State private var addresses: Result<[String], Error>?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      LegacyDetailHeader(
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
        LegacyInfoRow("UUID") { Text(vm.id).font(.body.monospaced()).textSelection(.enabled) }
        LegacyInfoRow("IP address") { addressView }
        LegacyInfoRow("Profiles") {
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

struct LegacyProfileDetail: View {
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

// swiftlint:enable no_magic_numbers line_length
