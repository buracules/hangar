import Foundation

private enum Constants {
  static let nameWidth = 20
  static let kindWidth = 10
  static let stateWidth = 9
  static let containerNameWidth = 28
  static let imageWidth = 24
  static let maxColumnWidth = 40
  static let indent = "  "
  static let columnGap = "  "
  static let none = "  (none)"
  static let null = "NULL"
  static let newlineMark = "↵"
  static let ellipsis = "…"
  static let ruleCharacter = "─"
  static let errorPrefix = "hangar: "
}

/// Plain-text tables for the CLI.
@MainActor
enum CLIPrinter {
  static func status(_ store: HangarStore) {
    profiles(store)
    print("")
    vms(store)
    print("")
    containers(store)
  }

  static func profiles(_ store: HangarStore) {
    print("PROFILES")
    if store.profiles.isEmpty { print(Constants.none) }
    for profile in store.profiles {
      let members = store.members(of: profile)
      let names = (members.vms.map(\.name) + members.containers.map(\.name))
        .joined(separator: ", ")
      let up = "\(members.runningCount)/\(members.total) up"
      print(row([pad(profile.name, Constants.nameWidth), pad(up, Constants.stateWidth), names]))
    }
  }

  /// One profile and its members, each with its current state.
  static func profile(_ profile: Profile, _ store: HangarStore) {
    let profile = store.current(profile) ?? profile
    let members = store.members(of: profile)
    print("\(profile.name)  \(members.runningCount)/\(members.total) up")
    if members.total == 0 && members.missing == 0 { print(Constants.none) }
    for vm in members.vms {
      print(row([pad("vm", Constants.kindWidth), pad(vm.name, Constants.nameWidth), vm.status]))
    }
    for container in members.containers {
      let name = pad(container.name, Constants.containerNameWidth)
      print(row([pad("container", Constants.kindWidth), name, container.state]))
    }
    let missing =
      profile.vmIDs.filter { id in !members.vms.contains { $0.id == id } }
      + profile.containerNames.filter { name in !members.containers.contains { $0.name == name } }
    for key in missing {
      print(row([pad("missing", Constants.kindWidth), key]))
    }
  }

  static func vms(_ store: HangarStore) {
    print("VMS" + (store.isUTMRunning ? "" : " (UTM closed)"))
    if case .missing = store.utmState {
      print(Constants.indent + "UTM is not installed")
      return
    }
    if store.vms.isEmpty { print(Constants.none) }
    for vm in store.vms {
      print(row([pad(vm.name, Constants.nameWidth), pad(vm.status, Constants.stateWidth), vm.id]))
    }
  }

  static func containers(_ store: HangarStore) {
    print("CONTAINERS")
    switch store.dockerState {
    case .offline(let reason):
      print(Constants.indent + reason)
      return
    case .missing:
      print(Constants.indent + "No Docker socket found")
      return
    case .loading, .ready:
      break
    }
    if store.containers.isEmpty { print(Constants.none) }
    let sorted = store.containers.sorted {
      ($0.composeProject ?? "", $0.name) < ($1.composeProject ?? "", $1.name)
    }
    for container in sorted {
      let ports =
        container.isRunning
        ? container.publishedPorts.map { ":\($0)" }.joined(separator: " ") : ""
      print(
        row([
          pad(container.name, Constants.containerNameWidth),
          pad(container.state, Constants.stateWidth),
          pad(container.image, Constants.imageWidth),
          ports,
        ])
      )
    }
  }

  /// A query result as an aligned table, long values cut with an ellipsis.
  static func result(_ result: QueryResult) {
    result.messages.forEach { print($0) }
    guard !result.columns.isEmpty else { return }
    let cells = result.rows.map { row in
      row.map { ($0 ?? Constants.null).replacingOccurrences(of: "\n", with: Constants.newlineMark) }
    }
    let widths = result.columns.indices.map { index in
      let longest = cells.map { $0.indices.contains(index) ? $0[index].count : 0 }.max() ?? 0
      return min(Constants.maxColumnWidth, max(result.columns[index].count, longest))
    }
    print(line(result.columns, widths: widths))
    print(
      widths.map { String(repeating: Constants.ruleCharacter, count: $0) }
        .joined(separator: Constants.columnGap)
    )
    cells.forEach { print(line($0, widths: widths)) }
    let count = result.rows.count
    let more = result.isTruncated ? ", more not shown" : ""
    print("(\(count) row\(count == 1 ? "" : "s")\(more))")
  }

  /// An error on stderr, prefixed with the command name.
  static func error(_ message: String) {
    FileHandle.standardError.write(Data((Constants.errorPrefix + message + "\n").utf8))
  }

  private static func row(_ fields: [String]) -> String {
    Constants.indent + fields.joined(separator: " ")
  }

  private static func line(_ values: [String], widths: [Int]) -> String {
    values.indices
      .map { index in
        let width = widths.indices.contains(index) ? widths[index] : values[index].count
        let value = values[index]
        let cut = value.count > width ? String(value.prefix(width - 1)) + Constants.ellipsis : value
        return pad(cut, width)
      }
      .joined(separator: Constants.columnGap)
  }

  private static func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
  }
}
