import SwiftUI

private enum Constants {
  static let rowSpacing: CGFloat = 6
  static let codePadding: CGFloat = 6
  static let codeVerticalPadding: CGFloat = 1
  static let separator = " · "
  /// Uptime shows minutes, so once a minute is enough.
  static let uptimeRefreshSeconds: TimeInterval = 60
  /// The health value runs across the value, key and value columns to the right.
  static let healthColumns = 3
}

/// Command, folder, port, URL, PID, uptime and health check, in the design's two-column form.
struct ProjectInfoGrid: View {
  let project: Project
  let spec: ProjectSpec
  let run: ProjectRun?
  let store: HangarStore

  var body: some View {
    Grid(
      alignment: .leading,
      horizontalSpacing: Spacing.md,
      verticalSpacing: Constants.rowSpacing
    ) {
      GridRow {
        InfoKey("Command")
        commandValue
        InfoKey("Directory")
        Text(verbatim: (project.path as NSString).abbreviatingWithTildeInPath)
          .font(.mono(FontSize.smallMono))
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }
      GridRow {
        InfoKey("Port")
        portValue
        InfoKey("URL")
        urlValue
      }
      GridRow {
        InfoKey("PID")
        dashed(run?.pid.map(String.init)).font(.mono())
        InfoKey("Uptime")
        TimelineView(.periodic(from: .now, by: Constants.uptimeRefreshSeconds)) { _ in
          dashed(run?.isActive == true ? run?.startedAt.map(uptime) : nil)
        }
      }
      GridRow {
        InfoKey("Health check")
        healthValue.gridCellColumns(Constants.healthColumns)
      }
    }
    .font(.ui(FontSize.body))
    .padding(.horizontal, Spacing.lg)
    .padding(.bottom, Spacing.md)
  }

  @ViewBuilder
  private var commandValue: some View {
    if let command = run?.command ?? spec.launchCommand(port: spec.port) {
      HStack(spacing: Spacing.xs) {
        Text(verbatim: command)
          .font(.mono())
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.horizontal, Constants.codePadding)
          .padding(.vertical, Constants.codeVerticalPadding)
          .background(Color.controlFill, in: RoundedRectangle(cornerRadius: Radius.xs))
          .textSelection(.enabled)
        Text(spec.source == .config ? "from .hangar.json" : "detected")
          .font(.ui(FontSize.subheadline))
          .foregroundStyle(Color.secondaryLabel)
      }
    } else {
      Text("None — add \"command\" to .hangar.json").foregroundStyle(Color.secondaryLabel)
    }
  }

  @ViewBuilder
  private var portValue: some View {
    if let port = run?.isActive == true ? run?.port : spec.port {
      HStack(spacing: Spacing.xs) {
        PortChip(port: port) { store.openPort(port) }
          .disabled(run?.isActive != true)
        if let note = run?.isActive == true ? run?.portNote : nil {
          Text("assigned\(Constants.separator)\(note)")
            .font(.ui(FontSize.subheadline))
            .foregroundStyle(Color.secondaryLabel)
        }
      }
    } else {
      dashed(nil)
    }
  }

  @ViewBuilder
  private var urlValue: some View {
    if run?.isActive == true, let url = store.browserURL(for: project, openPath: spec.openPath) {
      HStack(spacing: Spacing.xs) {
        Link(url.absoluteString, destination: url).font(.mono(FontSize.smallMono))
        if let note = store.routeNotes[project.id] {
          Text(note).font(.ui(FontSize.subheadline)).foregroundStyle(Color.secondaryLabel)
        }
      }
    } else {
      dashed(nil)
    }
  }

  @ViewBuilder
  private var healthValue: some View {
    if let path = spec.healthCheck {
      HStack(spacing: Spacing.xs) {
        Text(verbatim: "GET \(path)").font(.mono(FontSize.smallMono))
        if let health = run?.lastHealth {
          Text(healthText(health))
            .font(.ui(FontSize.callout))
            .foregroundStyle(Color.secondaryLabel)
        }
      }
    } else {
      Text("Off — set \"healthCheck\" in .hangar.json")
        .font(.ui(FontSize.callout))
        .foregroundStyle(Color.secondaryLabel)
    }
  }

  private func healthText(_ health: HealthCheckResult) -> String {
    let result = health.statusCode.map { "\($0) in \(health.milliseconds) ms" } ?? "no answer"
    return "every 10 s\(Constants.separator)\(result), at \(ActivityTime.clock(health.date))"
  }

  private func uptime(_ start: Date) -> String {
    String(ActivityTime.uptime(since: start).dropFirst("Up ".count))
  }

  private func dashed(_ text: String?) -> some View {
    Text(verbatim: text ?? "—")
      .foregroundStyle(text == nil ? Color.tertiaryLabel : Color.primary)
      .textSelection(.enabled)
  }
}
