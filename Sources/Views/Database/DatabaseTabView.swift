import AppKit
import SwiftUI

private enum Constants {
  static let installCommand = "apt-get install postgresql-client"
  static let psqlMissingMarker = "psql was not found"
  static let authFailureMarkers = ["password authentication failed", "authentication failed"]
  static let skeletonRowCount = 6
  /// Placeholder lines shorten in a repeating pattern of three, so they read as text.
  static let skeletonPattern = 3
  static let skeletonShortening: CGFloat = 0.15
  static let skeletonHeight: CGFloat = 10
  static let paneWidth: CGFloat = 256
}

/// The Database tab: reads the container's databases through its own psql.
struct DatabaseTabView: View {
  let container: Container
  let store: HangarStore
  @Bindable var model: DatabaseModel

  var body: some View {
    content
      .task(id: "\(container.id)|\(container.isRunning)") {
        guard container.isRunning, let docker = store.docker else {
          model.disconnect()
          return
        }
        let isFirstConnect = model.phase == .idle
        if let view = LaunchOptions.databaseView, isFirstConnect { model.tab = view }
        await model.connect(to: container, docker: docker)
        if isFirstConnect, let sql = LaunchOptions.sql {
          model.sql = sql
          await model.runSQL()
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    if !container.isRunning {
      DatabaseEmptyState(
        systemImage: "cylinder.split.1x2",
        title: "\(container.name) is stopped",
        message: "Start the container to browse its databases."
      ) {
        Button("Start Container", systemImage: "play.fill") { store.start(container) }
          .buttonStyle(.borderedProminent)
      }
    } else {
      switch model.phase {
      case .idle, .connecting: loading
      case .failed(let message): failure(message)
      case .ready: ready
      }
    }
  }

  @ViewBuilder
  private var ready: some View {
    HStack(spacing: 0) {
      DatabaseTablesPane(model: model)
      Divider()
      if model.tables.isEmpty && model.tab != .sql {
        DatabaseEmptyState(
          systemImage: "tablecells",
          title: "\(model.database ?? "This database") has no tables",
          message: "Run your migrations, or create one in the SQL tab."
        ) {
          Button("Open SQL") { model.tab = .sql }
        }
      } else {
        DatabaseContentView(model: model)
      }
    }
  }

  private var loading: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: Spacing.sm) { skeleton }
        .padding(Spacing.sm)
        .frame(width: Constants.paneWidth)
        .background(Color.backgroundPane)
      Divider()
      VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(spacing: Spacing.xs) {
          ProgressView().controlSize(.mini)
          Text("Reading schema…").foregroundStyle(Color.secondaryLabel)
        }
        skeleton
      }
      .padding(Spacing.sm)
    }
  }

  private var skeleton: some View {
    GeometryReader { proxy in
      VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(0..<Constants.skeletonRowCount, id: \.self) { row in
          let fraction = 1 - CGFloat(row % Constants.skeletonPattern) * Constants.skeletonShortening
          Capsule()
            .fill(Color.controlFill)
            .frame(width: proxy.size.width * fraction, height: Constants.skeletonHeight)
        }
      }
    }
  }

  @ViewBuilder
  private func failure(_ message: String) -> some View {
    if message.contains(Constants.psqlMissingMarker) {
      DatabaseEmptyState(
        systemImage: "apple.terminal",
        title: "psql isn’t in this image",
        message:
          "Hangar reads databases through psql inside the container, "
          + "and this image doesn’t include it."
      ) {
        Button("Copy Command") { copy(Constants.installCommand) }
      }
    } else if isAuthFailure(message) {
      DatabaseSignInForm(message: message, database: model.database ?? container.name) {
        signIn(user: $0, password: $1)
      }
    } else {
      DatabaseEmptyState(
        systemImage: "exclamationmark.triangle",
        title: "Couldn’t read the databases",
        message: message
      ) {
        Button("Try Again") {
          model.disconnect()
          guard let docker = store.docker else { return }
          Task { await model.connect(to: container, docker: docker) }
        }
      }
    }
  }

  private func isAuthFailure(_ message: String) -> Bool {
    Constants.authFailureMarkers.contains { message.localizedCaseInsensitiveContains($0) }
  }

  private func signIn(user: String?, password: String) {
    guard let docker = store.docker else { return }
    Task {
      await model.signIn(user: user, password: password, container: container, docker: docker)
    }
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
