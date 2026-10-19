import Foundation

private enum Constants {
  static let configFile = ".hangar.json"
  static let packageFile = "package.json"
  static let defaultOpenPath = "/"

  enum Node {
    static let devScripts = ["dev", "start", "serve"]
    /// Lockfile → package manager, first match wins.
    static let lockfiles: [(file: String, manager: String)] = [
      ("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("bun.lockb", "bun"), ("bun.lock", "bun"),
    ]
    static let fallbackManager = "npm"
    static let nextPort = 3000
    static let vitePort = 5173
    static let nodePort = 3000
  }

  enum Python {
    static let djangoFile = "manage.py"
    static let appFiles = ["main.py", "app.py"]
    static let dependencyFiles = ["requirements.txt", "pyproject.toml"]
    static let djangoPort = 8000
    static let fastAPIPort = 8000
    static let flaskPort = 5000
  }
}

/// Works out how to run a folder: its `.hangar.json` first, then what the files suggest —
/// a package.json script, Django's manage.py, a FastAPI or Flask app.
enum ProjectDetector {
  /// The resolved spec. Never fails: an unrecognised folder gets `source == .none`.
  static func spec(for project: Project) -> ProjectSpec {
    let folder = project.url
    let config = loadConfig(in: folder)
    let detected = detect(in: folder)
    let command = config?.command ?? detected?.command
    return ProjectSpec(
      name: config?.name ?? project.folderName,
      kind: detected?.kind ?? "Custom",
      command: command,
      source: config?.command != nil ? .config : (detected != nil ? .detected : .none),
      port: config?.port ?? detected?.port,
      isPortFixed: config?.port != nil,
      // A hand-written command is used as is.
      portFlag: config?.command == nil ? detected?.portFlag : nil,
      openPath: config?.openPath ?? Constants.defaultOpenPath,
      hostname: config?.hostname.flatMap(LocalhostName.normalize)
        ?? LocalhostName.defaultHost(for: config?.name ?? project.folderName),
      healthCheck: config?.healthCheck,
      autoOpen: config?.autoOpen ?? false,
      restartOnCrash: config?.restartOnCrash ?? false,
      env: config?.env ?? [:]
    )
  }

  /// The folder's `.hangar.json`, or nil if there is none or it does not parse.
  static func loadConfig(in folder: URL) -> ProjectConfig? {
    guard let data = try? Data(contentsOf: folder.appendingPathComponent(Constants.configFile))
    else { return nil }
    return try? JSONDecoder().decode(ProjectConfig.self, from: data)
  }

  /// What detection found: kind, command, default port and how to pass it.
  private struct Detection {
    let kind: String
    let command: String
    let port: Int?
    var portFlag: String?
  }

  private static func detect(in folder: URL) -> Detection? {
    detectNode(in: folder) ?? detectPython(in: folder)
  }

  private static func detectNode(in folder: URL) -> Detection? {
    guard let data = try? Data(contentsOf: folder.appendingPathComponent(Constants.packageFile)),
      let package = try? JSONDecoder().decode(PackageManifest.self, from: data),
      let script = Constants.Node.devScripts.first(where: { package.scripts?[$0] != nil })
    else { return nil }
    let manager =
      Constants.Node.lockfiles.first { exists($0.file, in: folder) }?.manager
      ?? Constants.Node.fallbackManager
    let command = "\(manager) run \(script)"
    let dependencies = package.allDependencies
    // npm needs `--` before arguments meant for the script; the others pass them through.
    let separator = manager == Constants.Node.fallbackManager ? "-- " : ""
    if dependencies.contains("next") {
      return Detection(kind: "Next.js", command: command, port: Constants.Node.nextPort)
    }
    if dependencies.contains("vite") {
      // Vite ignores PORT.
      return Detection(
        kind: "Vite",
        command: command,
        port: Constants.Node.vitePort,
        portFlag: separator + "--strictPort --port"
      )
    }
    return Detection(kind: "Node", command: command, port: Constants.Node.nodePort)
  }

  private static func detectPython(in folder: URL) -> Detection? {
    if exists(Constants.Python.djangoFile, in: folder) {
      // runserver takes the port as an argument.
      return Detection(
        kind: "Django",
        command: "python3 manage.py runserver",
        port: Constants.Python.djangoPort,
        portFlag: ""
      )
    }
    let dependencies = Constants.Python.dependencyFiles
      .compactMap { try? String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
      .joined(separator: "\n")
      .lowercased()
    guard let app = Constants.Python.appFiles.first(where: { exists($0, in: folder) }) else {
      return nil
    }
    let module = (app as NSString).deletingPathExtension
    if dependencies.contains("fastapi") {
      return Detection(
        kind: "FastAPI",
        command: "uvicorn \(module):app --reload",
        port: Constants.Python.fastAPIPort,
        portFlag: "--port"
      )
    }
    if dependencies.contains("flask") {
      return Detection(
        kind: "Flask",
        command: "flask --app \(module) run",
        port: Constants.Python.flaskPort,
        portFlag: "--port"
      )
    }
    return Detection(kind: "Python", command: "python3 \(app)", port: nil)
  }

  private static func exists(_ name: String, in folder: URL) -> Bool {
    FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
  }
}

/// The parts of package.json detection reads.
private struct PackageManifest: Decodable {
  let scripts: [String: String]?
  let dependencies: [String: String]?
  let devDependencies: [String: String]?

  var allDependencies: Set<String> {
    Set((dependencies ?? [:]).keys).union((devDependencies ?? [:]).keys)
  }
}
