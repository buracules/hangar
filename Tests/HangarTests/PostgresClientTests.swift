import Foundation
import Testing

@testable import Hangar

struct PostgresClientTests {
  @Test(arguments: [
    "select 1", "  SELECT * FROM t;  ", "with x as (select 1) select * from x", "(select 1)",
    "VALUES (1)",
  ])
  func singleQueriesCanBeWrapped(sql: String) {
    #expect(PostgresClient.isSingleQuery(sql))
  }

  @Test(arguments: [
    "select 1; select 2", "insert into t values (1)", "begin", "update t set x = 1",
  ])
  func otherStatementsRunAsTheyAre(sql: String) {
    #expect(!PostgresClient.isSingleQuery(sql))
  }

  @Test func trailingSemicolonsAndWhitespaceAreStripped() {
    #expect(PostgresClient.stripTrailingSemicolons("  select 1;;\n") == "select 1")
  }

  @Test func identifiersAndLiteralsAreQuoted() {
    #expect(SQLQuote.identifier(#"my "table""#) == #""my ""table""""#)
    #expect(SQLQuote.literal("it's") == "'it''s'")
  }

  @Test func aTableNamesItselfSafely() {
    let table = TableInfo(
      schema: "public",
      name: #"odd"name"#,
      kind: "r",
      estimatedRows: 0,
      size: ""
    )

    #expect(table.qualifiedName == #""public"."odd""name""#)
    #expect(!table.isView)
  }
}
