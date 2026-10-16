import Foundation

private enum Constants {
  static let commands: Set<String> = [
    "status", "up", "down", "profile", "project", "vm", "ps", "start", "stop", "restart", "logs",
    "sql",
    "help", "--help", "-h",
  ]
  static let successExitCode: Int32 = 0
  static let failureExitCode: Int32 = 1
  static let usageExitCode: Int32 = 2
  static let jsonFlag = "--json"
}

/// `hangar <command>`: the same binary as the menu bar app, run with arguments. It drives
/// the same HangarStore, so profiles, the known-VM list and start logic are shared.
@MainActor
enum CLI {
  static let usage = """
    usage: hangar <command>

      status                         VMs, containers and profiles at a glance
      up|down <profile>              start or stop everything in a profile

      profile list                   list profiles
      profile show <name>            a profile's members and their state
      profile create <name>          create an empty profile
      profile save <name>            create a profile from everything running now
      profile rename <name> <new>    rename (quote names with spaces)
      profile add <profile> <m>…     add VMs/containers by name, UUID or id prefix;
                                     prefix vm: or container: if a name means both
      profile remove <profile> <m>…  remove members, also ones that no longer exist
      profile start|stop <name>      same as up|down
      profile delete <name>          delete a profile (its machines are left alone)
      project list                   list project folders and how each would run
      project add <folder>           add a Node or Python project folder
      project remove <name>          forget a project (its files are left alone)
                                     (start and stop projects from the app)
      vm list                        list VMs
      vm start|stop|suspend <vm>     control a VM (name or UUID); stop asks the guest OS
      vm kill <vm>                   cut a VM's power
      vm ip <vm>                     print a VM's IP (needs the guest agent)
      ps                             list containers
      start|stop|restart <container> control a container (name or id prefix)
      logs [-f] <container>          print a container's last 200 lines; -f keeps following
      sql <container> [-d db] <sql>  run SQL in a postgres container (credentials from its env)

    --json   machine-readable output for status, ps, vm list, project and profile commands
    """

  /// Whether the arguments are a CLI command. Anything else — including the `-NS…` flags
  /// Xcode passes — launches the menu bar app.
  static func handles(_ arguments: [String]) -> Bool {
    arguments.first.map(Constants.commands.contains) ?? false
  }

  /// Runs a command and returns the process exit code: 0 done, 1 failed, 2 misused.
  static func run(_ arguments: [String]) async -> Int32 {
    let store = HangarStore()
    await store.refresh()
    let json = arguments.contains(Constants.jsonFlag)
    let arguments = expandingShorthand(arguments.filter { $0 != Constants.jsonFlag })
    do {
      try await dispatch(arguments, store, json: json)
      return Constants.successExitCode
    } catch Failure.usage(let message) {
      CLIPrinter.error(message)
      return Constants.usageExitCode
    } catch {
      CLIPrinter.error(error.localizedDescription)
      return Constants.failureExitCode
    }
  }

  /// `up`/`down` are shorthand for `profile start`/`profile stop`.
  private static func expandingShorthand(_ arguments: [String]) -> [String] {
    switch arguments.first {
    case "up": ["profile", "start"] + arguments.dropFirst()
    case "down": ["profile", "stop"] + arguments.dropFirst()
    default: arguments
    }
  }

  private static func dispatch(_ args: [String], _ store: HangarStore, json: Bool) async throws {
    switch (args.first, args.dropFirst().first) {
    case ("help", _), ("--help", _), ("-h", _):
      print(usage)
    case ("status", _), ("ps", _), ("vm", "list"):
      list(args.first ?? "", store, json: json)
    case ("profile", _):
      try await profile(args, store, json: json)
    case ("project", _):
      try project(args, store, json: json)
    case ("vm", let action?):
      try await vm(action, try findVM(args, store), store)
    case ("logs", _):
      try await logs(args, store)
    case ("sql", _):
      try await sql(args, store)
    case (let action?, _) where ContainerAction(rawValue: action) != nil:
      try await container(action, try findContainer(args, store), store)
    default:
      throw Failure.usage(usage)
    }
  }

  /// `status`, `ps` and `vm list`, as text or JSON.
  private static func list(_ command: String, _ store: HangarStore, json: Bool) {
    switch (command, json) {
    case ("status", true): print(CLIJSON.status(store))
    case ("status", false): CLIPrinter.status(store)
    case ("ps", true): print(CLIJSON.containers(store))
    case ("ps", false): CLIPrinter.containers(store)
    case (_, true): print(CLIJSON.vms(store))
    case (_, false): CLIPrinter.vms(store)
    }
  }
}
