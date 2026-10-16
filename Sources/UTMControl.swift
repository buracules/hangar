import Foundation

struct VirtualMachine: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    /// utmctl's word: stopped, starting, started, pausing, paused, resuming, stopping.
    let status: String

    var isRunning: Bool { status == "started" }
    var isStopped: Bool { status == "stopped" }
    var isPaused: Bool { status == "paused" }
    var isTransitioning: Bool { ["starting", "pausing", "resuming", "stopping"].contains(status) }
}

enum UTMError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let message): message }
    }
}

/// Wraps the `utmctl` CLI bundled inside UTM.app. utmctl drives UTM over Apple Events,
/// so calling it launches UTM if it is not already running — callers check first.
struct UTMControl: Sendable {
    static let bundleIdentifier = "com.utmapp.UTM"
    let path: String

    static func detect() -> UTMControl? {
        let path = "/Applications/UTM.app/Contents/MacOS/utmctl"
        return FileManager.default.isExecutableFile(atPath: path) ? UTMControl(path: path) : nil
    }

    func list() async throws -> [VirtualMachine] {
        let output = try await run(["list"])
        // "UUID  Status  Name" — the name may contain spaces, so split at most twice.
        return output.split(separator: "\n").dropFirst().compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3 else { return nil }
            return VirtualMachine(
                id: String(fields[0]),
                name: fields[2].trimmingCharacters(in: .whitespaces),
                status: String(fields[1])
            )
        }
    }

    /// VMs in UTM's default library, read straight from their bundles so it works while UTM
    /// is closed. Every VM is stopped then: VMs run inside UTM and die with it. Touching
    /// UTM's container triggers macOS's "access data from other apps" prompt once.
    static func libraryVMs() -> [VirtualMachine] {
        let library = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Documents")
        guard let bundles = try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: nil) else {
            return []
        }
        return bundles.filter { $0.pathExtension == "utm" }.compactMap { bundle in
            guard let data = try? Data(contentsOf: bundle.appendingPathComponent("config.plist")),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let info = plist["Information"] as? [String: Any],
                  let uuid = info["UUID"] as? String
            else { return nil }
            let name = info["Name"] as? String ?? bundle.deletingPathExtension().lastPathComponent
            return VirtualMachine(id: uuid, name: name, status: "stopped")
        }
    }

    func start(_ id: String) async throws { _ = try await run(["start", "--hide", id]) }

    /// By default asks the guest OS to shut down; `force` cuts the power instead, which is
    /// utmctl's own default.
    func stop(_ id: String, force: Bool = false) async throws {
        _ = try await run(["stop", id, force ? "--force" : "--request"])
    }
    func suspend(_ id: String) async throws { _ = try await run(["suspend", id]) }

    /// Needs the QEMU guest agent running inside the VM.
    func ipAddresses(_ id: String) async throws -> [String] {
        try await run(["ip-address", id])
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func run(_ arguments: [String]) async throws -> String {
        let path = path
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            guard process.terminationStatus == 0 else {
                let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
                throw UTMError.failed(message.isEmpty ? "utmctl \(arguments.first ?? "") failed" : message)
            }
            return output
        }.value
    }
}
