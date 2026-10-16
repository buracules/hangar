import SwiftUI

private enum Constants {
  /// The design's `.tl` columns: time, symbol, text.
  static let timeWidth: CGFloat = 52
  static let symbolWidth: CGFloat = 14
  static let rowSpacing: CGFloat = 10
  static let maxWidth: CGFloat = 640
  static let headerSpacing: CGFloat = 12
}

/// A machine's recent history, newest first: what happened, why, and when.
struct ActivityTimeline: View {
  let events: [ActivityEvent]

  var body: some View {
    VStack(alignment: .leading, spacing: Constants.headerSpacing) {
      Text("Activity")
        .font(.ui(FontSize.subheadline, weight: .semibold))
        .foregroundStyle(Color.tertiaryLabel)
      if events.isEmpty {
        Text("Nothing yet. Starts, stops and crashes show up here.")
          .font(.ui(FontSize.callout))
          .foregroundStyle(Color.secondaryLabel)
      } else {
        ScrollView {
          Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: Spacing.xs,
            verticalSpacing: Constants.rowSpacing
          ) {
            ForEach(events) { row($0) }
          }
          .frame(maxWidth: Constants.maxWidth, alignment: .leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
      }
    }
    .padding(.vertical, Spacing.md)
    .padding(.horizontal, Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.backgroundContent)
  }

  private func row(_ event: ActivityEvent) -> some View {
    GridRow {
      Text(verbatim: ActivityTime.label(for: event.date))
        .font(.mono(FontSize.smallMono))
        .foregroundStyle(Color.tertiaryLabel)
        .frame(width: Constants.timeWidth, alignment: .leading)
      StatusSymbol(kind: event.outcome.kind)
        .frame(width: Constants.symbolWidth)
      (Text(event.title + cause(event))
        + Text(verbatim: suffix(event)).foregroundStyle(Color.secondaryLabel))
        .font(.ui(FontSize.callout))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// " by profile work · 19:02 — it was closed"; the clock only for events before today.
  private func cause(_ event: ActivityEvent) -> String {
    event.cause.map { " " + $0 } ?? ""
  }

  private func suffix(_ event: ActivityEvent) -> String {
    var suffix = ""
    if !ActivityTime.labelShowsClock(event.date) {
      suffix += " · " + ActivityTime.clock(event.date)
    }
    if let detail = event.detail, !detail.isEmpty { suffix += " — " + detail }
    return suffix
  }
}
