import Foundation

// MARK: - Docker

extension JSONEncoder {
  /// Encodes camelCase properties as the Docker API's PascalCase keys.
  static var docker: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .custom { path in
      DockerCodingKey.pascalCased(path.last ?? DockerCodingKey(stringValue: ""))
    }
    return encoder
  }
}
