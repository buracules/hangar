import AppKit
import Observation

private enum Constants {
  static let pollIntervalSeconds = 5
}

/// The live picture of VMs, containers and profiles, shared by the menu bar panel, the
/// window and the CLI.
@MainActor
@Observable
final class HangarStore {
  private(set) var vms: [VirtualMachine] = []
  private(set) var containers: [Container] = []
  private(set) var utmState: SourceState = .loading
  /// Whether UTM was open at the last refresh. While it is closed every VM is stopped.
  private(set) var isUTMRunning = false
  private(set) var dockerState: SourceState = .loading
  /// Ids of VMs, containers and profiles with an action in flight.
  var busy: Set<String> = []
  /// The last action's error, shown until the next action or until dismissed.
  var lastError: String?
  var profiles: [Profile] = SharedFiles.profiles.load() ?? [] {
    didSet {
      do {
        try SharedFiles.profiles.save(profiles)
      } catch {
        lastError =
          Failure.couldNotSaveProfiles(reason: error.localizedDescription)
          .localizedDescription
      }
    }
  }

  let utm = UTMControl.detect()
  let docker = DockerClient.detect()
  private var pollTask: Task<Void, Never>?

  /// Running VMs and containers together, for the menu bar icon.
  var runningCount: Int {
    vms.filter(\.isRunning).count + containers.filter(\.isRunning).count
  }

  /// Containers grouped by compose project, projects and services sorted by name.
  var composeGroups: [ComposeGroup] {
    let pairs = containers.compactMap { container in
      container.composeProject.map { ($0, container) }
    }
    return Dictionary(grouping: pairs, by: \.0)
      .map { project, members in
        ComposeGroup(
          id: project,
          containers: members.map(\.1).sorted { $0.displayName < $1.displayName }
        )
      }
      .sorted { $0.id < $1.id }
  }

  /// Containers outside any compose project, sorted by name.
  var standaloneContainers: [Container] {
    containers.filter { $0.composeProject == nil }.sorted { $0.name < $1.name }
  }

  /// Refreshes now and then every few seconds, for the app's lifetime.
  func startPolling() {
    guard pollTask == nil else { return }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        try? await Task.sleep(for: .seconds(Constants.pollIntervalSeconds))
      }
    }
  }

  /// Re-reads VMs, containers and profiles.
  func refresh() async {
    reloadProfiles()
    async let vms: Void = refreshVMs()
    async let containers: Void = refreshContainers()
    _ = await (vms, containers)
  }

  /// Whether a UTM process exists right now.
  var isUTMProcessRunning: Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: UTMControl.bundleIdentifier)
      .isEmpty
  }

  private func refreshVMs() async {
    guard let utm else {
      utmState = .missing
      return
    }
    isUTMRunning = isUTMProcessRunning
    // utmctl launches UTM, so while UTM is closed the list comes from what we last saw
    // (or from disk, the first time) — and everything is stopped.
    guard isUTMRunning else {
      var known = knownVMs
      if known.isEmpty {
        known = UTMControl.libraryVMs()
        knownVMs = known
      }
      vms = known.map { .stopped(id: $0.id, name: $0.name) }.sorted { $0.name < $1.name }
      utmState = .ready
      return
    }
    do {
      let list = try await utm.list()
      vms = list
      knownVMs = list
      utmState = .ready
    } catch {
      // UTM answers Apple Events only once it has finished launching; keep the last list.
      if vms.isEmpty { utmState = .offline(error.localizedDescription) }
    }
  }

  /// The VMs UTM reported last time it was running, so they can be listed while it is closed.
  private var knownVMs: [VirtualMachine] {
    get { (SharedFiles.knownVMs.load() ?? []).map { .stopped(id: $0.id, name: $0.name) } }
    set {
      let known = newValue.map { KnownVM(id: $0.id, name: $0.name) }
      // Written on every poll while UTM runs; skip the disk write when nothing changed.
      guard known != SharedFiles.knownVMs.load() else { return }
      try? SharedFiles.knownVMs.save(known)
    }
  }

  private func refreshContainers() async {
    guard let docker else {
      dockerState = .missing
      return
    }
    do {
      containers = try await docker.containers()
      dockerState = .ready
    } catch DockerClient.Failure.connect {
      containers = []
      dockerState = .offline(Failure.dockerUnreachable.localizedDescription)
    } catch {
      containers = []
      dockerState = .offline(error.localizedDescription)
    }
  }
}
