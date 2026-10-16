import Foundation

// MARK: - Profile runs

extension HangarStore {
  /// Starts every member that is not running yet, in the background.
  func startProfile(_ profile: Profile) {
    let (vms, containers) = membersToStart(profile)
    runProfile(profile, memberIDs: vms.map(\.id) + containers.map(\.id)) {
      try await $0.start(vms: vms, containers: containers, cause: Cause.profile(profile.name))
    }
  }

  /// Stops every running member, in the background.
  func stopProfile(_ profile: Profile) {
    let (vms, containers) = membersToStop(profile)
    runProfile(profile, memberIDs: vms.map(\.id) + containers.map(\.id)) {
      try await $0.stop(vms: vms, containers: containers, cause: Cause.profile(profile.name))
    }
  }

  /// `startProfile`, awaited — for the CLI. Call `refresh()` first so membership is current.
  func startProfileNow(_ profile: Profile) async throws {
    let (vms, containers) = membersToStart(profile)
    try await start(vms: vms, containers: containers, cause: Cause.profile(profile.name))
  }

  /// `stopProfile`, awaited — for the CLI. Call `refresh()` first so membership is current.
  func stopProfileNow(_ profile: Profile) async throws {
    let (vms, containers) = membersToStop(profile)
    try await stop(vms: vms, containers: containers, cause: Cause.profile(profile.name))
  }

  private func membersToStart(_ profile: Profile) -> ([VirtualMachine], [Container]) {
    let members = members(of: profile)
    return (
      members.vms.filter { !$0.isRunning && !$0.isTransitioning },
      members.containers.filter { !$0.isRunning }
    )
  }

  private func membersToStop(_ profile: Profile) -> ([VirtualMachine], [Container]) {
    let members = members(of: profile)
    return (members.vms.filter(\.isRunning), members.containers.filter(\.isRunning))
  }

  /// VMs first, so services in them are coming up while containers start. One member
  /// failing does not stop the others; all failures are reported together.
  private func start(vms: [VirtualMachine], containers: [Container], cause: String) async throws {
    var failures: [String] = []
    for vm in vms {
      do { try await bootVM(vm, cause: cause) } catch { failures.append(describe(vm.name, error)) }
    }
    for container in containers {
      do {
        try await run(.start, on: container, cause: cause)
      } catch {
        failures.append(describe(container.name, error))
      }
    }
    if !failures.isEmpty { throw Failure.someMembersFailed(failures) }
  }

  /// The reverse order: containers that depend on a VM go down before it does.
  private func stop(vms: [VirtualMachine], containers: [Container], cause: String) async throws {
    var failures: [String] = []
    for container in containers {
      do {
        try await run(.stop, on: container, cause: cause)
      } catch {
        failures.append(describe(container.name, error))
      }
    }
    for vm in vms {
      do {
        try await shutDown(vm, force: false, cause: cause)
      } catch {
        failures.append(describe(vm.name, error))
      }
    }
    if !failures.isEmpty { throw Failure.someMembersFailed(failures) }
  }

  private func describe(_ name: String, _ error: Error) -> String {
    "\(name): \(error.localizedDescription)"
  }

  /// Runs a profile action with the profile and every member it touches marked busy, so
  /// their rows show progress and their own buttons cannot race it.
  private func runProfile(
    _ profile: Profile,
    memberIDs: [String],
    _ action: @escaping @MainActor (HangarStore) async throws -> Void
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
}
