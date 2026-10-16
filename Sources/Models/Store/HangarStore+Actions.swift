import AppKit

private enum Constants {
  /// A freshly launched UTM takes a moment before it accepts Apple Events.
  static let startAttempts = 10
  static let startRetryDelaySeconds = 1
  /// How long to wait for UTM to finish launching: attempts × interval.
  static let launchChecks = 30
  static let launchCheckIntervalMilliseconds = 500
  static let localhostURLPrefix = "http://localhost:"
}

// MARK: - Actions

extension HangarStore {
  func startVM(_ vm: VirtualMachine) { perform(vm.id) { try await $0.bootVM(vm) } }

  func stopVM(_ vm: VirtualMachine, force: Bool = false) {
    perform(vm.id) { try await $0.utm?.stop(vm.id, force: force) }
  }

  func suspendVM(_ vm: VirtualMachine) { perform(vm.id) { try await $0.utm?.suspend(vm.id) } }

  /// Puts the VM's first IP address on the clipboard.
  func copyIP(_ vm: VirtualMachine) {
    perform(vm.id, refreshAfter: false) { store in
      guard let ip = try await store.utm?.ipAddresses(vm.id).first else {
        throw UTMControl.Failure.noIPAddress(vmName: vm.name)
      }
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(ip, forType: .string)
    }
  }

  func start(_ container: Container) {
    perform(container.id) { try await $0.docker?.start(container.id) }
  }

  func stop(_ container: Container) {
    perform(container.id) { try await $0.docker?.stop(container.id) }
  }

  func restart(_ container: Container) {
    perform(container.id) { try await $0.docker?.restart(container.id) }
  }

  func startAll(_ group: ComposeGroup) {
    for container in group.containers where !container.isRunning { start(container) }
  }

  func stopAll(_ group: ComposeGroup) {
    for container in group.containers where container.isRunning { stop(container) }
  }

  /// Starts a VM, launching UTM hidden first if it is closed.
  func bootVM(_ vm: VirtualMachine) async throws {
    guard let utm else { throw UTMControl.Failure.notInstalled }
    guard try await launchUTMHidden() else {
      try await utm.start(vm.id)
      return
    }
    var lastError: Error?
    for _ in 0..<Constants.startAttempts {
      do {
        try await utm.start(vm.id)
        return
      } catch {
        lastError = error
        try await Task.sleep(for: .seconds(Constants.startRetryDelaySeconds))
      }
    }
    throw lastError ?? UTMControl.Failure.didNotStart(vmName: vm.name)
  }

  /// Opens an app normally (UTM, Docker Desktop), then refreshes.
  func openApp(bundleIdentifier: String) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, _ in
      Task { await self?.refresh() }
    }
  }

  /// Opens `http://localhost:<port>` in the browser.
  func openPort(_ port: Int) {
    if let url = URL(string: Constants.localhostURLPrefix + String(port)) {
      NSWorkspace.shared.open(url)
    }
  }

  /// Runs an action for one VM or container, marking it busy meanwhile so its buttons show
  /// progress and cannot be pressed twice. Errors land in `lastError`.
  func perform(
    _ id: String,
    refreshAfter: Bool = true,
    _ action: @escaping @MainActor (HangarStore) async throws -> Void
  ) {
    guard !busy.contains(id) else { return }
    busy.insert(id)
    lastError = nil
    Task {
      do {
        try await action(self)
      } catch {
        lastError = error.localizedDescription
      }
      if refreshAfter { await refresh() }
      busy.remove(id)
    }
  }

  /// Launches UTM in the background and hidden. Returns false if it was already running.
  private func launchUTMHidden() async throws -> Bool {
    guard !isUTMProcessRunning else { return false }
    guard
      let url = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: UTMControl.bundleIdentifier
      )
    else { throw UTMControl.Failure.appNotFound }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.hides = true
    let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    for _ in 0..<Constants.launchChecks where !app.isFinishedLaunching {
      try await Task.sleep(for: .milliseconds(Constants.launchCheckIntervalMilliseconds))
    }
    return true
  }
}
