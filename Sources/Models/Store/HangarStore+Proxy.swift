import Foundation

private enum Constants {
  static let scheme = "http://"
  static let defaultHTTPPort: UInt16 = 80
}

// MARK: - Proxy

extension HangarStore {
  /// Starts the `*.localhost` proxy on the first free candidate port.
  func startProxy() {
    proxy.start { [weak self] port in
      Task { @MainActor in
        self?.proxyPort = port
        self?.updateRoutes()
      }
    }
  }

  /// Rebuilds the host → port table from the running projects. A name goes to the first
  /// project in the list that wants it; later ones keep their plain localhost URL.
  func updateRoutes() {
    var table: [String: Int] = [:]
    var owners: [String: String] = [:]
    var hosts: [UUID: String] = [:]
    var notes: [UUID: String] = [:]
    for project in projects {
      guard let run = projectRuns[project.id], run.isActive, let port = run.port else { continue }
      let spec = spec(for: project)
      if let owner = owners[spec.hostname] {
        notes[project.id] = "\(spec.hostname) is served by \(owner)"
      } else {
        table[spec.hostname] = port
        owners[spec.hostname] = spec.name
        hosts[project.id] = spec.hostname
      }
    }
    proxy.setRoutes(table)
    if hosts != proxiedHosts { proxiedHosts = hosts }
    if notes != routeNotes { routeNotes = notes }
  }

  /// Where to open a running project: `http://<name>.localhost` through the proxy when it
  /// serves the project, `http://localhost:<port>` otherwise.
  func browserURL(for project: Project, openPath: String) -> URL? {
    if let proxyPort, let host = proxiedHosts[project.id] {
      let port = proxyPort == Constants.defaultHTTPPort ? "" : ":\(proxyPort)"
      return URL(string: Constants.scheme + host + port + openPath)
    }
    return projectRuns[project.id]?.url(openPath: openPath)
  }
}
