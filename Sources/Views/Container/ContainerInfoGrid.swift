import AppKit
import SwiftUI

private enum Constants {
  static let rowSpacing: CGFloat = 6
  static let copyIcon: CGFloat = 11
  static let separator = "·"
  static let mappingArrow = "→"
}

/// Name, image, ID, compose project, ports and profiles, in the design's two-column form.
struct ContainerInfoGrid: View {
  let container: Container
  let store: HangarStore

  var body: some View {
    Grid(
      alignment: .leading,
      horizontalSpacing: Spacing.md,
      verticalSpacing: Constants.rowSpacing
    ) {
      GridRow {
        InfoKey("Name")
        Text(container.name).textSelection(.enabled)
        InfoKey("Image")
        Text(container.image).font(.mono()).textSelection(.enabled)
      }
      GridRow {
        InfoKey("ID")
        idValue
        InfoKey("Compose")
        composeValue
      }
      GridRow {
        InfoKey("Ports")
        portsValue
        InfoKey("Profiles")
        ProfileChips(
          store: store,
          isMember: { $0.containerNames.contains(container.name) },
          add: { store.add(container, to: $0) },
          remove: { store.removeContainer(named: container.name, from: $0) }
        )
      }
    }
    .font(.ui(FontSize.body))
    .padding(.horizontal, Spacing.lg)
    .padding(.bottom, Spacing.md)
  }

  private var idValue: some View {
    HStack(spacing: Spacing.xxs) {
      Text(container.shortID).font(.mono()).textSelection(.enabled)
      Button("Copy container ID", systemImage: "doc.on.doc") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(container.id, forType: .string)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .font(.system(size: Constants.copyIcon))
      .foregroundStyle(Color.secondaryLabel)
    }
  }

  @ViewBuilder
  private var composeValue: some View {
    if let project = container.composeProject {
      HStack(spacing: Spacing.xxs) {
        Text(project)
        if let service = container.composeService {
          Text(Constants.separator).foregroundStyle(Color.tertiaryLabel)
          Text(service)
        }
      }
    } else {
      Text(verbatim: "—").foregroundStyle(Color.tertiaryLabel)
    }
  }

  @ViewBuilder
  private var portsValue: some View {
    let mappings = portMappings
    if mappings.isEmpty {
      Text(verbatim: "—").foregroundStyle(Color.tertiaryLabel)
    } else {
      HStack(spacing: Spacing.xs) {
        ForEach(mappings, id: \.self) { mapping in
          let published = mapping.publicPort ?? 0
          HStack(spacing: Spacing.xxs) {
            PortChip(port: published) { store.openPort(published) }
              .disabled(!container.isRunning)
            Text(verbatim: "\(Constants.mappingArrow) \(mapping.privatePort)/\(mapping.type)")
              .font(.mono(FontSize.smallMono))
              .foregroundStyle(Color.secondaryLabel)
          }
        }
      }
    }
  }

  /// Published ports, one per host port (Docker lists IPv4 and IPv6 separately).
  private var portMappings: [ContainerPort] {
    var seen: Set<Int> = []
    return (container.ports ?? [])
      .filter { port in port.publicPort.map { seen.insert($0).inserted } ?? false }
      .sorted { ($0.publicPort ?? 0) < ($1.publicPort ?? 0) }
  }
}
