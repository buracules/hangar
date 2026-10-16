import Foundation

// MARK: - Docker

extension JSONDecoder {
  /// Decodes Docker API responses into camelCase properties. The key strategy also applies
  /// to dictionary keys (labels): only a leading capital is lowered, so `com.docker.*` keys
  /// pass through unchanged.
  static var docker: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .custom { path in
      DockerCodingKey.camelCased(path.last ?? DockerCodingKey(stringValue: ""))
    }
    return decoder
  }
}
