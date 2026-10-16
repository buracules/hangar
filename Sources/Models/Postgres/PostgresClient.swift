import Foundation

private enum Constants {
  static let imageMarkers = ["postgres", "postgis", "timescale", "pgvector"]
  /// Official image, Bitnami, then libpq's own variables — first one set wins.
  static let userVariables = ["POSTGRES_USER", "POSTGRESQL_USERNAME", "PGUSER"]
  static let databaseVariables = ["POSTGRES_DB", "POSTGRESQL_DATABASE", "PGDATABASE"]
  static let passwordVariables = ["POSTGRES_PASSWORD", "POSTGRESQL_PASSWORD", "PGPASSWORD"]
  static let defaultUser = "postgres"
  static let passwordEnvironmentKey = "PGPASSWORD"
  /// The shell's exit codes for "found but not executable" and "not found".
  static let notExecutableCode = 126
  static let notFoundCode = 127
  static let missingExecutableMessage = "executable file not found"
  static let successCode = 0
  /// Hides the real last column's trailing newline from the parser; see `select`.
  static let markerColumn = "__hangar_end"
  static let singleQueryKeywords: Set<String> = ["select", "with", "values", "table"]
}

/// Talks to Postgres inside a container by running its own `psql` through `docker exec`.
/// No driver, no published port needed, and the credentials come from the container's
/// environment — so a postgres container is browsable with zero setup.
struct PostgresClient: Sendable {
  let docker: DockerClient
  let containerID: String
  let user: String
  let defaultDatabase: String
  let password: String?

  /// Whether the container runs a Postgres image.
  static func isPostgres(_ container: Container) -> Bool {
    let image = container.image.lowercased()
    return Constants.imageMarkers.contains { image.contains($0) }
  }

  /// A client using the user, database and password the container was started with.
  static func connect(
    to container: Container,
    docker: DockerClient
  ) async throws -> PostgresClient {
    let env = try await docker.environment(container.id)
    let first = { (names: [String]) in names.lazy.compactMap { env[$0] }.first }
    let user = first(Constants.userVariables) ?? Constants.defaultUser
    return PostgresClient(
      docker: docker,
      containerID: container.id,
      user: user,
      defaultDatabase: first(Constants.databaseVariables) ?? user,
      password: first(Constants.passwordVariables)
    )
  }

  /// Runs SQL as-is. Several statements give several results; statements without rows
  /// (BEGIN, INSERT 0 2, …) come back as messages.
  func run(_ sql: String, database: String? = nil) async throws -> [QueryResult] {
    let command =
      ["psql", "-X", "-v", "ON_ERROR_STOP=1", "-U", user, "-d", database ?? defaultDatabase]
      + PsqlOutput.arguments + ["-c", sql]
    var environment: [String: String] = [:]
    if let password { environment[Constants.passwordEnvironmentKey] = password }
    let result = try await docker.exec(containerID, command, environment: environment)
    let stderr = (String(bytes: result.stderr, encoding: .utf8) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard result.exitCode == Constants.successCode else {
      throw failure(exitCode: result.exitCode, stderr: stderr)
    }
    // Lossy on purpose: a stray invalid byte in one value should not lose the whole result.
    // swiftlint:disable:next optional_data_string_conversion
    var results = PsqlOutput.parse(String(decoding: result.stdout, as: UTF8.self))
    // NOTICE/WARNING lines from a successful run.
    if !stderr.isEmpty { results.append(.message(stderr)) }
    return results
  }

  /// Runs one row-returning statement, capped at `limit` rows. Wrapping it also appends a
  /// marker column, so a newline in the real last column cannot be mistaken for the end of
  /// the result.
  func select(
    _ sql: String,
    database: String? = nil,
    limit: Int,
    offset: Int = 0
  ) async throws -> QueryResult {
    let wrapped = """
      SELECT q.*, 0 AS \(SQLQuote.identifier(Constants.markerColumn)) FROM (
      \(sql)
      ) q LIMIT \(limit + 1) OFFSET \(offset)
      """
    let results = try await run(wrapped, database: database)
    guard var result = results.first(where: { !$0.columns.isEmpty }) else { return .empty }
    result.columns.removeLast()
    result.rows = result.rows.map { Array($0.dropLast()) }
    if result.rows.count > limit {
      result.rows.removeLast()
      result.isTruncated = true
    }
    return result
  }

  /// A single SELECT/WITH/VALUES/TABLE statement, which `select` can safely wrap.
  static func isSingleQuery(_ sql: String) -> Bool {
    let body = stripTrailingSemicolons(sql)
    guard !body.contains(";") else { return false }
    let keyword = body.drop { $0 == "(" || $0.isWhitespace }
      .prefix { !$0.isWhitespace && $0 != "(" }
      .lowercased()
    return Constants.singleQueryKeywords.contains(keyword)
  }

  /// The statement without surrounding whitespace and trailing semicolons, ready to wrap.
  static func stripTrailingSemicolons(_ sql: String) -> String {
    sql.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ";")))
  }

  /// What a failed psql run means.
  private func failure(exitCode: Int, stderr: String) -> Failure {
    if exitCode == Constants.notExecutableCode || exitCode == Constants.notFoundCode
      || stderr.contains(Constants.missingExecutableMessage)
    {
      return .psqlMissing
    }
    return stderr.isEmpty ? .psqlExited(code: exitCode) : .psqlError(message: stderr)
  }
}
