import Foundation

private enum Constants {
  static let vmPrefix = "vm:"
  static let containerPrefix = "container:"
}

/// A profile member as typed on the command line: a name, id or UUID, optionally prefixed
/// `vm:` or `container:` when a name could mean either.
struct MemberKey: Equatable {
  /// Which kind of machine a prefix asked for.
  enum Kind: Equatable {
    case vm
    case container
  }

  /// nil when no prefix was given: VMs are tried first, then containers.
  let kind: Kind?
  let name: String

  init(_ text: String) {
    if text.hasPrefix(Constants.vmPrefix) {
      kind = .vm
      name = String(text.dropFirst(Constants.vmPrefix.count))
    } else if text.hasPrefix(Constants.containerPrefix) {
      kind = .container
      name = String(text.dropFirst(Constants.containerPrefix.count))
    } else {
      kind = nil
      name = text
    }
  }
}
