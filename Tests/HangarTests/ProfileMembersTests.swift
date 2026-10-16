import Foundation
import Testing

@testable import Hangar

struct ProfileMembersTests {
  private func vm(_ name: String, _ status: String) -> VirtualMachine {
    VirtualMachine(id: name, name: name, status: status)
  }

  @Test func oneMemberDownIsNamed() {
    let members = ProfileMembers(
      vms: [vm("berqNET", "started"), vm("lab", "stopped")],
      containers: [],
      missing: 0
    )
    #expect(members.notRunningSummary == "lab isn't running")
  }

  @Test func severalMembersDownAreCounted() {
    let members = ProfileMembers(
      vms: [vm("a", "stopped"), vm("b", "paused"), vm("c", "stopped")],
      containers: [],
      missing: 0
    )
    #expect(members.notRunningSummary == "a and 2 more aren't running")
  }

  @Test func everythingUpSaysNothing() {
    let members = ProfileMembers(vms: [vm("a", "started")], containers: [], missing: 0)
    #expect(members.notRunningSummary == nil)
  }

  @Test func missingMembersAreMentionedWhenTheRestIsUp() {
    let members = ProfileMembers(vms: [vm("a", "started")], containers: [], missing: 2)
    #expect(members.notRunningSummary == "2 members are missing")
  }
}
