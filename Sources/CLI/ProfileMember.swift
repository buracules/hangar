import Foundation

/// A machine that can belong to a profile.
enum ProfileMember {
  case vm(VirtualMachine)
  case container(Container)

  /// How the CLI names it back to the user.
  var label: String {
    switch self {
    case .vm(let vm): "VM \(vm.name)"
    case .container(let container): "container \(container.name)"
    }
  }
}
