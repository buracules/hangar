import SwiftUI

private enum Constants {
  static let icon = "square.stack.3d.up"
  static let iconTile: CGFloat = 40
  static let iconSize: CGFloat = 22
  static let maxWidth: CGFloat = 760
  static let sectionSpacing: CGFloat = 20
  static let nameWidth: CGFloat = 260
  static let nameInset: CGFloat = 4
  static let outline: CGFloat = 1
  static let tagHeight: CGFloat = 16
  static let tagPadding: CGFloat = 5
  static let separator = "·"
}

/// A profile: its name (editable), how many members are up, Start All / Stop All, the
/// members by kind, and deleting it.
struct ProfileDetailView: View {
  let profile: Profile
  let store: HangarStore
  @Binding var selection: SidebarItem?

  @State private var name = ""
  @State private var isConfirmingDelete = false
  @FocusState private var isNameFocused: Bool

  var body: some View {
    let members = store.members(of: profile)
    ScrollView {
      VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
        header(members)
        HStack {
          Text("Members").font(.ui(FontSize.body, weight: .semibold))
          Spacer()
          ProfileAddMemberMenu(profile: profile, store: store)
        }
        vmSection
        containerSection
        projectsSection
        Divider().padding(.top, Spacing.sm)
        deleteRow
      }
      .frame(maxWidth: Constants.maxWidth, alignment: .leading)
      .padding(.top, Spacing.lg - Spacing.xxs)
      .padding(.horizontal, Spacing.lg)
      .padding(.bottom, Spacing.xl)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { name = profile.name }
    .onChange(of: profile.id) { name = profile.name }
    .onChange(of: isNameFocused) { if !isNameFocused { commitName() } }
    .confirmationDialog("Delete \(profile.name)?", isPresented: $isConfirmingDelete) {
      Button("Delete Profile", role: .destructive) {
        selection = nil
        store.deleteProfile(profile)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Only the profile is deleted — its VMs and containers aren’t touched.")
    }
  }

  // MARK: - Header

  private func header(_ members: ProfileMembers) -> some View {
    HStack(spacing: Spacing.sm) {
      Image(systemName: Constants.icon)
        .font(.system(size: Constants.iconSize))
        .foregroundStyle(Color.accentText)
        .frame(width: Constants.iconTile, height: Constants.iconTile)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        TextField("Profile name", text: $name)
          .textFieldStyle(.plain)
          .font(.ui(FontSize.title2, weight: .semibold))
          .focused($isNameFocused)
          .onSubmit(commitName)
          .padding(.horizontal, Constants.nameInset)
          .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
              .strokeBorder(Color.separator, lineWidth: Constants.outline)
          )
          .frame(width: Constants.nameWidth)
          .padding(.leading, -Constants.nameInset)
        statusLine(members)
      }
      Spacer(minLength: Spacing.md)
      if store.busy.contains(profile.id.uuidString) { ProgressView().controlSize(.small) }
      Button("Start All") { store.startProfile(profile) }
        .buttonStyle(.borderedProminent)
        .disabled(members.total == 0 || members.areAllUp || isBusy)
      Button("Stop All") { store.stopProfile(profile) }
        .disabled(members.runningCount == 0 || isBusy)
    }
  }

  private var isBusy: Bool { store.busy.contains(profile.id.uuidString) }

  private func statusLine(_ members: ProfileMembers) -> some View {
    HStack(spacing: Spacing.xxs + 2) {
      if members.total == 0 && members.missing == 0 {
        Text("No members yet")
      } else {
        (Text("\(members.runningCount) of \(members.total)")
          .fontWeight(.semibold)
          .foregroundStyle(Color.primary) + Text(" up"))
        if let summary = members.notRunningSummary {
          Text(Constants.separator)
          Text(summary)
        }
      }
    }
    .font(.ui(FontSize.callout))
    .foregroundStyle(Color.secondaryLabel)
    .lineLimit(1)
    .fixedSize()
  }

  private func commitName() {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, trimmed != profile.name else {
      name = profile.name
      return
    }
    store.renameProfile(profile, to: trimmed)
  }

  // MARK: - Members

  @ViewBuilder
  private var vmSection: some View {
    if !profile.vmIDs.isEmpty {
      ProfileMemberSection {
        Text("Virtual Machines")
      } rows: {
        ForEach(profile.vmIDs, id: \.self) { id in
          let vm = store.vms.first { $0.id == id }
          ProfileMemberRow(
            name: vm?.name ?? id,
            status: vm.map(MachineStatus.init),
            isBusy: store.busy.contains(id),
            open: vm.map { vm in { selection = .vm(vm.id) } },
            remove: { store.removeVM(id: id, from: profile) },
            detail: { EmptyView() }
          )
        }
      }
    }
  }

  @ViewBuilder
  private var containerSection: some View {
    if !profile.containerNames.isEmpty {
      ProfileMemberSection {
        Text("Containers")
      } rows: {
        ForEach(profile.containerNames, id: \.self) { name in
          let container = store.containers.first { $0.name == name }
          ProfileMemberRow(
            name: name,
            status: container?.machineStatus,
            isBusy: container.map { store.busy.contains($0.id) } ?? false,
            open: container.map { container in { selection = .container(container.name) } },
            remove: { store.removeContainer(named: name, from: profile) },
            detail: {
              if let container { containerDetail(container) }
            }
          )
        }
      }
    }
  }

  /// A port chip while running, otherwise where the container comes from.
  @ViewBuilder
  private func containerDetail(_ container: Container) -> some View {
    if container.isRunning, let port = container.publishedPorts.first {
      PortChip(port: port) { store.openPort(port) }
    } else if let project = container.composeProject {
      Text(
        [project, container.composeService].compactMap(\.self)
          .joined(separator: " \(Constants.separator) ")
      )
      .font(.ui(FontSize.subheadline))
      .foregroundStyle(Color.secondaryLabel)
    }
  }

  private var projectsSection: some View {
    ProfileMemberSection {
      HStack(spacing: Spacing.xxs + 2) {
        Text("Projects")
        Text("Soon")
          .font(.ui(FontSize.caption, weight: .medium))
          .foregroundStyle(Color.secondaryLabel)
          .padding(.horizontal, Constants.tagPadding)
          .frame(height: Constants.tagHeight)
          .background(Color.controlFill, in: RoundedRectangle(cornerRadius: Radius.xs))
      }
    } rows: {
      Text("Local Node and Python dev servers will be addable here.")
        .font(.ui(FontSize.callout))
        .foregroundStyle(Color.secondaryLabel)
        .padding(.vertical, Spacing.xs + 2)
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var deleteRow: some View {
    HStack(spacing: Spacing.sm) {
      Button("Delete Profile…") { isConfirmingDelete = true }
        .foregroundStyle(Color.statusError)
      Text("Only the profile is deleted — its VMs and containers aren’t touched.")
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(Color.secondaryLabel)
    }
  }
}
