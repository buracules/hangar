import Foundation
import Testing

@testable import Hangar

struct SelectionHistoryTests {
  @Test func backAndForwardRetraceTheVisits() {
    var history = SelectionHistory<String>()
    history.visit(from: "a")
    history.visit(from: "b")

    #expect(history.goBack(from: "c") == "b")
    #expect(history.goBack(from: "b") == "a")
    #expect(!history.canGoBack)
    #expect(history.goForward(from: "a") == "b")
    #expect(history.goForward(from: "b") == "c")
    #expect(!history.canGoForward)
  }

  @Test func aNewVisitDropsTheForwardTrail() {
    var history = SelectionHistory<String>()
    history.visit(from: "a")
    _ = history.goBack(from: "b")

    history.visit(from: "a")

    #expect(!history.canGoForward)
  }

  @Test func leavingNothingRecordsNothing() {
    var history = SelectionHistory<String>()

    history.visit(from: nil)

    #expect(!history.canGoBack)
  }
}
