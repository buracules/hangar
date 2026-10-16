import Foundation

private enum Constants {
  static let executablePath = "/Applications/UTM.app/Contents/MacOS/utmctl"
  /// `utmctl list` prints "UUID  Status  Name"; the name may contain spaces.
  static let listFieldCount = 3
  static let successStatus: Int32 = 0
}

/// Wraps the `utmctl` CLI bundled inside UTM.app. utmctl drives UTM over Apple Events,
/// so calling it launches UTM if it is not already running — callers check first.
struct UTMControl: Sendable {
  static let bundleIdentifier = "com.utmapp.UTM"
  let path: String

  /// The bundled utmctl, if UTM is installed.
  static func detect() -> UTMControl? {
    let path = Constants.executablePath
    return FileManager.default.isExecutableFile(atPath: path) ? UTMControl(path: path) : nil
  }

  /// Every registered VM with its current status.
  func list() async throws -> [VirtualMachine] {
    let output = try await run(["list"])
    return output.split(separator: "\n").dropFirst()
      .compactMap { line in
        let fields = line.split(
          separator: " ",
          maxSplits: Constants.listFieldCount - 1,
          omittingEmptySubsequences: true
        )
        guard fields.count == Constants.listFieldCount else { return nil }
        return VirtualMachine(
          id: String(fields[0]),
          name: fields[2].trimmingCharacters(in: .whitespaces),
          status: String(fields[1])
        )
      }
  }

  /// Starts or resumes a VM without bringing up UTM's main window.
  func start(_ id: String) async throws {
    _ = try await run(["start", "--hide", id])
  }

  /// By default asks the guest OS to shut down; `force` cuts the power instead, which is
  /// utmctl's own default.
  func stop(_ id: String, force: Bool = false) async throws {
    _ = try await run(["stop", id, force ? "--force" : "--request"])
  }

  func suspend(_ id: String) async throws {
    _ = try await run(["suspend", id])
  }

  /// The guest's addresses; needs the QEMU guest agent running inside the VM.
  func ipAddresses(_ id: String) async throws -> [String] {
    try await run(["ip-address", id])
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Runs utmctl off the main actor and returns what it printed.
  private func run(_ arguments: [String]) async throws -> String {
    let path = path
    return
      try await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(bytes: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == Constants.successStatus else {
          throw Failure.commandFailed(
            command: arguments.first ?? "",
            output: output.trimmingCharacters(in: .whitespacesAndNewlines)
          )
        }
        return output
      }
      .value
  }
}
