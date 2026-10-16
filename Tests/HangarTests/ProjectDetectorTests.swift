import Foundation
import Testing

@testable import Hangar

struct ProjectDetectorTests {
  /// A fresh folder with the given files, as a project.
  private func project(_ files: [String: String]) throws -> Project {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("HangarTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (name, contents) in files {
      try contents.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    return Project(path: folder.path)
  }

  @Test func nextAppsRunTheirDevScriptWithTheLockfilesManager() throws {
    let spec = ProjectDetector.spec(
      for: try project([
        "package.json": #"{"scripts":{"dev":"next dev"},"dependencies":{"next":"15"}}"#,
        "pnpm-lock.yaml": "",
      ])
    )
    #expect(spec.kind == "Next.js")
    #expect(spec.launchCommand(port: 3001) == "pnpm run dev")
    #expect(spec.port == 3000)
    #expect(spec.source == .detected)
  }

  @Test func viteGetsThePortAsAFlagBecauseItIgnoresPORT() throws {
    let spec = ProjectDetector.spec(
      for: try project([
        "package.json": #"{"scripts":{"dev":"vite"},"devDependencies":{"vite":"6"}}"#
      ])
    )
    #expect(spec.launchCommand(port: 5174) == "npm run dev -- --strictPort --port 5174")
  }

  @Test func djangoTakesThePortAsAnArgument() throws {
    let spec = ProjectDetector.spec(for: try project(["manage.py": ""]))
    #expect(spec.kind == "Django")
    #expect(spec.launchCommand(port: 8001) == "python3 manage.py runserver 8001")
  }

  @Test func fastAPIIsFoundFromItsDependencies() throws {
    let spec = ProjectDetector.spec(
      for: try project(["main.py": "", "requirements.txt": "fastapi\nuvicorn\n"])
    )
    #expect(spec.launchCommand(port: 8000) == "uvicorn main:app --reload --port 8000")
  }

  @Test func theConfigWinsAndItsCommandRunsAsWritten() throws {
    let spec = ProjectDetector.spec(
      for: try project([
        "package.json": #"{"scripts":{"dev":"vite"},"devDependencies":{"vite":"6"}}"#,
        ".hangar.json": #"{"name":"Canvas","command":"node --watch server.js","port":4301}"#,
      ])
    )
    #expect(spec.name == "Canvas")
    #expect(spec.source == .config)
    #expect(spec.launchCommand(port: 4301) == "node --watch server.js")
    #expect(spec.isPortFixed)
  }

  @Test func anUnknownFolderNeedsConfig() throws {
    let spec = ProjectDetector.spec(for: try project(["README.md": "hi"]))
    #expect(spec.source == .none)
    #expect(spec.command == nil)
  }
}
