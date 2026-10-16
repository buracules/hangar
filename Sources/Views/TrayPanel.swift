import SwiftUI

struct TrayPanel: View {
  let store: HangarStore
  @State private var contentHeight: CGFloat = 0
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      // A ScrollView has no ideal height, and the MenuBarExtra window sizes itself to
      // its content's ideal size — so measure the content and size the scroller to it.
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ProfilesSection(store: store)
          vmSection
          containerSection
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
          }
        )
      }
      .frame(height: min(contentHeight, 520))
      .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
      if let error = store.lastError {
        Divider()
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .lineLimit(3)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
      }
      Divider()
      footer
    }
    .frame(width: 360)
    .task { await store.refresh() }
  }

  private var header: some View {
    HStack {
      Text("Hangar").font(.headline)
      Spacer()
      Button {
        openWindow(id: HangarApp.mainWindowID)
        NSApp.activate()
      } label: {
        Image(systemName: "macwindow")
      }
      .buttonStyle(.borderless)
      .help("Open Hangar")
      Button {
        Task { await store.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Refresh")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var footer: some View {
    HStack {
      Button("Edit profiles…") {
        let file = SharedFiles.profiles
        if !FileManager.default.fileExists(atPath: file.url.path) { try? file.save(store.profiles) }
        NSWorkspace.shared.open(file.url)
      }
      .buttonStyle(.borderless)
      .help("Open profiles.json")
      Spacer()
      Button("Quit") { NSApplication.shared.terminate(nil) }
        .buttonStyle(.borderless)
        .keyboardShortcut("q")
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  // MARK: - VMs

  @ViewBuilder
  private var vmSection: some View {
    SectionHeader(title: "Virtual Machines", systemImage: "desktopcomputer")
    switch store.utmState {
    case .loading:
      ProgressView().controlSize(.small)
    case .missing:
      Placeholder(text: "UTM is not installed")
    case .offline(let reason):
      Placeholder(text: reason, action: "Open UTM") {
        store.openApp(bundleIdentifier: UTMControl.bundleIdentifier)
      }
    case .ready where store.vms.isEmpty:
      Placeholder(
        text: store.isUTMRunning ? "No virtual machines" : "No known virtual machines yet",
        action: store.isUTMRunning ? nil : "Open UTM"
      ) {
        store.openApp(bundleIdentifier: UTMControl.bundleIdentifier)
      }
    case .ready:
      ForEach(store.vms) { vm in
        VMRow(vm: vm, store: store)
      }
      if !store.isUTMRunning {
        Text("UTM is closed — starting a VM opens it in the background.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
  }

  // MARK: - Containers

  @ViewBuilder
  private var containerSection: some View {
    SectionHeader(title: "Containers", systemImage: "shippingbox")
    switch store.dockerState {
    case .loading:
      ProgressView().controlSize(.small)
    case .missing:
      Placeholder(text: "No Docker socket found")
    case .offline(let reason):
      Placeholder(text: reason, action: "Open Docker") {
        store.openApp(bundleIdentifier: "com.docker.docker")
      }
    case .ready where store.containers.isEmpty:
      Placeholder(text: "No containers")
    case .ready:
      ForEach(store.composeGroups) { group in
        ComposeGroupView(group: group, store: store)
      }
      ForEach(store.standaloneContainers) { container in
        ContainerRow(container: container, store: store)
      }
    }
  }
}

// MARK: - Rows

private struct VMRow: View {
  let vm: VirtualMachine
  let store: HangarStore

  var body: some View {
    HStack(spacing: 8) {
      StatusDot(color: vm.statusColor)
      VStack(alignment: .leading, spacing: 1) {
        Text(vm.name).lineLimit(1)
        Text(vm.status).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if store.busy.contains(vm.id) || vm.isTransitioning {
        ProgressView().controlSize(.small)
      } else if vm.isRunning {
        IconButton("doc.on.doc", help: "Copy IP address") { store.copyIP(vm) }
        IconButton("pause.fill", help: "Suspend") { store.suspendVM(vm) }
        IconButton("stop.fill", help: "Shut down") { store.stopVM(vm) }
      } else {
        IconButton("play.fill", help: vm.isPaused ? "Resume" : "Start") { store.startVM(vm) }
      }
    }
    .contentShape(Rectangle())
    .contextMenu {
      if vm.isRunning {
        Button("Force Stop") { store.stopVM(vm, force: true) }
        Divider()
      }
      ProfileMembershipMenu(store: store, contains: { $0.vmIDs.contains(vm.id) }) {
        store.toggle(vm, in: $0)
      }
    }
  }
}

private struct ComposeGroupView: View {
  let group: ComposeGroup
  let store: HangarStore
  @State private var expanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Button {
          expanded.toggle()
        } label: {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .frame(width: 12)
        }
        .buttonStyle(.borderless)
        Text(group.id).fontWeight(.medium)
        Text("\(group.runningCount)/\(group.containers.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        if group.runningCount < group.containers.count {
          IconButton("play.fill", help: "Start all") { store.startAll(group) }
        }
        if group.runningCount > 0 {
          IconButton("stop.fill", help: "Stop all") { store.stopAll(group) }
        }
      }
      if expanded {
        ForEach(group.containers) { container in
          ContainerRow(container: container, store: store)
            .padding(.leading, 18)
        }
      }
    }
  }
}

private struct ContainerRow: View {
  let container: Container
  let store: HangarStore

  var body: some View {
    HStack(spacing: 8) {
      StatusDot(color: container.statusColor)
      VStack(alignment: .leading, spacing: 2) {
        Text(container.displayName).lineLimit(1)
        HStack(spacing: 4) {
          Text(container.image).lineLimit(1).truncationMode(.middle)
          if container.isRunning {
            ForEach(container.publishedPorts, id: \.self) { port in
              Button(":\(port)") { store.openPort(port) }
                .buttonStyle(.borderless)
                .help("Open http://localhost:\(port)")
            }
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      if store.busy.contains(container.id) {
        ProgressView().controlSize(.small)
      } else if container.isRunning {
        IconButton("arrow.clockwise", help: "Restart") { store.restart(container) }
        IconButton("stop.fill", help: "Stop") { store.stop(container) }
      } else {
        IconButton("play.fill", help: "Start") { store.start(container) }
      }
    }
    .help(container.status)
    .contentShape(Rectangle())
    .contextMenu {
      ProfileMembershipMenu(store: store, contains: { $0.containerNames.contains(container.name) })
      {
        store.toggle(container, in: $0)
      }
    }
  }
}

// MARK: - Profiles

private struct ProfilesSection: View {
  let store: HangarStore
  @State private var newName: String?
  @FocusState private var nameFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        SectionHeader(title: "Profiles", systemImage: "square.stack.3d.up")
        Spacer()
        if newName == nil {
          IconButton("plus", help: "Save what is running now as a profile") {
            newName = ""
            nameFocused = true
          }
        }
      }
      if let name = newName {
        HStack(spacing: 6) {
          TextField("Profile name", text: Binding(get: { name }, set: { newName = $0 }))
            .textFieldStyle(.roundedBorder)
            .focused($nameFocused)
            .onSubmit(save)
          Button("Save", action: save)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          Button("Cancel") { newName = nil }
        }
        .controlSize(.small)
        Text(
          "Saves the VMs and containers running now. Right-click any row to add or remove it later."
        )
        .font(.caption)
        .foregroundStyle(.tertiary)
      } else if store.profiles.isEmpty {
        Text("Start what you need, then press + to save it as a profile.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      ForEach(store.profiles) { profile in
        ProfileRow(profile: profile, store: store)
      }
    }
  }

  private func save() {
    guard let name = newName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
    store.createProfileFromRunning(named: name)
    newName = nil
  }
}

private struct ProfileRow: View {
  let profile: Profile
  let store: HangarStore

  var body: some View {
    let members = store.members(of: profile)
    let allUp = members.areAllUp
    HStack(spacing: 8) {
      StatusDot(color: members.statusColor)
      VStack(alignment: .leading, spacing: 1) {
        Text(profile.name).fontWeight(.medium).lineLimit(1)
        Text(summary(members))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if store.busy.contains(profile.id.uuidString) {
        ProgressView().controlSize(.small)
      } else {
        if !allUp && members.total > 0 {
          IconButton("play.fill", help: "Start profile") { store.startProfile(profile) }
        }
        if members.runningCount > 0 {
          IconButton("stop.fill", help: "Stop profile") { store.stopProfile(profile) }
        }
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    .contextMenu {
      Button("Delete Profile", role: .destructive) { store.deleteProfile(profile) }
    }
  }

  private func summary(_ members: ProfileMembers) -> String {
    let names = members.vms.map(\.name) + members.containers.map(\.displayName)
    var text = "\(members.runningCount)/\(members.total) up"
    if !names.isEmpty { text += " · " + names.joined(separator: ", ") }
    if members.missing > 0 { text += " · \(members.missing) missing" }
    return text
  }
}

// MARK: - Pieces

private struct ContentHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct SectionHeader: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
  }
}

private struct Placeholder: View {
  let text: String
  var action: String?
  var perform: (() -> Void)?

  var body: some View {
    HStack {
      Text(text).font(.callout).foregroundStyle(.secondary)
      Spacer()
      if let action, let perform {
        Button(action, action: perform).controlSize(.small)
      }
    }
  }
}
