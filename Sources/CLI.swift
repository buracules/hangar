import Foundation

/// `hangar <command>`: the same binary as the menu bar app, run with arguments. It drives
/// the same TrayStore, so profiles, the known-VM list and start logic are shared.
@MainActor
enum CLI {
    static let usage = """
    usage: hangar <command>

      status                         VMs, containers and profiles at a glance
      profile list                   list profiles
      up|down <profile>              start or stop everything in a profile
      profile start|stop <name>      same as up|down
      profile save <name>            save what is running now as a profile
      profile delete <name>          delete a profile
      vm list                        list VMs
      vm start|stop|suspend <vm>     control a VM (name or UUID); stop asks the guest OS
      vm kill <vm>                   cut a VM's power
      vm ip <vm>                     print a VM's IP (needs the guest agent)
      ps                             list containers
      start|stop|restart <container> control a container (name or id prefix)
    """

    /// Commands the CLI answers to. Anything else (including the `-NS…` flags Xcode passes)
    /// launches the menu bar app.
    static func handles(_ arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        return ["status", "up", "down", "profile", "vm", "ps", "start", "stop", "restart", "help", "--help", "-h"].contains(first)
    }

    static func run(_ arguments: [String]) async -> Int32 {
        var arguments = arguments
        // `up`/`down` are shorthand for the profile commands.
        if let verb = arguments.first, verb == "up" || verb == "down" {
            arguments = ["profile", verb == "up" ? "start" : "stop"] + arguments.dropFirst()
        }
        let store = TrayStore()
        await store.refresh()
        do {
            try await dispatch(arguments, store)
            return 0
        } catch let error as UsageError {
            printError(error.message)
            return 2
        } catch {
            printError(error.localizedDescription)
            return 1
        }
    }

    private struct UsageError: Error { let message: String }

    private static func dispatch(_ args: [String], _ store: TrayStore) async throws {
        switch (args.first, args.dropFirst().first) {
        case ("help", _), ("--help", _), ("-h", _):
            print(usage)
        case ("status", _):
            printProfiles(store)
            print("")
            printVMs(store)
            print("")
            printContainers(store)
        case ("profile", "list"):
            printProfiles(store)
        case ("profile", "start"):
            let profile = try findProfile(args, store)
            try await store.startProfileNow(profile)
            print("started \(profile.name)")
        case ("profile", "stop"):
            let profile = try findProfile(args, store)
            try await store.stopProfileNow(profile)
            print("stopped \(profile.name)")
        case ("profile", "save"):
            let name = try argument(args, at: 2, "profile save <name>")
            guard !store.profiles.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
                throw UsageError(message: "a profile named \(name) already exists")
            }
            store.createProfileFromRunning(named: name)
            let members = store.members(of: store.profiles.last!)
            print("saved \(name): \(members.vms.count) VM(s), \(members.containers.count) container(s)")
        case ("profile", "delete"):
            let profile = try findProfile(args, store)
            store.deleteProfile(profile)
            print("deleted \(profile.name)")
        case ("vm", "list"):
            printVMs(store)
        case ("vm", let action?) where ["start", "stop", "suspend", "kill", "ip"].contains(action):
            try await vm(action, try findVM(args, store), store)
        case ("ps", _):
            printContainers(store)
        case (let action?, _) where ["start", "stop", "restart"].contains(action):
            try await container(action, try findContainer(args, store), store)
        default:
            throw UsageError(message: usage)
        }
    }

    private static func vm(_ action: String, _ vm: VirtualMachine, _ store: TrayStore) async throws {
        guard let utm = store.utm else { throw UTMError.failed("UTM is not installed") }
        switch action {
        case "start": try await store.bootVM(vm)
        case "stop": try await utm.stop(vm.id)
        case "kill": try await utm.stop(vm.id, force: true)
        case "suspend": try await utm.suspend(vm.id)
        default:
            guard store.utmRunning else { throw UTMError.failed("UTM is not running") }
            print(try await utm.ipAddresses(vm.id).joined(separator: "\n"))
            return
        }
        print("\(action) \(vm.name)")
    }

    private static func container(_ action: String, _ container: Container, _ store: TrayStore) async throws {
        guard let docker = store.docker else { throw UTMError.failed("No Docker socket found") }
        switch action {
        case "start": try await docker.start(container.id)
        case "stop": try await docker.stop(container.id)
        default: try await docker.restart(container.id)
        }
        print("\(action) \(container.name)")
    }

    // MARK: - Lookup

    private static func argument(_ args: [String], at index: Int, _ form: String) throws -> String {
        guard args.count > index else { throw UsageError(message: "usage: hangar \(form)") }
        return args[index...].joined(separator: " ")
    }

    private static func findProfile(_ args: [String], _ store: TrayStore) throws -> Profile {
        let name = try argument(args, at: 2, "profile \(args[1]) <name>")
        guard let profile = store.profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw UsageError(message: "no profile named \(name) — try: hangar profile list")
        }
        return profile
    }

    private static func findVM(_ args: [String], _ store: TrayStore) throws -> VirtualMachine {
        let key = try argument(args, at: 2, "vm \(args[1]) <name|uuid>")
        guard let vm = store.vms.first(where: {
            $0.id.caseInsensitiveCompare(key) == .orderedSame || $0.name.caseInsensitiveCompare(key) == .orderedSame
        }) else {
            throw UsageError(message: "no VM named \(key) — try: hangar vm list")
        }
        return vm
    }

    private static func findContainer(_ args: [String], _ store: TrayStore) throws -> Container {
        let key = try argument(args, at: 1, "\(args[0]) <container>")
        if let exact = store.containers.first(where: { $0.name == key }) { return exact }
        let byID = store.containers.filter { $0.id.hasPrefix(key) }
        guard byID.count == 1 else {
            throw UsageError(message: byID.isEmpty ? "no container named \(key) — try: hangar ps" : "\(key) matches several containers")
        }
        return byID[0]
    }

    // MARK: - Output

    private static func printProfiles(_ store: TrayStore) {
        print("PROFILES")
        if store.profiles.isEmpty { print("  (none)") }
        for profile in store.profiles {
            let members = store.members(of: profile)
            let names = (members.vms.map(\.name) + members.containers.map(\.name)).joined(separator: ", ")
            print("  \(pad(profile.name, 20)) \(pad("\(members.runningCount)/\(members.total) up", 9)) \(names)")
        }
    }

    private static func printVMs(_ store: TrayStore) {
        print("VMS" + (store.utmRunning ? "" : " (UTM closed)"))
        if case .missing = store.utmState { print("  UTM is not installed"); return }
        if store.vms.isEmpty { print("  (none)") }
        for vm in store.vms {
            print("  \(pad(vm.name, 20)) \(pad(vm.status, 9)) \(vm.id)")
        }
    }

    private static func printContainers(_ store: TrayStore) {
        print("CONTAINERS")
        if case .offline(let reason) = store.dockerState { print("  \(reason)"); return }
        if case .missing = store.dockerState { print("  No Docker socket found"); return }
        if store.containers.isEmpty { print("  (none)") }
        for c in store.containers.sorted(by: { ($0.composeProject ?? "", $0.name) < ($1.composeProject ?? "", $1.name) }) {
            let ports = c.isRunning ? c.publishedPorts.map { ":\($0)" }.joined(separator: " ") : ""
            print("  \(pad(c.name, 28)) \(pad(c.state, 9)) \(pad(c.image, 24)) \(ports)")
        }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data(("hangar: " + message + "\n").utf8))
    }
}
