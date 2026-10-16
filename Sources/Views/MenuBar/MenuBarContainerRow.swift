import SwiftUI

private enum Constants {
  static let leadingPadding: CGFloat = 36
  static let trailingPadding: CGFloat = 12
  static let verticalPadding: CGFloat = 2
  static let detailLineHeight: CGFloat = 14
  static let separator = " · "
}

/// A container in the menu bar panel, on two lines: name, then status word and image; its
/// ports on the right. Start / stop show on hover and in the context menu.
struct MenuBarContainerRow: View {
  let container: Container
  let store: HangarStore

  @State private var isHovering = false

  var body: some View {
    let status = container.machineStatus
    HStack(spacing: Spacing.xs) {
      StatusSymbol(kind: status.kind)
      VStack(alignment: .leading, spacing: 0) {
        Text(container.name).font(.ui(FontSize.body, weight: .medium)).lineLimit(1)
        (Text(status.word).foregroundStyle(status.kind.wordColor)
          + Text(verbatim: Constants.separator).foregroundStyle(Color.tertiaryLabel)
          + Text(verbatim: container.image).foregroundStyle(Color.secondaryLabel))
          .font(.ui(FontSize.subheadline))
          .frame(minHeight: Constants.detailLineHeight)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailing
    }
    .frame(minHeight: Dimension.tallRow)
    .padding(.vertical, Constants.verticalPadding)
    .padding(.leading, Constants.leadingPadding)
    .padding(.trailing, Constants.trailingPadding)
    .contentShape(Rectangle())
    .onHover { isHovering = $0 }
    .help(container.status)
    .contextMenu { contextMenu }
  }

  @ViewBuilder
  private var trailing: some View {
    if store.busy.contains(container.id) {
      ProgressView().controlSize(.small)
    } else if isHovering {
      if container.isRunning {
        MenuBarIconButton("Stop \(container.name)", systemImage: "stop.fill") {
          store.stop(container)
        }
      } else {
        MenuBarIconButton("Start \(container.name)", systemImage: "play.fill") {
          store.start(container)
        }
      }
    } else if container.isRunning {
      HStack(spacing: Spacing.xxs) {
        ForEach(container.publishedPorts, id: \.self) { port in
          PortChip(port: port) { store.openPort(port) }
        }
      }
    }
  }

  @ViewBuilder
  private var contextMenu: some View {
    if container.isRunning {
      Button("Restart") { store.restart(container) }
      Button("Stop") { store.stop(container) }
    } else {
      Button("Start") { store.start(container) }
    }
    Divider()
    ProfileMembershipMenu(
      store: store,
      contains: { $0.containerNames.contains(container.name) },
      toggle: { store.toggle(container, in: $0) }
    )
  }
}
