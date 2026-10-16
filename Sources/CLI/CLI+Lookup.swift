import Foundation

private enum Constants {
  /// `profile <verb> <name…>` and `vm <verb> <vm…>`: the name starts here.
  static let subcommandArgumentIndex = 2
  /// `<verb> <container…>`: the name starts here.
  static let commandArgumentIndex = 1
}

// MARK: - Lookup

extension CLI {
  /// Everything from `index` on, joined: names may contain spaces.
  static func argument(_ args: [String], at index: Int, _ form: String) throws -> String {
    guard args.count > index else { throw Failure.usage("usage: hangar \(form)") }
    return args[index...].joined(separator: " ")
  }

  /// The profile named in the arguments, case-insensitively.
  static func findProfile(_ args: [String], _ store: HangarStore) throws -> Profile {
    let verb = args.dropFirst().first ?? ""
    let name = try argument(args, at: Constants.subcommandArgumentIndex, "profile \(verb) <name>")
    return try findProfile(named: name, store)
  }

  /// The profile with this name, case-insensitively.
  static func findProfile(named name: String, _ store: HangarStore) throws -> Profile {
    guard let profile = store.profiles.first(where: { matches($0.name, name) }) else {
      throw Failure.usage("no profile named \(name) — try: hangar profile list")
    }
    return profile
  }

  /// The VM or container a key names. Without a prefix a name matching both is ambiguous.
  static func findMember(_ key: MemberKey, _ store: HangarStore) throws -> ProfileMember {
    let vm = key.kind == .container ? nil : vm(matching: key.name, store)
    let container = key.kind == .vm ? nil : try? container(matching: key.name, store)
    switch (vm, container) {
    case (let vm?, nil): return .vm(vm)
    case (nil, let container?): return .container(container)
    case (.some, .some):
      throw Failure.usage(
        "\(key.name) is both a VM and a container — use vm:\(key.name) or container:\(key.name)"
      )
    case (nil, nil):
      throw Failure.usage("no VM or container named \(key.name) — try: hangar status")
    }
  }

  /// The VM named in the arguments, by name or UUID, case-insensitively.
  static func findVM(_ args: [String], _ store: HangarStore) throws -> VirtualMachine {
    let verb = args.dropFirst().first ?? ""
    let key = try argument(args, at: Constants.subcommandArgumentIndex, "vm \(verb) <name|uuid>")
    guard let vm = vm(matching: key, store) else {
      throw Failure.usage("no VM named \(key) — try: hangar vm list")
    }
    return vm
  }

  /// The container named in the arguments, by exact name or an unambiguous id prefix.
  static func findContainer(_ args: [String], _ store: HangarStore) throws -> Container {
    let verb = args.first ?? ""
    let key = try argument(args, at: Constants.commandArgumentIndex, "\(verb) <container>")
    return try container(matching: key, store)
  }

  private static func vm(matching key: String, _ store: HangarStore) -> VirtualMachine? {
    store.vms.first { matches($0.id, key) || matches($0.name, key) }
  }

  private static func container(matching key: String, _ store: HangarStore) throws -> Container {
    if let exact = store.containers.first(where: { $0.name == key }) { return exact }
    let byID = store.containers.filter { $0.id.hasPrefix(key) }
    guard byID.count == 1, let container = byID.first else {
      let reason =
        byID.isEmpty
        ? "no container named \(key) — try: hangar ps" : "\(key) matches several containers"
      throw Failure.usage(reason)
    }
    return container
  }

  static func matches(_ value: String, _ key: String) -> Bool {
    value.caseInsensitiveCompare(key) == .orderedSame
  }
}
