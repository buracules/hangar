import SwiftUI

private enum Constants {
  static let minimumWidth: CGFloat = 860
  static let minimumHeight: CGFloat = 540
  static let sidebarMinimumWidth: CGFloat = 200
  static let sidebarMaximumWidth: CGFloat = 320
  static let appName = "Hangar"
}

/// The main window: sidebar, the selected item's detail, and a toolbar with history,
/// title, refresh and search.
struct MainWindowView: View {
  let store: HangarStore

  @State private var selection: SidebarItem?
  @State private var history = SelectionHistory<SidebarItem>()
  @State private var isNavigatingHistory = false
  @State private var searchText = ""

  var body: some View {
    NavigationSplitView {
      SidebarView(store: store, selection: $selection, searchText: searchText)
        .navigationSplitViewColumnWidth(
          min: Constants.sidebarMinimumWidth,
          ideal: Dimension.sidebarWidth,
          max: Constants.sidebarMaximumWidth
        )
    } detail: {
      DetailView(store: store, selection: $selection)
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .background(Color.backgroundContent)
    }
    .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
    .toolbar { toolbarContent }
    .safeAreaInset(edge: .bottom) { errorBanner }
    .frame(minWidth: Constants.minimumWidth, minHeight: Constants.minimumHeight)
    .onChange(of: selection) { previous, _ in
      if !isNavigatingHistory { history.visit(from: previous) }
      isNavigatingHistory = false
    }
    // A Dock icon and ⌘-Tab only while the window is open; closing it leaves the menu bar app.
    .onAppear {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate()
    }
    .onDisappear { NSApp.setActivationPolicy(.accessory) }
    .task { await applyLaunchSelection() }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button("Back", systemImage: "chevron.left") { navigate(back: true) }
        .disabled(!history.canGoBack)
        .keyboardShortcut("[", modifiers: .command)
      Button("Forward", systemImage: "chevron.right") { navigate(back: false) }
        .disabled(!history.canGoForward)
        .keyboardShortcut("]", modifiers: .command)
    }
    ToolbarItem {
      Button("Refresh", systemImage: "arrow.clockwise") {
        Task { await store.refresh() }
      }
      .keyboardShortcut("r")
    }
  }

  private func navigate(back: Bool) {
    let target = back ? history.goBack(from: selection) : history.goForward(from: selection)
    guard let target else { return }
    isNavigatingHistory = true
    selection = target
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = store.lastError {
      HStack(alignment: .top, spacing: Spacing.xs) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(Color.statusError)
        Text(error)
          .foregroundStyle(Color.logError)
          .textSelection(.enabled)
        Spacer()
        Button("Dismiss", systemImage: "xmark") { store.lastError = nil }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
      }
      .font(.ui(FontSize.callout))
      .padding(.vertical, Spacing.xs)
      .padding(.horizontal, Spacing.md)
      .background(Color.errorBackground)
      .overlay(alignment: .top) { Divider().overlay(Color.errorBorder) }
    }
  }

  // MARK: Title

  private var title: String {
    switch selection {
    case .profile(let id): store.profiles.first { $0.id == id }?.name ?? Constants.appName
    case .vm(let id): store.vms.first { $0.id == id }?.name ?? Constants.appName
    case .container(let name): name
    case nil: Constants.appName
    }
  }

  private var subtitle: String {
    switch selection {
    case .profile(let id):
      guard let profile = store.profiles.first(where: { $0.id == id }) else { return "" }
      let members = store.members(of: profile)
      return "Profile · \(members.runningCount)/\(members.total) up"
    case .vm:
      return "Virtual machine"
    case .container(let name):
      let project = store.containers.first { $0.name == name }?.composeProject
      return project.map { "Container · \($0)" } ?? "Container"
    case nil:
      return ""
    }
  }

  // MARK: Launch

  /// Selects the item named by `-HangarSelect`, once the first refresh has loaded it.
  private func applyLaunchSelection() async {
    guard let (kind, name) = LaunchOptions.selection else { return }
    await store.refresh()
    switch kind {
    case .profile:
      selection = store.profiles.first { $0.name == name }.map { .profile($0.id) }
    case .vm:
      selection = store.vms.first { $0.name == name || $0.id == name }.map { .vm($0.id) }
    case .container:
      selection = store.containers.first { $0.name == name }.map { .container($0.name) }
    }
  }
}
