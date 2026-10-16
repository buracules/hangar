import Foundation
import Testing

@testable import Hangar

struct SQLBuilderTests {
  private let users = TableInfo(
    schema: "public",
    name: "users",
    kind: "r",
    estimatedRows: 0,
    size: ""
  )

  @Test func aRowBecomesAnInsertWithQuotedValuesAndNull() {
    let sql = SQLBuilder.insert(
      into: users,
      columns: ["id", "email", "deleted_at"],
      values: ["1042", "o'neil@acme.test", nil]
    )

    let expected =
      #"INSERT INTO "public"."users" ("id", "email", "deleted_at") "#
      + #"VALUES ('1042', 'o''neil@acme.test', NULL);"#
    #expect(sql == expected)
  }

  @Test func aFilterMatchesAValueOrNull() {
    #expect(SQLBuilder.equals(column: "role", value: "admin") == #""role" = 'admin'"#)
    #expect(SQLBuilder.equals(column: "deleted_at", value: nil) == #""deleted_at" IS NULL"#)
  }
}
