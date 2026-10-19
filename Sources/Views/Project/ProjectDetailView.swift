import AppKit
import SwiftUI

private enum Constants {
  static let icon = "chevron.left.forwardslash.chevron.right"
  static let eventsMinWidth: CGFloat = 260
  static let eventsMaxWidth: CGFloat = 360
  static let logsMinWidth: CGFloat = 420
  static let bannerPadding: CGFloat = 8
  static let outline: CGFloat = 0.5
}

/// A project: header with Open in Browser and start / stop, the info grid, then its output
/// beside what has happened to it.
struct ProjectDetailView: View {
  let project: Project
  let store: HangarStore
  @Binding var selection: SidebarItem?

  @State private var isConfirmingRemove = false

  var body: some View {
    let spec = store.spec(for: project)
    let run = store.projectRuns[project.id]
    VStack(alignment: .leading, spacing: 0) {
      DetailHeader(
        systemImage: Constants.icon,
        name: spec.name,
        status: store.status(of: project),
        facts: facts(spec: spec, run: run)
      ) {
        actions(spec: spec, run: run)
      }
      if let message = problem(run) { banner(message) }
      ProjectInfoGrid(project: project, spec: spec, run: run, store: store)
      Divider()
      HStack(spacing: 0) {
        logs(run)
          .frame(minWidth: Constants.logsMinWidth)
        Divider()
        ActivityTimeline(events: store.activity.events(for: project.id.uuidString))
          .frame(minWidth: Constants.eventsMinWidth, maxWidth: Constants.eventsMaxWidth)
      }
    }
    .confirmationDialog("Remove \(spec.name) from Hangar?", isPresented: $isConfirmingRemove) {
      Button("Remove Project", role: .destructive) {
        selection = nil
        store.removeProject(project)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("It stops if it is running. The folder and its files are left alone.")
    }
  }

  // MARK: - Header

  private func facts(spec: ProjectSpec, run: ProjectRun?) -> [DetailFact] {
    var facts: [DetailFact] = [.text(spec.kind)]
    switch run?.state {
    case .running?:
      if let start = run?.startedAt { facts.append(.text(ActivityTime.uptime(since: start))) }
      if spec.healthCheck != nil { facts.append(.text("health check passing")) }
    case .starting?:
      if let port = run?.port { facts.append(.text("waiting for port \(String(port)) to answer…")) }
    case .unhealthy(let reason)?:
      facts.append(.text(reason))
    case .crashed(let code)?:
      facts.append(.text("exit code \(code)"))
    default:
      break
    }
    return facts
  }

  @ViewBuilder
  private func actions(spec: ProjectSpec, run: ProjectRun?) -> some View {
    let isActive = run?.isActive == true
    if isActive, let url = store.browserURL(for: project, openPath: spec.openPath) {
      Button("Open in Browser", systemImage: "safari") { NSWorkspace.shared.open(url) }
        .disabled(run?.state == .starting)
    }
    if isActive {
      Button("Restart", systemImage: "arrow.clockwise") { store.restartProject(project) }
        .disabled(run?.state == .stopping)
      Button("Stop", systemImage: "stop.fill") { store.stopProject(project) }
        .disabled(run?.state == .stopping)
    } else {
      Button("Start", systemImage: "play.fill") { store.startProject(project) }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(spec.command == nil)
    }
    moreMenu
  }

  private var moreMenu: some View {
    Menu {
      Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.url]) }
      Button("Copy Path") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(project.path, forType: .string)
      }
      Divider()
      Button("Remove Project…") { isConfirmingRemove = true }
    } label: {
      Label("More actions", systemImage: "ellipsis").labelStyle(.iconOnly)
    }
    .menuIndicator(.hidden)
    .fixedSize()
  }

  // MARK: - Problems

  /// What went wrong, worth a banner: a crash or a start that never happened.
  private func problem(_ run: ProjectRun?) -> String? {
    switch run?.state {
    case .failed(let message)?: message
    case .crashed?: run?.buffer.lines.last(where: \.isStderr)?.text ?? run?.buffer.endReason
    default: nil
    }
  }

  private func banner(_ message: String) -> some View {
    Text(message)
      .font(.ui(FontSize.callout))
      .lineLimit(2)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, Constants.bannerPadding)
      .padding(.horizontal, Spacing.sm)
      .background(Color.errorBackground, in: RoundedRectangle(cornerRadius: Radius.sm))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.sm)
          .strokeBorder(Color.errorBorder, lineWidth: Constants.outline)
      )
      .padding(.horizontal, Spacing.lg)
      .padding(.bottom, Spacing.sm)
  }

  // MARK: - Logs

  @ViewBuilder
  private func logs(_ run: ProjectRun?) -> some View {
    if let run {
      LogPane(buffer: run.buffer) {
        Text("Logs").font(.ui(FontSize.body, weight: .semibold))
      }
    } else {
      ContentUnavailableView(
        "Not started yet",
        systemImage: "text.alignleft",
        description: Text("Its output shows up here once it starts.")
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.backgroundContent)
    }
  }
}
