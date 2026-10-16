import Foundation

private enum Constants {
  static let folderName = "Hangar"
}

/// A JSON file in Application Support that the menu bar app and the CLI both read and write.
struct SharedFile<Value: Codable>: Sendable {
  let name: String
  /// Where the file lives; Hangar's Application Support folder unless a test points elsewhere.
  var directory = URL.applicationSupportDirectory
    .appendingPathComponent(Constants.folderName, isDirectory: true)

  /// `~/Library/Application Support/Hangar/<name>` by default.
  var url: URL { directory.appendingPathComponent(name) }

  /// The stored value, or nil if the file is missing or unreadable.
  func load() -> Value? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Value.self, from: data)
  }

  /// Writes the value atomically, pretty-printed so it stays hand-editable.
  func save(_ value: Value) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: url, options: .atomic)
  }
}
