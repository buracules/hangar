import Foundation

private enum Constants {
  static let defaultTimeoutSeconds = 120
  /// Reported when Docker does not say how the command ended.
  static let unknownExitCode = -1
  static let startBody = Data(#"{"Detach":false,"Tty":false}"#.utf8)
}

// MARK: - Exec

extension DockerClient {
  /// What a command run inside a container printed, and how it exited.
  struct ExecResult: Sendable {
    let stdout: Data
    let stderr: Data
    let exitCode: Int
  }

  /// Runs a command inside a running container, like `docker exec`, and collects its output.
  func exec(
    _ id: String,
    _ command: [String],
    environment: [String: String] = [:],
    timeoutSeconds: Int = Constants.defaultTimeoutSeconds
  ) async throws -> ExecResult {
    let env = environment.map { "\($0.key)=\($0.value)" }
    let create = try JSONEncoder.docker.encode(ExecCreate(cmd: command, env: env))
    let created = try await request("POST", "/containers/\(id)/exec", body: create)
    let execID = try JSONDecoder.docker.decode(ExecCreated.self, from: created).id
    // Not attaching stdin means the daemon closes the connection when the command exits.
    let output = try await request(
      "POST",
      "/exec/\(execID)/start",
      body: Constants.startBody,
      timeoutSeconds: timeoutSeconds
    )
    let inspect = try await request("GET", "/exec/\(execID)/json")
    let exitCode = try JSONDecoder.docker.decode(ExecInspect.self, from: inspect).exitCode
    let (stdout, stderr) = DockerFrame.demultiplex(output)
    return ExecResult(
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode ?? Constants.unknownExitCode
    )
  }
}

/// The body of `POST /containers/{id}/exec`.
private struct ExecCreate: Encodable {
  var attachStdout = true
  var attachStderr = true
  let cmd: [String]
  let env: [String]
}

/// Its answer.
private struct ExecCreated: Decodable {
  let id: String
}

/// The part of `GET /exec/{id}/json` Hangar reads.
private struct ExecInspect: Decodable {
  let exitCode: Int?
}
