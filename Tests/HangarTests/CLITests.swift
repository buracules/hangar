import Foundation
import Testing

@testable import Hangar

@MainActor
struct CLITests {
  @Test(arguments: [["status"], ["up", "work"], ["sql", "db", "select 1"], ["-h"]])
  func commandsRunTheCLI(arguments: [String]) {
    #expect(CLI.handles(arguments))
  }

  @Test(arguments: [[], ["-NSDocumentRevisionsDebugMode", "YES"], ["unknown"]])
  func anythingElseLaunchesTheApp(arguments: [String]) {
    #expect(!CLI.handles(arguments))
  }
}
