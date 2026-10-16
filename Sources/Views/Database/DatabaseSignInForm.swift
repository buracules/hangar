import SwiftUI

private enum Constants {
  static let width: CGFloat = 340
  static let labelWidth: CGFloat = 64
}

/// Shown when psql's sign-in fails: Postgres's error, and a user and password to try instead
/// for the rest of this app session.
struct DatabaseSignInForm: View {
  let message: String
  let database: String
  /// A nil user goes back to the container's POSTGRES_USER.
  let signIn: (_ user: String?, _ password: String) -> Void

  @State private var user = ""
  @State private var password = ""

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.sm) {
      Label("Couldn’t sign in to \(database)", systemImage: "xmark")
        .font(.ui(FontSize.body, weight: .semibold))
        .labelStyle(.titleAndIcon)
        .foregroundStyle(Color.label)
      ErrorBox(message: message)
      Grid(alignment: .leading, horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.xs) {
        GridRow {
          Text("User").frame(width: Constants.labelWidth, alignment: .trailing)
          TextField("User", text: $user).textFieldStyle(.roundedBorder)
        }
        GridRow {
          Text("Password").frame(width: Constants.labelWidth, alignment: .trailing)
          SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
        }
      }
      .font(.ui(FontSize.callout))
      .foregroundStyle(Color.secondaryLabel)
      HStack {
        Spacer()
        Button("Use POSTGRES_USER") { signIn(nil, "") }
        Button("Connect") { signIn(user, password) }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(user.isEmpty)
      }
    }
    .padding(Spacing.md)
    .frame(width: Constants.width)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
