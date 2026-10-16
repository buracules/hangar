import SwiftUI

/// A context-menu section that toggles a machine's membership in each profile.
struct ProfileMembershipMenu: View {
  let store: HangarStore
  let contains: (Profile) -> Bool
  let toggle: (Profile) -> Void

  var body: some View {
    if store.profiles.isEmpty {
      Text("No profiles yet")
    } else {
      Section("Profiles") {
        ForEach(store.profiles) { profile in
          Toggle(
            profile.name,
            isOn: Binding(get: { contains(profile) }, set: { _ in toggle(profile) })
          )
        }
      }
    }
  }
}
