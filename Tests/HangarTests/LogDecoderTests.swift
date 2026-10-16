import Foundation
import Testing

@testable import Hangar

struct LogDecoderTests {
  @Test func rawOutputKeepsColoursAsRuns() {
    let lines = Fixtures.decode([
      Fixtures.raw("\u{1B}[32mVITE\u{1B}[0m ready in \u{1B}[1m312\u{1B}[22m ms\r\n")
    ])

    #expect(lines.map(\.text) == ["VITE ready in 312 ms"])
    #expect(lines[0].runs.first?.style.foreground == .indexed(2))
    #expect(lines[0].runs.contains { $0.text == "312" && $0.style.isBold })
  }

  @Test func framedOutputKeepsStdoutAndStderrApart() {
    let lines = Fixtures.decode([
      Fixtures.frame(DockerFrame.stderr, "boom\n") + Fixtures.frame(DockerFrame.stdout, "fine\n")
    ])

    #expect(lines.map(\.text) == ["boom", "fine"])
    #expect(lines.map(\.isStderr) == [true, false])
  }

  @Test func aFrameSplitAcrossChunksStillDecodes() {
    let stream =
      Fixtures.frame(DockerFrame.stdout, "first\n") + Fixtures.frame(DockerFrame.stdout, "second\n")

    let lines = Fixtures.decode([stream.prefix(10), stream.dropFirst(10)])

    #expect(lines.map(\.text) == ["first", "second"])
  }

  @Test func anEscapeSplitAcrossChunksStillDecodes() {
    let lines = Fixtures.decode([
      Fixtures.raw("part one \u{1B}[3"), Fixtures.raw("4mblue\u{1B}[0m\n"),
    ])

    #expect(lines.map(\.text) == ["part one blue"])
    #expect(lines[0].runs.last?.style.foreground == .indexed(4))
  }

  @Test func aColourCarriesOverToTheNextLine() {
    let lines = Fixtures.decode([Fixtures.raw("\u{1B}[31mstarts red\nstill red\u{1B}[0m\n")])

    #expect(lines.allSatisfy { $0.runs.first?.style.foreground == .indexed(1) })
  }

  @Test func aCarriageReturnShowsOnlyTheFinalState() {
    let lines = Fixtures.decode([Fixtures.raw("10%\r50%\r100% done\n")])

    #expect(lines.map(\.text) == ["100% done"])
  }

  @Test func linksAndCursorCodesAreDropped() {
    let lines = Fixtures.decode([
      Fixtures.raw("\u{1B}]8;;http://x\u{07}link\u{1B}]8;;\u{07} \u{1B}[2K\u{1B}[1Gcleared\n")
    ])

    #expect(lines.map(\.text) == ["link cleared"])
  }

  @Test func dockersTimestampBecomesTheLineTime() throws {
    let lines = Fixtures.decode([Fixtures.raw("2026-10-16T15:10:54.505123456Z hello\n")])

    let time = try #require(lines.first?.time)
    #expect(lines.map(\.text) == ["hello"])
    #expect(abs(time.timeIntervalSince1970 - 1_792_163_454.505) < 0.001)
  }

  @Test func aPartialLineWaitsForItsNewline() {
    var decoder = LogDecoder()

    #expect(decoder.feed(Fixtures.raw("no newline yet")).isEmpty)
    #expect(decoder.feed(Fixtures.raw(" — now\n")).map(\.text) == ["no newline yet — now"])
  }
}
