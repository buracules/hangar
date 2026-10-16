import Foundation

/// `--json` output: stable, machine-readable shapes for scripts and for Claude.
@MainActor
enum CLIJSON {
  static func status(_ store: HangarStore) -> String {
    encode(
      StatusOutput(
        profiles: store.profiles.map { ProfileOutput($0, store) },
        vms: store.vms.map(VMOutput.init),
        containers: store.containers.map(ContainerOutput.init),
        isUTMRunning: store.isUTMRunning,
        isDockerReachable: store.dockerState == .ready
      )
    )
  }

  static func profiles(_ store: HangarStore) -> String {
    encode(store.profiles.map { ProfileOutput($0, store) })
  }

  static func profile(_ profile: Profile, _ store: HangarStore) -> String {
    encode(ProfileOutput(store.current(profile) ?? profile, store))
  }

  static func deleted(_ profile: Profile) -> String {
    encode(DeletedOutput(deleted: profile.name))
  }

  static func vms(_ store: HangarStore) -> String {
    encode(store.vms.map(VMOutput.init))
  }

  static func containers(_ store: HangarStore) -> String {
    encode(store.containers.map(ContainerOutput.init))
  }

  private static func encode(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value) else { return "{}" }
    return String(bytes: data, encoding: .utf8) ?? "{}"
  }
}

/// Everything at once.
private struct StatusOutput: Encodable {
  let profiles: [ProfileOutput]
  let vms: [VMOutput]
  let containers: [ContainerOutput]
  let isUTMRunning: Bool
  let isDockerReachable: Bool
}

/// A profile with its members' current state. Members whose machine no longer exists are
/// listed by the raw id or name the profile stored.
private struct ProfileOutput: Encodable {
  let name: String
  let runningCount: Int
  let total: Int
  let vms: [VMOutput]
  let containers: [ContainerOutput]
  let missingVMIDs: [String]
  let missingContainerNames: [String]

  @MainActor
  init(_ profile: Profile, _ store: HangarStore) {
    let members = store.members(of: profile)
    name = profile.name
    runningCount = members.runningCount
    total = members.total
    vms = members.vms.map(VMOutput.init)
    containers = members.containers.map(ContainerOutput.init)
    missingVMIDs = profile.vmIDs.filter { id in !members.vms.contains { $0.id == id } }
    missingContainerNames = profile.containerNames.filter { name in
      !members.containers.contains { $0.name == name }
    }
  }
}

/// A VM.
private struct VMOutput: Encodable {
  let id: String
  let name: String
  let status: String
  let isRunning: Bool

  init(_ vm: VirtualMachine) {
    id = vm.id
    name = vm.name
    status = vm.status
    isRunning = vm.isRunning
  }
}

/// A container.
private struct ContainerOutput: Encodable {
  let name: String
  let id: String
  let image: String
  let state: String
  let isRunning: Bool
  let composeProject: String?
  let ports: [Int]

  init(_ container: Container) {
    name = container.name
    id = container.shortID
    image = container.image
    state = container.state
    isRunning = container.isRunning
    composeProject = container.composeProject
    ports = container.publishedPorts
  }
}

/// What `profile delete --json` prints.
private struct DeletedOutput: Encodable {
  let deleted: String
}
