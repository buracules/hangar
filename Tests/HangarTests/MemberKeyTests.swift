import Foundation
import Testing

@testable import Hangar

struct MemberKeyTests {
  @Test func aPrefixPicksTheKind() {
    let vm = MemberKey("vm:berqNET")
    let container = MemberKey("container:db")

    #expect(vm.kind == .vm && vm.name == "berqNET")
    #expect(container.kind == .container && container.name == "db")
  }

  @Test func aBareNameLeavesTheKindOpen() {
    let key = MemberKey("hermes-postgres")

    #expect(key.kind == nil && key.name == "hermes-postgres")
  }

  @Test func onlyTheFirstPrefixCounts() {
    #expect(MemberKey("vm:container:x").name == "container:x")
  }
}
