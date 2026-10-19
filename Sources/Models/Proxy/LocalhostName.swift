import Foundation

private enum Constants {
  static let suffix = ".localhost"
  static let fallbackSlug = "project"
  static let schemeSeparator = "://"
}

/// `<name>.localhost` hostnames: browsers and macOS resolve every one of them to this Mac,
/// so the proxy can give each project a stable address without touching DNS or /etc/hosts.
enum LocalhostName {
  /// The default hostname for a project: "Portal Web" → `portal-web.localhost`.
  static func defaultHost(for name: String) -> String {
    slug(name) + Constants.suffix
  }

  /// A configured `hostname`, cleaned up: scheme, path and port dropped, lowercased, and
  /// `.localhost` added to a bare name. Nil when nothing usable is left.
  static func normalize(_ raw: String) -> String? {
    var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let range = host.range(of: Constants.schemeSeparator) {
      host = String(host[range.upperBound...])
    }
    host = String(host.prefix { $0 != "/" && $0 != ":" })
    host = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    guard !host.isEmpty, host.allSatisfy(isHostCharacter) else { return nil }
    return host.contains(".") ? host : host + Constants.suffix
  }

  /// Whether a request's host is one the proxy serves.
  static func isLocalhost(_ host: String) -> Bool {
    host.hasSuffix(Constants.suffix)
  }

  /// Lowercase ASCII letters and digits, with every other run turned into one dash.
  static func slug(_ name: String) -> String {
    var slug = ""
    for scalar in name.lowercased().unicodeScalars {
      if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
        slug.unicodeScalars.append(scalar)
      } else if !slug.isEmpty, slug.last != "-" {
        slug.append("-")
      }
    }
    while slug.hasSuffix("-") { slug.removeLast() }
    return slug.isEmpty ? Constants.fallbackSlug : slug
  }

  private static func isHostCharacter(_ character: Character) -> Bool {
    character.isASCII
      && (character.isLetter || character.isNumber || character == "-" || character == ".")
  }
}
