import Foundation

private enum Constants {
  static let executablePath = "/Applications/UTM.app/Contents/MacOS/utmctl"
  /// `utmctl list` prints "UUID  Status  Name"; the name may contain spaces.
  static let listFieldCount = 3
  static let successStatus: Int32 = 0
  /// errAEEventNotPermitted: macOS refused to let Hangar send Apple Events to UTM.
  static let eventNotPermitted = "-1743"
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
    Self.parseList(try await run(["list"]))
  }

  /// Rows of `utmctl list` output. Only lines starting with a UUID are VMs, so a header or
  /// a stray message is never mistaken for one.
  static func parseList(_ output: String) -> [VirtualMachine] {
    output.split(separator: "\n")
      .compactMap { line in
        let fields = line.split(
          separator: " ",
          maxSplits: Constants.listFieldCount - 1,
          omittingEmptySubsequences: true
        )
        guard fields.count == Constants.listFieldCount, UUID(uuidString: String(fields[0])) != nil
        else { return nil }
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

  /// Runs utmctl off the main actor and returns what it printed on stdout. Anything on
  /// stderr is an error, even when utmctl exits with 0.
  private func run(_ arguments: [String]) async throws -> String {
    let path = path
    return
      try await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let outPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errorPipe
        try process.run()
        // Read stderr concurrently so a full pipe cannot stall utmctl.
        async let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errors = String(bytes: await errorData, encoding: .utf8) ?? ""
        process.waitUntilExit()
        let message = errors.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains(Constants.eventNotPermitted) { throw Failure.automationDenied }
        guard process.terminationStatus == Constants.successStatus, message.isEmpty else {
          throw Failure.commandFailed(command: arguments.first ?? "", output: message)
        }
        return String(bytes: data, encoding: .utf8) ?? ""
      }
      .value
  }
}
