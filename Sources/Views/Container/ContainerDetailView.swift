import AppKit
import SwiftUI

private enum Constants {
  static let postgresIcon = "cylinder.split.1x2"
  static let containerIcon = "shippingbox"
}

/// A container: header with its actions, the info grid, then Logs — and Database for
/// Postgres images.
struct ContainerDetailView: View {
  let container: Container
  let store: HangarStore

  @State private var tab = LaunchOptions.databaseView == nil ? ContainerTab.logs : .database

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if tab == .logs { ContainerInfoGrid(container: container, store: store) }
      Divider()
      switch tab {
      case .logs:
        ContainerLogsView(container: container, docker: store.docker) { tabPicker }
      case .database:
        databaseTab
      }
    }
    .onChange(of: container.name) { tab = .logs }
  }

  private var isPostgres: Bool { PostgresClient.isPostgres(container) }

  private var header: some View {
    DetailHeader(
      systemImage: isPostgres ? Constants.postgresIcon : Constants.containerIcon,
      name: container.name,
      status: container.machineStatus,
      facts: facts
    ) {
      actions
    }
  }

  /// With the info grid folded away for the Database tab, the image and port move up here.
  private var facts: [DetailFact] {
    var facts: [DetailFact] = [.text(container.statusDetail)]
    if let health = container.health { facts.append(.text(health.rawValue)) }
    if tab == .database {
      facts.append(.mono(container.image))
      if container.isRunning, let port = container.publishedPorts.first {
        facts.append(.port(port) { store.openPort(port) })
      }
    }
    return facts
  }

  @ViewBuilder
  private var actions: some View {
    if store.busy.contains(container.id) {
      ProgressView().controlSize(.small)
    } else if container.isRunning {
      Button("Restart", systemImage: "arrow.clockwise") { store.restart(container) }
      Button("Stop", systemImage: "stop.fill") { store.stop(container) }
    } else {
      Button("Start", systemImage: "play.fill") { store.start(container) }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
    moreMenu
  }

  private var moreMenu: some View {
    Menu {
      Button("Copy Container ID") { copy(container.id) }
      Button("Copy Name") { copy(container.name) }
      if container.isRunning, let port = container.publishedPorts.first {
        Divider()
        Button("Open localhost:\(String(port))") { store.openPort(port) }
      }
    } label: {
      Label("More actions", systemImage: "ellipsis")
        .labelStyle(.iconOnly)
    }
    .menuIndicator(.hidden)
    .fixedSize()
  }

  @ViewBuilder
  private var tabPicker: some View {
    if isPostgres {
      Picker("Tab", selection: $tab) {
        ForEach(ContainerTab.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    } else {
      Text(ContainerTab.logs.rawValue).font(.ui(FontSize.body, weight: .semibold))
    }
  }

  private var databaseTab: some View {
    let model = store.databaseModel(for: container)
    return VStack(spacing: 0) {
      HStack(spacing: Spacing.xs) {
        tabPicker
        Spacer()
        if let version = model.psqlVersion, let user = model.user {
          HStack(spacing: 0) {
            Text(verbatim: "psql \(version) · user ").font(.ui(FontSize.subheadline))
            Text(verbatim: user).font(.mono(FontSize.smallMono))
          }
          .foregroundStyle(Color.secondaryLabel)
        }
      }
      .padding(.vertical, Spacing.xs)
      .padding(.leading, Spacing.lg)
      .padding(.trailing, Spacing.md)
      Divider()
      DatabaseTabView(container: container, store: store, model: model)
    }
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
