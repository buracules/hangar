import AppKit
import Foundation

private enum Constants {
  /// How often a restart checks whether the old process is gone.
  static let restartPollMilliseconds = 100
}

// MARK: - Projects

extension HangarStore {
  /// How the project runs now — re-read each time, so `.hangar.json` edits apply.
  func spec(for project: Project) -> ProjectSpec { ProjectDetector.spec(for: project) }

  /// The project's run, made on first use and wired to the activity log.
  func run(for project: Project) -> ProjectRun {
    if let run = projectRuns[project.id] { return run }
    let run = ProjectRun()
    let id = project.id.uuidString
    run.record = { [activity] outcome, title, cause, detail in
      activity.record(id, outcome: outcome, title: title, cause: cause, detail: detail)
    }
    run.onChange = { [weak self] in self?.updateRoutes() }
    run.browserURL = { [weak self] openPath in self?.browserURL(for: project, openPath: openPath) }
    projectRuns[project.id] = run
    return run
  }

  /// The status the shared language shows for a project.
  func status(of project: Project) -> MachineStatus {
    let run = projectRuns[project.id]
    if run?.isActive != true, spec(for: project).source == .none {
      return MachineStatus(kind: .stopped, word: "Needs config")
    }
    return MachineStatus(run?.state ?? .stopped)
  }

  func startProject(_ project: Project, cause: String? = nil) {
    lastError = nil
    run(for: project).start(project, spec: spec(for: project), cause: cause)
  }

  func stopProject(_ project: Project, cause: String? = nil) {
    projectRuns[project.id]?.stop(cause: cause)
  }

  /// Stops, waits for the exit, then starts again.
  func restartProject(_ project: Project) {
    let run = run(for: project)
    run.stop(cause: nil)
    Task {
      while run.isActive {
        try? await Task.sleep(for: .milliseconds(Constants.restartPollMilliseconds))
      }
      startProject(project)
    }
  }

  /// Adds a folder as a project, or returns the one already pointing at it.
  @discardableResult
  func addProject(at folder: URL) -> Project {
    let path = folder.standardizedFileURL.path
    if let existing = projects.first(where: { $0.path == path }) { return existing }
    let project = Project(path: path)
    projects.append(project)
    return project
  }

  /// Stops the project if it runs, and forgets it. The folder is left alone.
  func removeProject(_ project: Project) {
    projectRuns[project.id]?.stop(cause: nil)
    projectRuns[project.id] = nil
    projects.removeAll { $0.id == project.id }
  }

  /// Asks for a folder and adds it; returns the project, or nil if cancelled.
  func chooseProjectFolder() -> Project? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Add Project"
    panel.message = "Choose a folder with a package.json, a Python app or a .hangar.json."
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return addProject(at: url)
  }

  /// Picks up projects added or removed by the CLI.
  func reloadProjects() {
    let stored = SharedFiles.projects.load() ?? []
    if stored != projects { projects = stored }
  }

  /// Signals every running project — Hangar is quitting and its children go with it.
  func terminateProjects() {
    for run in projectRuns.values where run.isActive { run.terminateNow() }
  }
}
