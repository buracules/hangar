import SwiftUI

private enum Constants {
  static let spacing: CGFloat = 6
}

/// Shape, colour and word together — the way every status is shown.
struct StatusLabel: View {
  let status: MachineStatus

  var body: some View {
    HStack(spacing: Constants.spacing) {
      StatusSymbol(kind: status.kind)
      Text(status.word)
        .fontWeight(.medium)
        .foregroundStyle(status.kind.wordColor)
    }
    .accessibilityElement(children: .combine)
  }
}
