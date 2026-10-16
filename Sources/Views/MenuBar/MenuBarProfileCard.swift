import SwiftUI

private enum Constants {
  static let spacing: CGFloat = 10
  static let nameSpacing: CGFloat = 8
  static let padding: CGFloat = 8
  static let leadingPadding: CGFloat = 12
  static let buttonSize: CGFloat = 22
  static let buttonIcon: CGFloat = 10
  static let outline: CGFloat = 0.5
  static let memberSeparator = " · "
}

/// A profile in the menu bar panel: name, "2/3 up", its members, and start / stop.
struct MenuBarProfileCard: View {
  let profile: Profile
  let store: HangarStore

  var body: some View {
    let members = store.members(of: profile)
    let isBusy = store.busy.contains(profile.id.uuidString)
    HStack(spacing: Constants.spacing) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline, spacing: Constants.nameSpacing) {
          Text(profile.name).font(.ui(FontSize.body, weight: .semibold)).lineLimit(1)
          Text(verbatim: "\(members.runningCount)/\(members.total) up")
            .font(.ui(FontSize.subheadline))
            .monospacedDigit()
            .foregroundStyle(Color.secondaryLabel)
        }
        Text(memberNames(members))
          .font(.ui(FontSize.subheadline))
          .foregroundStyle(Color.secondaryLabel)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if isBusy { ProgressView().controlSize(.small) }
      button("Start \(profile.name)", systemImage: "play.fill", isProminent: true) {
        store.startProfile(profile)
      }
      .disabled(isBusy || members.total == 0 || members.areAllUp)
      button("Stop \(profile.name)", systemImage: "stop.fill", isProminent: false) {
        store.stopProfile(profile)
      }
      .disabled(isBusy || members.runningCount == 0)
    }
    .padding(Constants.padding)
    .padding(.leading, Constants.leadingPadding - Constants.padding)
    .background(Color.backgroundCard, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.md)
        .strokeBorder(Color.strongSeparator, lineWidth: Constants.outline)
    )
  }

  private func memberNames(_ members: ProfileMembers) -> String {
    let names = members.vms.map(\.name) + members.containers.map(\.name)
    return names.isEmpty ? "No members yet" : names.joined(separator: Constants.memberSeparator)
  }

  @ViewBuilder
  private func button(
    _ title: String,
    systemImage: String,
    isProminent: Bool,
    action: @escaping () -> Void
  ) -> some View {
    let label = Image(systemName: systemImage)
      .font(.system(size: Constants.buttonIcon))
      .frame(width: Constants.buttonSize, height: Constants.buttonSize)
    if isProminent {
      Button(action: action) { label }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
    } else {
      Button(action: action) { label }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
    }
  }
}
