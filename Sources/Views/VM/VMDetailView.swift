import SwiftUI

private enum Constants {
  static let icon = "desktopcomputer"
  static let dividerHeight: CGFloat = 20
  static let utmHidden = "UTM running hidden"
  static let utmClosed = "UTM closed"
}

/// A VM: header with its power actions, the info grid, then what has happened to it.
struct VMDetailView: View {
  let vm: VirtualMachine
  let store: HangarStore

  @State private var isConfirmingForceStop = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      DetailHeader(
        systemImage: Constants.icon,
        name: vm.name,
        status: MachineStatus(vm),
        facts: facts
      ) {
        actions
      }
      VMInfoGrid(vm: vm, store: store)
      Divider()
      ActivityTimeline(events: store.activity.events(for: vm.id))
    }
    .confirmationDialog(
      "Force stop \(vm.name)?",
      isPresented: $isConfirmingForceStop
    ) {
      Button("Force Stop", role: .destructive) { store.stopVM(vm, force: true) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "The VM powers off immediately, like pulling the plug. Unsaved work in the guest is lost."
      )
    }
  }

  /// "Up 3 h 12 min" while running, when Hangar saw it start, then whether UTM is open.
  private var facts: [DetailFact] {
    var facts: [DetailFact] = []
    if vm.isRunning,
      let started = store.activity.events(for: vm.id).first(where: { $0.outcome == .running })
    {
      facts.append(.text(ActivityTime.uptime(since: started.date)))
    }
    facts.append(.text(store.isUTMRunning ? Constants.utmHidden : Constants.utmClosed))
    return facts
  }

  @ViewBuilder
  private var actions: some View {
    let isBusy = store.busy.contains(vm.id) || vm.isTransitioning
    if isBusy { ProgressView().controlSize(.small) }
    Button(vm.isPaused ? "Resume" : "Start", systemImage: "play.fill") { store.startVM(vm) }
      .disabled(isBusy || vm.isRunning)
    Button("Suspend", systemImage: "pause") { store.suspendVM(vm) }
      .disabled(isBusy || !vm.isRunning)
    Button("Shut Down", systemImage: "power") { store.stopVM(vm) }
      .disabled(isBusy || !vm.isRunning)
    Divider().frame(height: Constants.dividerHeight).padding(.horizontal, Spacing.xxs)
    Button("Force Stop…", systemImage: "exclamationmark.triangle") {
      isConfirmingForceStop = true
    }
    .foregroundStyle(Color.statusError)
    .disabled(vm.isStopped)
  }
}
