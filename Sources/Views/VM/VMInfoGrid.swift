import AppKit
import SwiftUI

private enum Constants {
  static let rowSpacing: CGFloat = 6
  static let copyIcon: CGFloat = 11
  static let chipHeight: CGFloat = 18
  static let chipPadding: CGFloat = 6
  static let guestAgentGuide = "https://docs.getutm.app/guest-support/linux/"
}

/// Name, UUID, IP addresses, backend, resources and profiles, in the design's two-column form.
struct VMInfoGrid: View {
  let vm: VirtualMachine
  let store: HangarStore

  /// Nil until read; stays nil when the bundle is outside UTM's default library.
  @State private var configuration: VMConfiguration?
  /// Nil while loading or while the VM is not running.
  @State private var addresses: Result<[String], Error>?

  var body: some View {
    Grid(
      alignment: .leading,
      horizontalSpacing: Spacing.md,
      verticalSpacing: Constants.rowSpacing
    ) {
      let right = rightColumn
      GridRow {
        InfoKey("Name")
        Text(vm.name).textSelection(.enabled)
        rightCell(right[0])
      }
      GridRow {
        InfoKey("UUID")
        uuidValue
        rightCell(right.count > 1 ? right[1] : nil)
      }
      GridRow {
        InfoKey("IP addresses")
        addressesValue
        rightCell(right.count > 2 ? right[2] : nil)
      }
    }
    .font(.ui(FontSize.body))
    .padding(.horizontal, Spacing.lg)
    .padding(.bottom, Spacing.md)
    .task(id: vm.id) { await loadConfiguration() }
    .task(id: "\(vm.id)|\(vm.status)") { await loadAddresses() }
  }

  /// Backend and resources when the bundle could be read, then profiles — moved up into
  /// any gap so the form never has a hole.
  private var rightColumn: [RightCell] {
    let facts = [
      ("Backend", configuration?.backendText), ("Resources", configuration?.resourcesText),
    ]
    .compactMap { key, value in value.map { RightCell.fact(key, $0) } }
    return facts + [.profiles]
  }

  /// A key and value, or two empty cells so the grid keeps its columns.
  @ViewBuilder
  private func rightCell(_ cell: RightCell?) -> some View {
    switch cell {
    case .fact(let key, let value):
      InfoKey(key)
      Text(value).textSelection(.enabled)
    case .profiles:
      InfoKey("Profiles")
      ProfileChips(
        store: store,
        isMember: { $0.vmIDs.contains(vm.id) },
        add: { store.add(vm, to: $0) },
        remove: { store.removeVM(id: vm.id, from: $0) }
      )
    case nil:
      Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
      Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
    }
  }

  private var uuidValue: some View {
    HStack(spacing: Spacing.xxs) {
      Text(vm.id).font(.mono(FontSize.smallMono)).textSelection(.enabled)
      Button("Copy UUID", systemImage: "doc.on.doc") { copy(vm.id) }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: Constants.copyIcon))
        .foregroundStyle(Color.secondaryLabel)
    }
  }

  @ViewBuilder
  private var addressesValue: some View {
    switch addresses {
    case _ where !vm.isRunning:
      Text(verbatim: "—").foregroundStyle(Color.tertiaryLabel)
    case nil:
      ProgressView().controlSize(.small)
    case .success(let ips) where ips.isEmpty:
      Text("None reported").foregroundStyle(Color.secondaryLabel)
    case .success(let ips):
      HStack(spacing: Spacing.xxs) {
        ForEach(ips, id: \.self) { addressChip($0) }
      }
    case .failure:
      HStack(spacing: Spacing.xs) {
        Text("Needs the QEMU guest agent").foregroundStyle(Color.secondaryLabel)
        if let url = URL(string: Constants.guestAgentGuide) {
          Link("How to install", destination: url)
        }
      }
      .font(.ui(FontSize.callout))
    }
  }

  private func addressChip(_ address: String) -> some View {
    Button {
      copy(address)
    } label: {
      Text(verbatim: address)
        .font(.mono(FontSize.smallMono))
        .foregroundStyle(Color.accentText)
        .padding(.horizontal, Constants.chipPadding)
        .frame(height: Constants.chipHeight)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.xs))
    }
    .buttonStyle(.plain)
    .help("Copy \(address)")
    .accessibilityLabel("Copy \(address)")
  }

  private func loadConfiguration() async {
    let id = vm.id
    configuration = await Task.detached { UTMControl.configuration(forVM: id) }.value
  }

  private func loadAddresses() async {
    addresses = nil
    guard vm.isRunning, let utm = store.utm else { return }
    do {
      addresses = .success(try await utm.ipAddresses(vm.id))
    } catch {
      addresses = .failure(error)
    }
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}

/// One key–value pair in the grid's right column.
private enum RightCell {
  case fact(String, String)
  case profiles
}
