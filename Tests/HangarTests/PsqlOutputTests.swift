import Foundation
import Testing

@testable import Hangar

struct PsqlOutputTests {
  private let fs = PsqlOutput.fieldSeparator
  private let rs = PsqlOutput.recordSeparator
  private let null = PsqlOutput.nullMarker

  /// The exact bytes psql 17 printed for
  /// `select 1 as a, null as b, E'x\ny' as c, '' as e; select 2 as d`.
  @Test func nullEmptyAndNewlineValuesStayDistinct() {
    let output = "a\(fs)b\(fs)c\(fs)e\(rs)1\(fs)\(null)\(fs)x\ny\(fs)\nd\(rs)2\n"

    let results = PsqlOutput.parse(output)

    #expect(results.map(\.columns) == [["a", "b", "c", "e"], ["d"]])
    #expect(results[0].rows == [["1", nil, "x\ny", ""]])
    #expect(results[1].rows == [["2"]])
  }

  @Test func emptyStringIsNotNull() {
    let results = PsqlOutput.parse("e\(rs)\n")

    #expect(results[0].rows == [[""]])
  }

  @Test func severalStatementsGiveSeveralResults() {
    let results = PsqlOutput.parse("a\(rs)1\nb\(rs)x\n")

    #expect(results.map(\.columns) == [["a"], ["b"]])
    #expect(results.map(\.rows) == [[["1"]], [["x"]]])
  }

  @Test func aHeaderWithoutRowsIsAnEmptyResult() {
    let results = PsqlOutput.parse("a\n")

    #expect(results[0].columns == ["a"])
    #expect(results[0].rows.isEmpty)
  }

  @Test func commandTagsBecomeMessages() {
    let results = PsqlOutput.parse("BEGIN\nCREATE TABLE\nINSERT 0 2\nROLLBACK\n")

    #expect(results.flatMap(\.messages) == ["BEGIN", "CREATE TABLE", "INSERT 0 2", "ROLLBACK"])
    #expect(results.allSatisfy { $0.columns.isEmpty })
  }
}
