import Testing

@testable import Hangar

struct UTMListTests {
  @Test func rowsAfterTheHeaderBecomeVMs() {
    let output = """
      UUID                                 Status   Name
      A69873CB-897E-4A66-B040-793D73B15CEA stopped  berq NET
      """
    let vms = UTMControl.parseList(output)
    #expect(vms.map(\.name) == ["berq NET"])
    #expect(vms.first?.status == "stopped")
  }

  @Test func messagesAreNeverMistakenForVMs() {
    let output = """
      Error from event: The operation couldn’t be completed. (OSStatus error -1743.)
      UUID                                 Status   Name
      """
    #expect(UTMControl.parseList(output).isEmpty)
  }
}
