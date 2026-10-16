import SwiftUI

private enum Constants {
  static let leadingPadding: CGFloat = 16
  static let trailingPadding: CGFloat = 10
}

/// A VM in the menu bar panel: status, name, word and the power buttons that apply now.
struct MenuBarVMRow: View {
  let vm: VirtualMachine
  let store: HangarStore

  var body: some View {
    let status = MachineStatus(vm)
    HStack(spacing: Spacing.xs) {
      StatusSymbol(kind: status.kind)
      Text(vm.name).font(.ui(FontSize.body, weight: .medium)).lineLimit(1)
      Text(status.word)
        .font(.ui(FontSize.subheadline))
        .foregroundStyle(status.kind.wordColor)
        .frame(maxWidth: .infinity, alignment: .leading)
      if store.busy.contains(vm.id) || vm.isTransitioning {
        ProgressView().controlSize(.small)
      } else {
        if !vm.isRunning {
          MenuBarIconButton(
            vm.isPaused ? "Resume \(vm.name)" : "Start \(vm.name)",
            systemImage: "play.fill"
          ) { store.startVM(vm) }
        }
        if vm.isRunning {
          MenuBarIconButton("Suspend \(vm.name)", systemImage: "pause.fill") {
            store.suspendVM(vm)
          }
        }
        if !vm.isStopped {
          MenuBarIconButton("Shut down \(vm.name)", systemImage: "power") { store.stopVM(vm) }
        }
      }
    }
    .frame(height: Dimension.row)
    .padding(.leading, Constants.leadingPadding)
    .padding(.trailing, Constants.trailingPadding)
    .contentShape(Rectangle())
    .contextMenu {
      if vm.isRunning {
        Button("Copy IP Address") { store.copyIP(vm) }
        Divider()
      }
      ProfileMembershipMenu(
        store: store,
        contains: { $0.vmIDs.contains(vm.id) },
        toggle: { store.toggle(vm, in: $0) }
      )
    }
  }
}
