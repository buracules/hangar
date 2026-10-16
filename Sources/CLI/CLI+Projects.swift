import Foundation

private enum Constants {
  /// `project <verb> <path or name>`.
  static let targetIndex = 2
  static let indent = "  "
  static let none = "  (none)"
  static let nameWidth = 20
  static let kindWidth = 9
}

// MARK: - Projects

extension CLI {
  /// `project list|add|remove`. Starting and stopping stay in the app: a project runs as the
  /// app's child process, which a short-lived CLI cannot own.
  static func project(_ args: [String], _ store: HangarStore, json: Bool) throws {
    switch args.dropFirst().first {
    case "list":
      printProjects(store.projects, store, json: json)
    case "add":
      let path = try argument(args, at: Constants.targetIndex, "project add <folder>")
      let folder = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else { throw Failure.usage("not a folder: \(path)") }
      printProjects([store.addProject(at: folder)], store, json: json)
    case "remove":
      let project = try findProject(args, store)
      store.removeProject(project)
      print(json ? CLIJSON.projects([], store) : "removed \(store.spec(for: project).name)")
    default:
      throw Failure.usage(usage)
    }
  }

  /// A project by name, folder name or path, case-insensitively.
  private static func findProject(_ args: [String], _ store: HangarStore) throws -> Project {
    let target = try argument(args, at: Constants.targetIndex, "project remove <name or folder>")
    let path = URL(fileURLWithPath: (target as NSString).expandingTildeInPath).standardizedFileURL
      .path
    let match = store.projects.first { project in
      project.path == path
        || project.folderName.caseInsensitiveCompare(target) == .orderedSame
        || store.spec(for: project).name.caseInsensitiveCompare(target) == .orderedSame
    }
    guard let match else { throw Failure.usage("no project named \(target)") }
    return match
  }

  private static func printProjects(_ projects: [Project], _ store: HangarStore, json: Bool) {
    if json {
      print(CLIJSON.projects(projects, store))
      return
    }
    print("PROJECTS")
    if projects.isEmpty { print(Constants.none) }
    for project in projects {
      let spec = store.spec(for: project)
      let name = spec.name.padding(toLength: Constants.nameWidth, withPad: " ", startingAt: 0)
      let kind = spec.kind.padding(toLength: Constants.kindWidth, withPad: " ", startingAt: 0)
      let command = spec.launchCommand(port: spec.port) ?? "(needs a .hangar.json command)"
      print(Constants.indent + [name, kind, command].joined(separator: " "))
      print(
        Constants.indent + String(repeating: " ", count: Constants.nameWidth + 1) + project.path
      )
    }
  }
}
