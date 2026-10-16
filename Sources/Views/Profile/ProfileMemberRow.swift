import SwiftUI

private enum Constants {
  static let height: CGFloat = 36
  static let spacing: CGFloat = 10
  static let leadingPadding: CGFloat = 12
  static let trailingPadding: CGFloat = 8
  static let removeSize: CGFloat = 22
  static let removeIcon: CGFloat = 9
}

/// One member in a profile's card: status, name (opens it), status word, a detail on the
/// right and a remove button.
struct ProfileMemberRow<Detail: View>: View {
  let name: String
  /// Nil when the member no longer exists.
  let status: MachineStatus?
  let isBusy: Bool
  let open: (() -> Void)?
  let remove: () -> Void
  @ViewBuilder let detail: Detail

  var body: some View {
    HStack(spacing: Constants.spacing) {
      StatusSymbol(kind: status?.kind ?? .error)
      nameView
      Text(status?.word ?? "Missing")
        .font(.ui(FontSize.callout))
        .foregroundStyle(status?.kind.wordColor ?? Color.statusError)
        .frame(maxWidth: .infinity, alignment: .leading)
      if isBusy { ProgressView().controlSize(.small) }
      detail
      Button("Remove \(name)", systemImage: "xmark", action: remove)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: Constants.removeIcon, weight: .semibold))
        .foregroundStyle(Color.secondaryLabel)
        .frame(width: Constants.removeSize, height: Constants.removeSize)
        .help("Remove from profile")
    }
    .frame(height: Constants.height)
    .padding(.leading, Constants.leadingPadding)
    .padding(.trailing, Constants.trailingPadding)
  }

  @ViewBuilder
  private var nameView: some View {
    if let open {
      Button(action: open) {
        Text(name).font(.ui(FontSize.body, weight: .medium)).foregroundStyle(Color.primary)
      }
      .buttonStyle(.plain)
      .pointerStyle(.link)
    } else {
      Text(name).font(.ui(FontSize.body, weight: .medium)).foregroundStyle(Color.secondaryLabel)
    }
  }
}
