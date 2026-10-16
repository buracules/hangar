import Foundation
import Testing

@testable import Hangar

struct ChildProcessTests {
  private let folder = FileManager.default.temporaryDirectory

  @Test func outputArrivesTaggedByStreamAndTheExitCodeIsReported() async throws {
    let process = try ChildProcess(
      command: "echo out; echo err >&2; exit 3",
      directory: folder,
      environment: ProcessInfo.processInfo.environment
    )
    var out = ""
    var err = ""
    for await (isStderr, data) in process.output() {
      let text = String(bytes: data, encoding: .utf8) ?? ""
      if isStderr { err += text } else { out += text }
    }
    #expect(await process.waitForExit() == 3)
    #expect(out.contains("out"))
    #expect(err.contains("err"))
  }

  @Test func signallingTheGroupStopsChildrenToo() async throws {
    let process = try ChildProcess(
      command: "sleep 30 & wait",
      directory: folder,
      environment: ProcessInfo.processInfo.environment
    )
    process.signal(SIGTERM)
    // 128 + SIGTERM: the shell died of the signal instead of waiting 30 s for its child.
    #expect(await process.waitForExit() == 128 + SIGTERM)
  }

  @Test func thePortVariableReachesTheCommand() async throws {
    var environment = ProcessInfo.processInfo.environment
    environment["PORT"] = "4321"
    let process = try ChildProcess(
      command: "echo $PORT",
      directory: folder,
      environment: environment
    )
    var out = ""
    for await (_, data) in process.output() { out += String(bytes: data, encoding: .utf8) ?? "" }
    _ = await process.waitForExit()
    #expect(out.contains("4321"))
  }
}
