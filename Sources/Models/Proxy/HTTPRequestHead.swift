import Foundation

private enum Constants {
  static let headTerminator = Data("\r\n\r\n".utf8)
  static let hostHeader = "host:"
}

/// The start of an HTTP/1.x request, as far as the proxy needs it: where the head ends and
/// which host it is for.
enum HTTPRequestHead {
  /// Whether `data` holds the complete head (request line and headers).
  static func isComplete(_ data: Data) -> Bool {
    data.range(of: Constants.headTerminator) != nil
  }

  /// The `Host` header, without its port and lowercased; nil if the head has none.
  static func host(in data: Data) -> String? {
    guard let end = data.range(of: Constants.headTerminator),
      let head = String(bytes: data[..<end.lowerBound], encoding: .utf8)
    else { return nil }
    let lines = head.split(separator: "\r\n").dropFirst()
    guard let line = lines.first(where: { $0.lowercased().hasPrefix(Constants.hostHeader) })
    else { return nil }
    let value = line.dropFirst(Constants.hostHeader.count).trimmingCharacters(in: .whitespaces)
    let host = value.hasPrefix("[") ? value : String(value.prefix { $0 != ":" })
    return host.isEmpty ? nil : host.lowercased()
  }
}
