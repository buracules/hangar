import Foundation
import Testing

@testable import Hangar

struct ANSIParserTests {
  @Test func paletteAndRGBColoursAreRead() {
    var parser = ANSIParser()

    let runs = parser.parse(
      "\u{1B}[38;5;208morange\u{1B}[0m \u{1B}[38;2;10;20;30mrgb\u{1B}[39m plain"
    )

    #expect(runs.map(\.text) == ["orange", " ", "rgb", " plain"])
    #expect(runs[0].style.foreground == .indexed(208))
    #expect(runs[2].style.foreground == .rgb(red: 10, green: 20, blue: 30))
    #expect(runs[3].style.foreground == nil)
  }

  @Test func brightColoursMapToTheUpperPalette() {
    var parser = ANSIParser()

    let runs = parser.parse("\u{1B}[91mbright red\u{1B}[104m on blue")

    #expect(runs[0].style.foreground == .indexed(9))
    #expect(runs[1].style.background == .indexed(12))
  }

  @Test func resetClearsEveryAttribute() {
    var parser = ANSIParser()

    _ = parser.parse("\u{1B}[1;2;4;31mloud")
    _ = parser.parse("\u{1B}[0m")

    #expect(parser.style == LogStyle())
  }

  @Test func runsWithTheSameStyleAreMerged() {
    var parser = ANSIParser()

    let runs = parser.parse("a\u{1B}[0mb")

    #expect(runs.map(\.text) == ["ab"])
  }
}
