import Foundation

/// A named set of VMs and containers started and stopped together.
struct Profile: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    /// UTM VM UUIDs.
    var vmIDs: [String]
    /// Container names rather than ids: `docker compose up` recreates containers with new
    /// ids but the same name.
    var containerNames: [String]
}

/// A VM as last reported by UTM, so it can be listed while UTM is closed.
struct KnownVM: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

/// State shared by the menu bar app and the CLI, kept as JSON in Application Support.
/// Not UserDefaults: the CLI runs through a symlink, outside the app bundle, and would get
/// a different defaults domain. Profiles are also meant to be hand-editable.
enum Shared {
    static let profiles = SharedFile<[Profile]>(name: "profiles.json")
    static let knownVMs = SharedFile<[KnownVM]>(name: "known-vms.json")
}

struct SharedFile<Value: Codable>: Sendable {
    let name: String

    var url: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Hangar", isDirectory: true)
            .appendingPathComponent(name)
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
