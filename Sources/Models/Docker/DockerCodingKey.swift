import Foundation

/// A coding key with its first letter's case changed, to bridge the Docker API's PascalCase
/// keys (`Id`, `ExitCode`) and Swift's camelCase property names.
struct DockerCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }

  /// `Id` → `id`, for decoding.
  static func camelCased(_ key: CodingKey) -> CodingKey {
    let name = key.stringValue
    return DockerCodingKey(stringValue: name.prefix(1).lowercased() + name.dropFirst())
  }

  /// `exitCode` → `ExitCode`, for encoding.
  static func pascalCased(_ key: CodingKey) -> CodingKey {
    let name = key.stringValue
    return DockerCodingKey(stringValue: name.prefix(1).uppercased() + name.dropFirst())
  }
}
