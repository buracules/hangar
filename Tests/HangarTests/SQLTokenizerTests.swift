import Foundation
import Testing

@testable import Hangar

struct SQLTokenizerTests {
  /// The text each token covers, with its kind.
  private func tokens(_ sql: String) -> [(String, SQLToken.Kind)] {
    let text = sql as NSString
    return SQLTokenizer.tokens(in: sql).map { (text.substring(with: $0.range), $0.kind) }
  }

  @Test func keywordsNumbersStringsAndCallsAreFound() {
    let found = tokens("SELECT count(*) FROM users WHERE role <> 'service' LIMIT 200")

    #expect(found.map(\.0) == ["SELECT", "count", "FROM", "WHERE", "'service'", "LIMIT", "200"])
    #expect(found.map(\.1) == [.keyword, .function, .keyword, .keyword, .string, .keyword, .number])
  }

  @Test func keywordsInsideStringsAndCommentsStayPlain() {
    let found = tokens("-- select everything\nselect 'from where'")

    #expect(found.map(\.1) == [.comment, .keyword, .string])
  }

  @Test func plainIdentifiersAreNotTokens() {
    #expect(tokens("users u").isEmpty)
  }
}
