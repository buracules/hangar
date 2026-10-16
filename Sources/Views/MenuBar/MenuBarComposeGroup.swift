import SwiftUI

private enum Constants {
  static let chevronSize: CGFloat = 20
  static let chevronIcon: CGFloat = 9
  static let spacing: CGFloat = 6
  static let leadingPadding: CGFloat = 12
  static let trailingPadding: CGFloat = 10
  static let quarterTurn: Double = 90
}

/// A compose project in the menu bar panel: a collapsible header with its count and
/// start / stop all, then its containers.
struct MenuBarComposeGroup: View {
  let group: ComposeGroup
  let store: HangarStore

  @State private var isExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded {
        ForEach(group.containers) { MenuBarContainerRow(container: $0, store: store) }
      }
    }
  }

  private var header: some View {
    HStack(spacing: Constants.spacing) {
      Button {
        withAnimation(Motion.ease()) { isExpanded.toggle() }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: Constants.chevronIcon, weight: .semibold))
          .rotationEffect(.degrees(isExpanded ? Constants.quarterTurn : 0))
          .frame(width: Constants.chevronSize, height: Constants.chevronSize)
          .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .foregroundStyle(Color.secondaryLabel)
      .accessibilityLabel(isExpanded ? "Collapse \(group.id)" : "Expand \(group.id)")
      Text(group.id).font(.ui(FontSize.body, weight: .semibold)).lineLimit(1)
      Text(verbatim: "\(group.runningCount)/\(group.containers.count)")
        .font(.ui(FontSize.subheadline))
        .monospacedDigit()
        .foregroundStyle(Color.secondaryLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
      if group.runningCount < group.containers.count {
        MenuBarIconButton("Start all in \(group.id)", systemImage: "play.fill") {
          store.startAll(group)
        }
      }
      if group.runningCount > 0 {
        MenuBarIconButton("Stop all in \(group.id)", systemImage: "stop.fill") {
          store.stopAll(group)
        }
      }
    }
    .frame(height: Dimension.row)
    .padding(.leading, Constants.leadingPadding)
    .padding(.trailing, Constants.trailingPadding)
  }
}
