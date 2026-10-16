import SwiftUI

private enum Constants {
  static let iconTile: CGFloat = 40
  static let iconSize: CGFloat = 22
  static let nameLineSpacing: CGFloat = 2
  static let statusSpacing: CGFloat = 6
  static let separator = "·"
}

/// The top of a detail pane: icon tile, name, status line and the primary actions.
struct DetailHeader<Actions: View>: View {
  let systemImage: String
  let name: String
  let status: MachineStatus?
  /// Extra facts after the status, separated by middle dots: "Up 2 hours", "healthy".
  var facts: [DetailFact] = []
  @ViewBuilder let actions: Actions

  var body: some View {
    HStack(spacing: Spacing.sm) {
      Image(systemName: systemImage)
        .font(.system(size: Constants.iconSize))
        .foregroundStyle(Color.accentText)
        .frame(width: Constants.iconTile, height: Constants.iconTile)
        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Constants.nameLineSpacing) {
        Text(name)
          .font(.ui(FontSize.title2, weight: .semibold))
          .lineLimit(1)
          .textSelection(.enabled)
        statusLine
      }
      Spacer(minLength: Spacing.md)
      HStack(spacing: Spacing.xs) { actions }
    }
    .padding(.vertical, Spacing.md)
    .padding(.horizontal, Spacing.lg)
  }

  private var statusLine: some View {
    HStack(spacing: Constants.statusSpacing) {
      if let status { StatusLabel(status: status) }
      ForEach(facts.indices, id: \.self) { index in
        Text(Constants.separator)
        factView(facts[index])
      }
    }
    .font(.ui(FontSize.callout))
    .foregroundStyle(Color.secondaryLabel)
    .lineLimit(1)
  }

  @ViewBuilder
  private func factView(_ fact: DetailFact) -> some View {
    switch fact {
    case .text(let text): Text(text)
    case .mono(let text): Text(text).font(.mono(FontSize.smallMono))
    case .port(let port, let open): PortChip(port: port, open: open)
    }
  }
}
