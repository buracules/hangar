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
  func startVM(_ vm: VirtualMachine) {
    perform(vm.id) { try await $0.bootVM(vm, cause: Cause.hangar) }
  }

  func stopVM(_ vm: VirtualMachine, force: Bool = false) {
    perform(vm.id) { try await $0.shutDown(vm, force: force, cause: Cause.hangar) }
  }

  func suspendVM(_ vm: VirtualMachine) {
    perform(vm.id) { try await $0.suspend(vm, cause: Cause.hangar) }
  }

  /// Asks the guest to shut down, or with `force` cuts the power, and records it.
  func shutDown(_ vm: VirtualMachine, force: Bool, cause: String) async throws {
    try await utm?.stop(vm.id, force: force)
    activity.record(
      vm.id,
      outcome: force ? .error : .stopped,
      title: force ? "Force stopped" : "Shut down",
      cause: cause
    )
  }

  func suspend(_ vm: VirtualMachine, cause: String) async throws {
    try await utm?.suspend(vm.id)
    activity.record(vm.id, outcome: .paused, title: "Suspended", cause: cause)
  }

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
    perform(container.id) { try await $0.run(.start, on: container, cause: Cause.hangar) }
  }

  func stop(_ container: Container) {
    perform(container.id) { try await $0.run(.stop, on: container, cause: Cause.hangar) }
  }

  func restart(_ container: Container) {
    perform(container.id) { try await $0.run(.restart, on: container, cause: Cause.hangar) }
  }

  /// Starts, stops or restarts a container and records it.
  func run(_ action: ContainerAction, on container: Container, cause: String) async throws {
    guard let docker else { throw Failure.dockerMissing }
    switch action {
    case .start: try await docker.start(container.id)
    case .stop: try await docker.stop(container.id)
    case .restart: try await docker.restart(container.id)
    }
    let (outcome, title): (ActivityEvent.Outcome, String) =
      switch action {
      case .start: (.running, "Started")
      case .stop: (.stopped, "Stopped")
      case .restart: (.running, "Restarted")
      }
    activity.record(container.id, outcome: outcome, title: title, cause: cause)
  }

  func startAll(_ group: ComposeGroup) {
    for container in group.containers where !container.isRunning { start(container) }
  }

  func stopAll(_ group: ComposeGroup) {
    for container in group.containers where container.isRunning { stop(container) }
  }

  /// Starts a VM, launching UTM hidden first if it is closed, and records why.
  func bootVM(_ vm: VirtualMachine, cause: String) async throws {
    guard let utm else { throw UTMControl.Failure.notInstalled }
    let title = vm.isPaused ? "Resumed" : "Started"
    guard try await launchUTMHidden() else {
      try await utm.start(vm.id)
      activity.record(vm.id, outcome: .running, title: title, cause: cause)
      return
    }
    activity.record(vm.id, outcome: .busy, title: "UTM opened hidden", detail: "it was closed")
    var lastError: Error?
    for _ in 0..<Constants.startAttempts {
      do {
        try await utm.start(vm.id)
        activity.record(vm.id, outcome: .running, title: title, cause: cause)
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
