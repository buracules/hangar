import Foundation

private enum Constants {
  static let newProfileName = "New Profile"
}

// MARK: - Profiles

extension HangarStore {
  /// The profile's members that exist right now, and how many no longer do.
  func members(of profile: Profile) -> ProfileMembers {
    let vms = profile.vmIDs.compactMap { id in self.vms.first { $0.id == id } }
    let containers = profile.containerNames.compactMap { name in
      self.containers.first { $0.name == name }
    }
    let expected = profile.vmIDs.count + profile.containerNames.count
    return ProfileMembers(
      vms: vms,
      containers: containers,
      missing: expected - vms.count - containers.count
    )
  }

  /// Saves everything currently running as a new profile.
  @discardableResult
  func createProfileFromRunning(named name: String) -> Profile {
    let profile = Profile(
      name: name,
      vmIDs: vms.filter(\.isRunning).map(\.id),
      containerNames: containers.filter(\.isRunning).map(\.name)
    )
    profiles.append(profile)
    return profile
  }

  /// A new, empty profile. Without a name it is called "New Profile", "New Profile 2", …
  /// whichever is free.
  @discardableResult
  func createEmptyProfile(named requestedName: String? = nil) -> Profile {
    let taken = Set(profiles.map(\.name))
    var name = requestedName ?? Constants.newProfileName
    var number = 1
    while requestedName == nil, taken.contains(name) {
      number += 1
      name = "\(Constants.newProfileName) \(number)"
    }
    let profile = Profile(name: name, vmIDs: [], containerNames: [])
    profiles.append(profile)
    return profile
  }

  func renameProfile(_ profile: Profile, to name: String) {
    let name = name.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    updateProfile(profile) { $0.name = name }
  }

  /// Deletes only the profile; its VMs and containers are left as they are.
  func deleteProfile(_ profile: Profile) {
    profiles.removeAll { $0.id == profile.id }
  }

  /// By raw id, so a VM that no longer exists can be removed too.
  func removeVM(id: String, from profile: Profile) {
    updateProfile(profile) { $0.vmIDs.removeAll { $0 == id } }
  }

  /// By name, so a container that no longer exists can be removed too.
  func removeContainer(named name: String, from profile: Profile) {
    updateProfile(profile) { $0.containerNames.removeAll { $0 == name } }
  }

  /// Adds the VM to the profile unless it is already a member.
  func add(_ vm: VirtualMachine, to profile: Profile) {
    updateProfile(profile) { profile in
      if !profile.vmIDs.contains(vm.id) { profile.vmIDs.append(vm.id) }
    }
  }

  /// Adds the container to the profile unless it is already a member.
  func add(_ container: Container, to profile: Profile) {
    updateProfile(profile) { profile in
      if !profile.containerNames.contains(container.name) {
        profile.containerNames.append(container.name)
      }
    }
  }

  /// Adds every container of a compose project that is not a member yet.
  func add(_ group: ComposeGroup, to profile: Profile) {
    updateProfile(profile) { profile in
      for container in group.containers where !profile.containerNames.contains(container.name) {
        profile.containerNames.append(container.name)
      }
    }
  }

  /// The profile as stored now, after any edits made since it was looked up.
  func current(_ profile: Profile) -> Profile? {
    profiles.first { $0.id == profile.id }
  }

  /// Picks up edits made by the other side — the CLI while the app runs, or the reverse.
  func reloadProfiles() {
    let stored = SharedFiles.profiles.load() ?? []
    if stored != profiles { profiles = stored }
  }

  /// Adds the VM to the profile, or removes it if it is already a member.
  func toggle(_ vm: VirtualMachine, in profile: Profile) {
    updateProfile(profile) { profile in
      if let index = profile.vmIDs.firstIndex(of: vm.id) {
        profile.vmIDs.remove(at: index)
      } else {
        profile.vmIDs.append(vm.id)
      }
    }
  }

  /// Adds the container to the profile, or removes it if it is already a member.
  func toggle(_ container: Container, in profile: Profile) {
    updateProfile(profile) { profile in
      if let index = profile.containerNames.firstIndex(of: container.name) {
        profile.containerNames.remove(at: index)
      } else {
        profile.containerNames.append(container.name)
      }
    }
  }

  private func updateProfile(_ profile: Profile, _ change: (inout Profile) -> Void) {
    guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
    change(&profiles[index])
  }
}
