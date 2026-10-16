import SwiftUI

private enum Constants {
  /// Past this the panel scrolls instead of growing.
  static let maxScrollHeight: CGFloat = 600
  static let headerTop: CGFloat = 12
  static let headerBottom: CGFloat = 8
  static let headerLeading: CGFloat = 16
  static let headerTrailing: CGFloat = 12
  static let sectionInset: CGFloat = 16
  static let standaloneInset: CGFloat = 40
  static let cardSpacing: CGFloat = 8
  static let footerHeight: CGFloat = 36
  static let noticePadding: CGFloat = 6
  static let noticeHorizontalPadding: CGFloat = 10
  static let errorLineLimit = 3
}

/// The menu bar panel: profiles, VMs and containers at a glance, each startable from here.
struct MenuBarPanel: View {
  let store: HangarStore

  @State private var contentHeight: CGFloat = 0
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      // A ScrollView has no ideal height and the MenuBarExtra window sizes itself to its
      // content's, so measure the content and size the scroller to it.
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          profilesSection
          vmSection
          containerSection
        }
        .padding(.bottom, Spacing.xs)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          contentHeight = $0
        }
      }
      .frame(height: min(contentHeight, Constants.maxScrollHeight))
      if let error = store.lastError { errorNotice(error) }
      Divider()
      footer
    }
    .frame(width: Dimension.popoverWidth)
    .task { await store.refresh() }
  }

  // MARK: - Header and footer

  private var header: some View {
    HStack(spacing: Spacing.xxs) {
      Text(verbatim: "Hangar")
        .font(.ui(FontSize.title3, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
      MenuBarIconButton("Refresh", systemImage: "arrow.clockwise") {
        Task { await store.refresh() }
      }
      MenuBarIconButton("Open window", systemImage: "macwindow", action: openMainWindow)
    }
    .padding(.top, Constants.headerTop)
    .padding(.bottom, Constants.headerBottom)
    .padding(.leading, Constants.headerLeading)
    .padding(.trailing, Constants.headerTrailing)
  }

  private var footer: some View {
    HStack {
      Button("Edit profiles…", action: openMainWindow)
      Spacer()
      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        HStack(spacing: Spacing.xxs + 2) {
          Text("Quit").foregroundStyle(Color.secondaryLabel)
          Text(verbatim: "⌘Q").foregroundStyle(Color.tertiaryLabel)
        }
      }
      .keyboardShortcut("q")
    }
    .buttonStyle(.plain)
    .font(.ui(FontSize.body))
    .frame(height: Constants.footerHeight)
    .padding(.horizontal, Constants.sectionInset)
  }

  private func openMainWindow() {
    openWindow(id: HangarApp.mainWindowID)
    NSApp.activate()
  }

  private func errorNotice(_ error: String) -> some View {
    Label(error, systemImage: "exclamationmark.triangle.fill")
      .font(.ui(FontSize.subheadline))
      .foregroundStyle(Color.statusError)
      .lineLimit(Constants.errorLineLimit)
      .padding(.horizontal, Constants.sectionInset)
      .padding(.vertical, Spacing.xs)
  }

  // MARK: - Sections

  private func sectionHeader(_ title: String, top: CGFloat = Spacing.sm) -> some View {
    Text(title)
      .font(.ui(FontSize.subheadline, weight: .semibold))
      .foregroundStyle(Color.tertiaryLabel)
      .padding(.top, top)
      .padding(.bottom, Spacing.xxs)
      .padding(.horizontal, Constants.sectionInset)
  }

  /// A quiet one-line note under a section header, with an optional button.
  private func notice(
    _ text: String,
    action: String? = nil,
    perform: @escaping () -> Void = {}
  ) -> some View {
    HStack {
      Text(text)
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(Color.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let action { Button(action, action: perform).controlSize(.small) }
    }
    .padding(.vertical, Constants.noticePadding)
    .padding(.horizontal, Constants.noticeHorizontalPadding)
    .background(Color.controlFill, in: RoundedRectangle(cornerRadius: Radius.sm))
    .padding(.horizontal, Spacing.sm)
    .padding(.bottom, Spacing.xxs)
  }

  @ViewBuilder
  private var profilesSection: some View {
    sectionHeader("Profiles", top: Spacing.xxs)
    if store.profiles.isEmpty {
      notice("Group machines you start together.", action: "New Profile…") {
        _ = store.createEmptyProfile()
        openMainWindow()
      }
    } else {
      VStack(spacing: Constants.cardSpacing) {
        ForEach(store.profiles) { MenuBarProfileCard(profile: $0, store: store) }
      }
      .padding(.horizontal, Spacing.sm)
      .padding(.bottom, Spacing.xxs)
    }
  }

  @ViewBuilder
  private var vmSection: some View {
    sectionHeader("Virtual Machines")
    switch store.utmState {
    case .loading:
      ProgressView().controlSize(.small).padding(.horizontal, Constants.sectionInset)
    case .missing:
      notice("UTM isn't installed.")
    case .offline(let reason):
      notice(reason, action: "Open UTM") {
        store.openApp(bundleIdentifier: UTMControl.bundleIdentifier)
      }
    case .ready:
      if !store.isUTMRunning && !store.vms.isEmpty {
        notice("UTM is closed — starting a VM opens it hidden.")
      }
      if store.vms.isEmpty {
        notice("No virtual machines yet.", action: "Open UTM") {
          store.openApp(bundleIdentifier: UTMControl.bundleIdentifier)
        }
      }
      ForEach(store.vms) { MenuBarVMRow(vm: $0, store: store) }
    }
  }

  @ViewBuilder
  private var containerSection: some View {
    sectionHeader("Containers")
    switch store.dockerState {
    case .loading:
      ProgressView().controlSize(.small).padding(.horizontal, Constants.sectionInset)
    case .missing:
      notice("No Docker socket found.")
    case .offline(let reason):
      notice(reason, action: "Open Docker") {
        store.openApp(bundleIdentifier: DockerClient.desktopBundleIdentifier)
      }
    case .ready where store.containers.isEmpty:
      notice("No containers.")
    case .ready:
      ForEach(store.composeGroups) { MenuBarComposeGroup(group: $0, store: store) }
      if !store.standaloneContainers.isEmpty {
        if !store.composeGroups.isEmpty {
          Text("Standalone")
            .font(.ui(FontSize.subheadline, weight: .medium))
            .foregroundStyle(Color.tertiaryLabel)
            .padding(.top, Spacing.xs)
            .padding(.leading, Constants.standaloneInset)
        }
        ForEach(store.standaloneContainers) { MenuBarContainerRow(container: $0, store: store) }
      }
    }
  }
}
