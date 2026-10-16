import Foundation

private enum Constants {
  /// `profile <verb> <profile> …`: the profile name is this argument.
  static let profileIndex = 2
  /// `profile rename <name> <new name>` / `profile add <profile> <member>…`.
  static let secondIndex = 3
  static let renameUsage =
    "usage: hangar profile rename <name> <new name>  (quote names with spaces)"
}

// MARK: - Profiles

extension CLI {
  /// `profile <verb> …`. Every verb that changes a profile prints the result, as JSON with
  /// `--json`, so a caller can check what it did.
  static func profile(_ args: [String], _ store: HangarStore, json: Bool) async throws {
    switch args.dropFirst().first {
    case "list":
      if json { print(CLIJSON.profiles(store)) } else { CLIPrinter.profiles(store) }
    case "show":
      show(try findProfile(args, store), store, json: json)
    case "create", "save":
      try create(args, store, json: json)
    case "rename":
      try rename(args, store, json: json)
    case "add":
      try changeMembers(args, store, json: json, adding: true)
    case "remove":
      try changeMembers(args, store, json: json, adding: false)
    case "delete":
      let profile = try findProfile(args, store)
      store.deleteProfile(profile)
      print(json ? CLIJSON.deleted(profile) : "deleted \(profile.name)")
    case "start", "stop":
      try await run(args, store, json: json)
    default:
      throw Failure.usage(usage)
    }
  }

  /// `profile create <name>` makes an empty profile; `profile save <name>` fills it with
  /// everything running now.
  private static func create(_ args: [String], _ store: HangarStore, json: Bool) throws {
    let verb = args.dropFirst().first ?? ""
    let name = try argument(args, at: Constants.profileIndex, "profile \(verb) <name>")
    try requireFreeName(name, store)
    let profile =
      verb == "save"
      ? store.createProfileFromRunning(named: name) : store.createEmptyProfile(named: name)
    show(profile, store, json: json)
  }

  /// `profile start|stop <name>`, waiting until every member has been asked.
  private static func run(_ args: [String], _ store: HangarStore, json: Bool) async throws {
    let isStart = args.dropFirst().first == "start"
    let profile = try findProfile(args, store)
    if isStart {
      try await store.startProfileNow(profile)
    } else {
      try await store.stopProfileNow(profile)
    }
    if json {
      await store.refresh()
      show(profile, store, json: true)
    } else {
      print("\(isStart ? "started" : "stopped") \(profile.name)")
    }
  }

  /// `profile rename <name> <new name>`.
  private static func rename(_ args: [String], _ store: HangarStore, json: Bool) throws {
    guard args.count == Constants.secondIndex + 1 else {
      throw Failure.usage(Constants.renameUsage)
    }
    let profile = try findProfile(named: args[Constants.profileIndex], store)
    let newName = args[Constants.secondIndex]
    if !matches(profile.name, newName) { try requireFreeName(newName, store) }
    store.renameProfile(profile, to: newName)
    show(store.current(profile) ?? profile, store, json: json)
  }

  /// `profile add|remove <profile> <member>…`. Removing also accepts the raw id or name of a
  /// member that no longer exists.
  private static func changeMembers(
    _ args: [String],
    _ store: HangarStore,
    json: Bool,
    adding: Bool
  ) throws {
    guard args.count > Constants.secondIndex else {
      let verb = adding ? "add" : "remove"
      throw Failure.usage("usage: hangar profile \(verb) <profile> <vm|container>…")
    }
    let profile = try findProfile(named: args[Constants.profileIndex], store)
    for text in args[Constants.secondIndex...] {
      let key = MemberKey(text)
      if adding {
        add(try findMember(key, store), to: profile, store)
      } else {
        try remove(key, from: profile, store)
      }
    }
    show(store.current(profile) ?? profile, store, json: json)
  }

  private static func add(_ member: ProfileMember, to profile: Profile, _ store: HangarStore) {
    switch member {
    case .vm(let vm): store.add(vm, to: profile)
    case .container(let container): store.add(container, to: profile)
    }
  }

  private static func remove(
    _ key: MemberKey,
    from profile: Profile,
    _ store: HangarStore
  ) throws {
    let current = store.current(profile) ?? profile
    if let member = try? findMember(key, store) {
      switch member {
      case .vm(let vm) where current.vmIDs.contains(vm.id):
        store.removeVM(id: vm.id, from: profile)
        return
      case .container(let container) where current.containerNames.contains(container.name):
        store.removeContainer(named: container.name, from: profile)
        return
      default:
        break
      }
    }
    // A member whose machine is gone is only known by the raw id or name the profile stored.
    if key.kind != .container, current.vmIDs.contains(key.name) {
      store.removeVM(id: key.name, from: profile)
    } else if key.kind != .vm, current.containerNames.contains(key.name) {
      store.removeContainer(named: key.name, from: profile)
    } else {
      throw Failure.usage("\(key.name) is not in \(profile.name)")
    }
  }

  private static func show(_ profile: Profile, _ store: HangarStore, json: Bool) {
    if json {
      print(CLIJSON.profile(profile, store))
    } else {
      CLIPrinter.profile(profile, store)
    }
  }

  private static func requireFreeName(_ name: String, _ store: HangarStore) throws {
    guard !store.profiles.contains(where: { matches($0.name, name) }) else {
      throw Failure.usage("a profile named \(name) already exists")
    }
  }
}
