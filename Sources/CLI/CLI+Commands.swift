import Foundation

private enum Constants {
  static let logTail = 200
  static let followFlag = "-f"
  static let databaseFlag = "-d"
  static let sqlRowLimit = 1000
  /// `sql <container> <sql…>`: the SQL starts at this argument.
  static let sqlArgumentIndex = 2
}

// MARK: - Commands

extension CLI {
  static func vm(_ action: String, _ vm: VirtualMachine, _ store: HangarStore) async throws {
    guard let action = VMAction(rawValue: action) else { throw Failure.usage(usage) }
    guard let utm = store.utm else { throw UTMControl.Failure.notInstalled }
    switch action {
    case .start: try await store.bootVM(vm)
    case .stop: try await utm.stop(vm.id)
    case .kill: try await utm.stop(vm.id, force: true)
    case .suspend: try await utm.suspend(vm.id)
    case .ip:
      guard store.isUTMRunning else { throw UTMControl.Failure.notRunning }
      print(try await utm.ipAddresses(vm.id).joined(separator: "\n"))
      return
    }
    print("\(action.rawValue) \(vm.name)")
  }

  static func container(
    _ action: String,
    _ container: Container,
    _ store: HangarStore
  ) async throws {
    guard let action = ContainerAction(rawValue: action) else { throw Failure.usage(usage) }
    let docker = try requireDocker(store)
    switch action {
    case .start: try await docker.start(container.id)
    case .stop: try await docker.stop(container.id)
    case .restart: try await docker.restart(container.id)
    }
    print("\(action.rawValue) \(container.name)")
  }

  /// `logs [-f] <container>`: prints the tail, and keeps printing with `-f`.
  static func logs(_ args: [String], _ store: HangarStore) async throws {
    let follow = args.contains(Constants.followFlag)
    let container = try findContainer(args.filter { $0 != Constants.followFlag }, store)
    let docker = try requireDocker(store)
    var decoder = LogDecoder()
    for try await chunk in docker.logs(container.id, tail: Constants.logTail, follow: follow) {
      for line in decoder.feed(chunk) { print(line.text) }
      fflush(stdout)
    }
  }

  /// `sql <container> [-d db] <sql>`: a single query is wrapped and capped; anything else
  /// runs as-is.
  static func sql(_ args: [String], _ store: HangarStore) async throws {
    guard args.count > Constants.sqlArgumentIndex else {
      throw Failure.usage("usage: hangar sql <container> [-d db] <sql>")
    }
    let container = try findContainer(Array(args.prefix(Constants.sqlArgumentIndex)), store)
    var rest = Array(args.dropFirst(Constants.sqlArgumentIndex))
    var database: String?
    if rest.first == Constants.databaseFlag, rest.count > Constants.sqlArgumentIndex {
      database = rest[1]
      rest = Array(rest.dropFirst(Constants.sqlArgumentIndex))
    }
    let sql = rest.joined(separator: " ")
    let client = try await PostgresClient.connect(to: container, docker: try requireDocker(store))
    let results =
      PostgresClient.isSingleQuery(sql)
      ? [
        try await client.select(
          PostgresClient.stripTrailingSemicolons(sql),
          database: database,
          limit: Constants.sqlRowLimit
        )
      ]
      : try await client.run(sql, database: database)
    for (index, result) in results.enumerated() {
      if index > 0 { print("") }
      CLIPrinter.result(result)
    }
  }

  private static func requireDocker(_ store: HangarStore) throws -> DockerClient {
    guard let docker = store.docker else { throw HangarStore.Failure.dockerMissing }
    return docker
  }
}
