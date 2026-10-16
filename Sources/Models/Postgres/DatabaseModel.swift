import Foundation
import Observation

private enum Constants {
  static let pageSize = 200
  static let sqlRowLimit = 1000
  static let historyLimit = 30
  /// Opened first when a database has it, as most apps keep their tables there.
  static let preferredSchema = "public"
}

/// The Database tab's state for one Postgres container: which database and table are open,
/// the page of rows, the structure, and the SQL editor with its history. Kept per container
/// by the store, so switching tabs or containers does not lose any of it.
@MainActor
@Observable
final class DatabaseModel {
  /// The views over the open table.
  enum Tab: String, CaseIterable, Identifiable {
    case data = "Data"
    case structure = "Structure"
    case sql = "SQL"

    var id: Self { self }
  }

  /// How far connecting has got.
  enum Phase: Equatable {
    case idle
    case connecting
    case ready
    case failed(String)
  }

  static let pageSize = Constants.pageSize

  private(set) var phase = Phase.idle
  private(set) var client: PostgresClient?
  private(set) var psqlVersion: String?
  private(set) var databases: [String] = []
  private(set) var database: String?
  private(set) var tables: [TableInfo] = []
  private(set) var selectedTable: TableInfo?
  var tableFilter = ""
  var tab = Tab.data

  // Data and Structure
  var whereClause = ""
  private(set) var page = 0
  private(set) var rows: QueryResult?
  private(set) var columns: [ColumnInfo] = []
  private(set) var indexes: [IndexInfo] = []
  private(set) var isLoadingRows = false
  private(set) var rowsError: String?
  private(set) var rowsElapsed: Duration?

  // SQL
  var sql = ""
  private(set) var sqlResult: QueryResult?
  private(set) var sqlColumnTypes: [String] = []
  private(set) var sqlError: String?
  private(set) var sqlElapsed: Duration?
  private(set) var isRunningSQL = false
  private(set) var history: [String] = []

  private var containerID: String?
  /// Credentials typed into the sign-in form, used instead of the container's environment.
  private var signIn: (user: String, password: String)?

  /// Tables matching the filter, grouped by schema in catalog order.
  var tablesBySchema: [(schema: String, tables: [TableInfo])] {
    let filter = tableFilter.trimmingCharacters(in: .whitespaces)
    let visible = tables.filter {
      filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter)
    }
    var groups: [(schema: String, tables: [TableInfo])] = []
    for table in visible {
      if groups.last?.schema == table.schema {
        groups[groups.count - 1].tables.append(table)
      } else {
        groups.append((table.schema, [table]))
      }
    }
    return groups
  }

  /// The short type of each column in the current page, for the grid headers.
  var rowColumnTypes: [String] {
    let types = Dictionary(columns.map { ($0.name, $0.shortType) }) { first, _ in first }
    return (rows?.columns ?? []).map { types[$0] ?? "" }
  }

  /// The 1-based range of rows on the current page: "1–200".
  var pageRange: ClosedRange<Int>? {
    guard let count = rows?.rows.count, count > 0 else { return nil }
    let first = page * Constants.pageSize + 1
    return first...(first + count - 1)
  }

  var hasNextPage: Bool { rows?.isTruncated ?? false }
  var hasPreviousPage: Bool { page > 0 }

  // MARK: Connecting

  /// Connects once per container, or again after it was recreated with a new id.
  func connect(to container: Container, docker: DockerClient) async {
    guard containerID != container.id || phase == .idle else { return }
    containerID = container.id
    phase = .connecting
    do {
      let detected = try await PostgresClient.connect(to: container, docker: docker)
      let client =
        signIn.map {
          PostgresClient(
            docker: docker,
            containerID: container.id,
            user: $0.user,
            defaultDatabase: detected.defaultDatabase,
            password: $0.password
          )
        } ?? detected
      self.client = client
      async let version = client.psqlVersion()
      databases = try await client.databases()
      psqlVersion = await version
      phase = .ready
      let previous = database.flatMap { databases.contains($0) ? $0 : nil }
      await selectDatabase(previous ?? client.defaultDatabase)
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  /// Forgets the connection, so the next `connect` starts over.
  func disconnect() {
    containerID = nil
    phase = .idle
  }

  /// Signs in with typed credentials, for the rest of this app session; nil goes back to
  /// the container's own POSTGRES_USER.
  func signIn(user: String?, password: String, container: Container, docker: DockerClient) async {
    signIn = user.map { ($0, password) }
    disconnect()
    await connect(to: container, docker: docker)
  }

  /// The user the connection signs in as.
  var user: String? { client?.user }

  func selectDatabase(_ name: String) async {
    guard let client else { return }
    database = name
    selectedTable = nil
    rows = nil
    columns = []
    indexes = []
    do {
      tables = try await client.tables(in: name)
      let preferred = tables.first { $0.schema == Constants.preferredSchema && !$0.isView }
      if let first = preferred ?? tables.first { await selectTable(first) }
    } catch {
      tables = []
      rowsError = error.localizedDescription
    }
  }

  // MARK: Data and Structure

  func selectTable(_ table: TableInfo) async {
    guard let client, let database else { return }
    selectedTable = table
    whereClause = ""
    page = 0
    async let columns = client.columns(of: table, in: database)
    async let indexes = client.indexes(of: table, in: database)
    self.columns = (try? await columns) ?? []
    self.indexes = (try? await indexes) ?? []
    await loadRows()
  }

  /// Loads the current page, honouring the WHERE clause.
  func loadRows() async {
    guard let client, let database, let table = selectedTable else { return }
    isLoadingRows = true
    defer { isLoadingRows = false }
    let start = ContinuousClock.now
    do {
      rows = try await client.rows(
        of: table,
        in: database,
        where: whereClause,
        limit: Constants.pageSize,
        offset: page * Constants.pageSize
      )
      rowsError = nil
    } catch {
      rows = nil
      rowsError = error.localizedDescription
    }
    rowsElapsed = ContinuousClock.now - start
  }

  func applyWhere() async {
    page = 0
    await loadRows()
  }

  /// "Filter Rows Where column = value".
  func filterRows(column: String, value: String?) async {
    whereClause = SQLBuilder.equals(column: column, value: value)
    await applyWhere()
  }

  func nextPage() async {
    guard hasNextPage else { return }
    page += 1
    await loadRows()
  }

  func previousPage() async {
    guard hasPreviousPage else { return }
    page -= 1
    await loadRows()
  }

  // MARK: SQL

  /// Runs the editor's SQL. A single query is capped and gets column types; anything else
  /// runs as written and shows its last result or messages.
  func runSQL() async {
    let text = sql.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let client, let database, !text.isEmpty, !isRunningSQL else { return }
    isRunningSQL = true
    defer { isRunningSQL = false }
    remember(text)
    let start = ContinuousClock.now
    do {
      if PostgresClient.isSingleQuery(text) {
        let query = PostgresClient.stripTrailingSemicolons(text)
        async let types = client.columnTypes(ofQuery: query, in: database)
        sqlResult = try await client.select(query, database: database, limit: Constants.sqlRowLimit)
        sqlColumnTypes = await types
      } else {
        let results = try await client.run(text, database: database)
        sqlResult = results.last { !$0.columns.isEmpty } ?? mergedMessages(results)
        sqlColumnTypes = []
      }
      sqlError = nil
    } catch {
      sqlResult = nil
      sqlError = error.localizedDescription
    }
    sqlElapsed = ContinuousClock.now - start
  }

  private func remember(_ text: String) {
    history.removeAll { $0 == text }
    history.insert(text, at: 0)
    if history.count > Constants.historyLimit { history.removeLast() }
  }

  private func mergedMessages(_ results: [QueryResult]) -> QueryResult {
    QueryResult(columns: [], rows: [], messages: results.flatMap(\.messages))
  }
}
