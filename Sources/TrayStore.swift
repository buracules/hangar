import AppKit
import Observation

enum SourceState: Equatable {
    case loading
    case ready
    /// The tool is installed but not running (UTM closed, Docker daemon down).
    case offline(String)
    /// The tool is not installed at all.
    case missing
}

struct ComposeGroup: Identifiable {
    let id: String
    let containers: [Container]
    var runningCount: Int { containers.filter(\.isRunning).count }
}

@MainActor
@Observable
final class TrayStore {
    private(set) var vms: [VirtualMachine] = []
    private(set) var containers: [Container] = []
    private(set) var utmState: SourceState = .loading
    private(set) var utmRunning = false
    private(set) var dockerState: SourceState = .loading
    /// Ids of VMs/containers with an action in flight.
    private(set) var busy: Set<String> = []
    var lastError: String?
    var profiles: [Profile] = Shared.profiles.load() ?? [] {
        didSet {
            do { try Shared.profiles.save(profiles) } catch { lastError = "Could not save profiles: \(error.localizedDescription)" }
        }
    }

    let utm = UTMControl.detect()
    let docker = DockerClient.detect()
    private var pollTask: Task<Void, Never>?

    var runningCount: Int {
        vms.filter(\.isRunning).count + containers.filter(\.isRunning).count
    }

    var composeGroups: [ComposeGroup] {
        Dictionary(grouping: containers.filter { $0.composeProject != nil }, by: { $0.composeProject! })
            .map { ComposeGroup(id: $0.key, containers: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.id < $1.id }
    }

    var standaloneContainers: [Container] {
        containers.filter { $0.composeProject == nil }.sorted { $0.name < $1.name }
    }

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func refresh() async {
        async let vms: Void = refreshVMs()
        async let containers: Void = refreshContainers()
        _ = await (vms, containers)
    }

    private func refreshVMs() async {
        guard let utm else { utmState = .missing; return }
        utmRunning = isUTMRunning
        // utmctl launches UTM, so while UTM is closed the list comes from what we last saw
        // (or from disk, the first time) — and everything is stopped.
        guard utmRunning else {
            var known = knownVMs
            if known.isEmpty {
                known = UTMControl.libraryVMs()
                knownVMs = known
            }
            vms = known.map { VirtualMachine(id: $0.id, name: $0.name, status: "stopped") }
                .sorted { $0.name < $1.name }
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
        get {
            (Shared.knownVMs.load() ?? []).map { VirtualMachine(id: $0.id, name: $0.name, status: "stopped") }
        }
        set {
            let known = newValue.map { KnownVM(id: $0.id, name: $0.name) }
            // Written on every poll while UTM runs; skip the disk write when nothing changed.
            guard known != Shared.knownVMs.load() else { return }
            try? Shared.knownVMs.save(known)
        }
    }

    private func refreshContainers() async {
        guard let docker else { dockerState = .missing; return }
        do {
            containers = try await docker.containers()
            dockerState = .ready
        } catch DockerError.connect {
            containers = []
            dockerState = .offline("Docker is not reachable")
        } catch {
            containers = []
            dockerState = .offline(error.localizedDescription)
        }
    }

    private var isUTMRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: UTMControl.bundleIdentifier).isEmpty
    }

    // MARK: - Actions

    func startVM(_ vm: VirtualMachine) { perform(vm.id) { try await $0.bootVM(vm) } }
    func stopVM(_ vm: VirtualMachine, force: Bool = false) { perform(vm.id) { try await $0.utm?.stop(vm.id, force: force) } }
    func suspendVM(_ vm: VirtualMachine) { perform(vm.id) { try await $0.utm?.suspend(vm.id) } }

    func copyIP(_ vm: VirtualMachine) {
        perform(vm.id, refreshAfter: false) { store in
            guard let ips = try await store.utm?.ipAddresses(vm.id), let ip = ips.first else {
                throw UTMError.failed("\(vm.name) reported no IP address")
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ip, forType: .string)
        }
    }

    func start(_ container: Container) { perform(container.id) { try await $0.docker?.start(container.id) } }
    func stop(_ container: Container) { perform(container.id) { try await $0.docker?.stop(container.id) } }
    func restart(_ container: Container) { perform(container.id) { try await $0.docker?.restart(container.id) } }

    func startAll(_ group: ComposeGroup) {
        for container in group.containers where !container.isRunning { start(container) }
    }

    func stopAll(_ group: ComposeGroup) {
        for container in group.containers where container.isRunning { stop(container) }
    }

    /// Starts a VM, launching UTM hidden first if it is closed.
    func bootVM(_ vm: VirtualMachine) async throws {
        guard let utm else { return }
        guard try await launchUTMHidden() else {
            try await utm.start(vm.id)
            return
        }
        // A freshly launched UTM takes a moment before it accepts Apple Events.
        var lastError: Error?
        for _ in 0..<10 {
            do {
                try await utm.start(vm.id)
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .seconds(1))
            }
        }
        throw lastError ?? UTMError.failed("UTM did not start \(vm.name)")
    }

    /// Launches UTM in the background and hidden. Returns false if it was already running.
    private func launchUTMHidden() async throws -> Bool {
        guard !isUTMRunning else { return false }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: UTMControl.bundleIdentifier) else {
            throw UTMError.failed("UTM.app not found")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        for _ in 0..<30 where !app.isFinishedLaunching {
            try await Task.sleep(for: .milliseconds(500))
        }
        return true
    }

    // MARK: - Profiles

    struct ProfileMembers {
        let vms: [VirtualMachine]
        let containers: [Container]
        /// Members that no longer exist (VM deleted, container removed).
        let missing: Int
        var runningCount: Int { vms.filter(\.isRunning).count + containers.filter(\.isRunning).count }
        var total: Int { vms.count + containers.count }
    }

    func members(of profile: Profile) -> ProfileMembers {
        let vms = profile.vmIDs.compactMap { id in self.vms.first { $0.id == id } }
        let containers = profile.containerNames.compactMap { name in self.containers.first { $0.name == name } }
        let missing = profile.vmIDs.count + profile.containerNames.count - vms.count - containers.count
        return ProfileMembers(vms: vms, containers: containers, missing: missing)
    }

    /// Saves everything currently running as a new profile.
    func createProfileFromRunning(named name: String) {
        let profile = Profile(
            name: name,
            vmIDs: vms.filter(\.isRunning).map(\.id),
            containerNames: containers.filter(\.isRunning).map(\.name)
        )
        profiles.append(profile)
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
    }

    func toggle(_ vm: VirtualMachine, in profile: Profile) {
        updateProfile(profile) { p in
            if let i = p.vmIDs.firstIndex(of: vm.id) { p.vmIDs.remove(at: i) } else { p.vmIDs.append(vm.id) }
        }
    }

    func toggle(_ container: Container, in profile: Profile) {
        updateProfile(profile) { p in
            if let i = p.containerNames.firstIndex(of: container.name) {
                p.containerNames.remove(at: i)
            } else {
                p.containerNames.append(container.name)
            }
        }
    }

    private func updateProfile(_ profile: Profile, _ change: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        change(&profiles[index])
    }

    func startProfile(_ profile: Profile) {
        let (vms, containers) = toStart(profile)
        runProfile(profile, memberIDs: vms.map(\.id) + containers.map(\.id)) {
            try await $0.start(vms: vms, containers: containers)
        }
    }

    func stopProfile(_ profile: Profile) {
        let (vms, containers) = toStop(profile)
        runProfile(profile, memberIDs: vms.map(\.id) + containers.map(\.id)) {
            try await $0.stop(vms: vms, containers: containers)
        }
    }

    /// The awaitable forms, for the CLI. Call `refresh()` first so membership is current.
    func startProfileNow(_ profile: Profile) async throws {
        let (vms, containers) = toStart(profile)
        try await start(vms: vms, containers: containers)
    }

    func stopProfileNow(_ profile: Profile) async throws {
        let (vms, containers) = toStop(profile)
        try await stop(vms: vms, containers: containers)
    }

    private func toStart(_ profile: Profile) -> ([VirtualMachine], [Container]) {
        let members = members(of: profile)
        return (members.vms.filter { !$0.isRunning && !$0.isTransitioning }, members.containers.filter { !$0.isRunning })
    }

    private func toStop(_ profile: Profile) -> ([VirtualMachine], [Container]) {
        let members = members(of: profile)
        return (members.vms.filter(\.isRunning), members.containers.filter(\.isRunning))
    }

    /// VMs first so services in them are coming up while containers start.
    private func start(vms: [VirtualMachine], containers: [Container]) async throws {
        var failures: [String] = []
        for vm in vms {
            do { try await bootVM(vm) } catch { failures.append("\(vm.name): \(error.localizedDescription)") }
        }
        for container in containers {
            do { try await docker?.start(container.id) } catch { failures.append("\(container.name): \(error.localizedDescription)") }
        }
        if !failures.isEmpty { throw UTMError.failed(failures.joined(separator: "\n")) }
    }

    /// The reverse order: containers that depend on a VM go down before it does.
    private func stop(vms: [VirtualMachine], containers: [Container]) async throws {
        var failures: [String] = []
        for container in containers {
            do { try await docker?.stop(container.id) } catch { failures.append("\(container.name): \(error.localizedDescription)") }
        }
        for vm in vms {
            do { try await utm?.stop(vm.id) } catch { failures.append("\(vm.name): \(error.localizedDescription)") }
        }
        if !failures.isEmpty { throw UTMError.failed(failures.joined(separator: "\n")) }
    }

    /// Runs a profile action with the profile and every member it touches marked busy, so
    /// their rows show progress and their own buttons cannot race it.
    private func runProfile(
        _ profile: Profile,
        memberIDs: [String],
        _ action: @escaping @MainActor (TrayStore) async throws -> Void
    ) {
        let ids = [profile.id.uuidString] + memberIDs
        guard busy.isDisjoint(with: ids) else { return }
        busy.formUnion(ids)
        lastError = nil
        Task {
            do {
                try await action(self)
            } catch {
                lastError = error.localizedDescription
            }
            await refresh()
            busy.subtract(ids)
        }
    }

    func openApp(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, _ in
            Task { await self?.refresh() }
        }
    }

    func openPort(_ port: Int) {
        if let url = URL(string: "http://localhost:\(port)") { NSWorkspace.shared.open(url) }
    }

    private func perform(
        _ id: String,
        refreshAfter: Bool = true,
        _ action: @escaping @MainActor (TrayStore) async throws -> Void
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
}
