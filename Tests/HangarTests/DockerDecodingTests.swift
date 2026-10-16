import Foundation
import Testing

@testable import Hangar

struct DockerDecodingTests {
  @Test func aContainerDecodesFromDockersPascalCase() throws {
    let json = #"""
      [{"Id":"d3b0f90df3c4752d48ed","Names":["/hermes-postgres"],"Image":"postgres:17",
        "State":"running","Status":"Up 2 hours",
        "Labels":{"com.docker.compose.project":"hermes","com.docker.compose.service":"db"},
        "Ports":[{"IP":"127.0.0.1","PrivatePort":5432,"PublicPort":5433,"Type":"tcp"},
                 {"IP":"::1","PrivatePort":5432,"PublicPort":5433,"Type":"tcp"}]}]
      """#

    let container = try #require(
      try JSONDecoder.docker.decode([Container].self, from: Data(json.utf8)).first
    )

    #expect(container.name == "hermes-postgres")
    #expect(container.shortID == "d3b0f90df3c4")
    #expect(container.composeProject == "hermes")
    #expect(container.displayName == "db")
    #expect(container.isRunning)
    #expect(container.publishedPorts == [5433])
  }

  @Test func aContainerWithoutPortsDecodes() throws {
    let json = #"""
      [{"Id":"abc","Names":["/x"],"Image":"alpine","State":"exited","Status":"Exited",
        "Labels":{},"Ports":null}]
      """#

    let container = try #require(
      try JSONDecoder.docker.decode([Container].self, from: Data(json.utf8)).first
    )

    #expect(container.publishedPorts.isEmpty)
    #expect(!container.isRunning)
  }

  @Test func framesSplitIntoStdoutAndStderr() {
    let stream =
      Fixtures.frame(DockerFrame.stdout, "out") + Fixtures.frame(DockerFrame.stderr, "err")

    let (stdout, stderr) = DockerFrame.demultiplex(stream)

    #expect(String(bytes: stdout, encoding: .utf8) == "out")
    #expect(String(bytes: stderr, encoding: .utf8) == "err")
    #expect(DockerFrame.looksFramed(stream))
    #expect(!DockerFrame.looksFramed(Fixtures.raw("plain text output")))
  }

  @Test func requestBodiesEncodeInPascalCase() throws {
    struct Body: Encodable {
      let attachStdout: Bool
      let cmd: [String]
    }

    let data = try JSONEncoder.docker.encode(Body(attachStdout: true, cmd: ["psql"]))
    let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys

    #expect(Set(keys) == ["AttachStdout", "Cmd"])
  }
}
