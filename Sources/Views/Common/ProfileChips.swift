import SwiftUI

private enum Constants {
  static let height: CGFloat = 20
  static let leadingPadding: CGFloat = 8
  static let trailingPadding: CGFloat = 4
  static let removeButton: CGFloat = 14
  static let removeIcon: CGFloat = 7
  static let outline: CGFloat = 1
}

/// The profiles a machine belongs to, as removable chips, and "+" to add it to another.
struct ProfileChips: View {
  let store: HangarStore
  let isMember: (Profile) -> Bool
  let add: (Profile) -> Void
  let remove: (Profile) -> Void

  var body: some View {
    HStack(spacing: Spacing.xxs) {
      ForEach(store.profiles.filter(isMember)) { profile in
        chip(profile)
      }
      addMenu
    }
  }

  private func chip(_ profile: Profile) -> some View {
    HStack(spacing: Spacing.xxs) {
      Text(profile.name)
      Button {
        remove(profile)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: Constants.removeIcon, weight: .bold))
          .frame(width: Constants.removeButton, height: Constants.removeButton)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.tertiaryLabel)
      .accessibilityLabel("Remove from \(profile.name)")
    }
    .font(.ui(FontSize.callout))
    .padding(.leading, Constants.leadingPadding)
    .padding(.trailing, Constants.trailingPadding)
    .frame(height: Constants.height)
    .background(Color.controlFill, in: Capsule())
  }

  private var addMenu: some View {
    let others = store.profiles.filter { !isMember($0) }
    return Menu {
      ForEach(others) { profile in
        Button(profile.name) { add(profile) }
      }
      if others.isEmpty { Text("In every profile") }
    } label: {
      Text(verbatim: "+")
        .font(.ui(FontSize.callout))
        .foregroundStyle(Color.secondaryLabel)
        .padding(.horizontal, Constants.leadingPadding)
        .frame(height: Constants.height)
        .overlay(Capsule().strokeBorder(Color.strongSeparator, lineWidth: Constants.outline))
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel("Add to profile")
  }
}
