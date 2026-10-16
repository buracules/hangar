import Foundation

/// Something that happened to a machine: "Started by profile work", "Force stopped".
struct ActivityEvent: Identifiable, Codable, Sendable, Equatable {
  /// The state the event left the machine in, which picks its shape in the timeline.
  enum Outcome: String, Codable, Sendable {
    case running
    case paused
    case busy
    case stopped
    case error
  }

  var id = UUID()
  let date: Date
  let outcome: Outcome
  /// "Started", "Force stopped", "UTM opened hidden".
  let title: String
  /// Who asked for it, read straight after the title: "by profile work", "from the CLI".
  var cause: String?
  /// What else is worth knowing, after a dash: "it was closed", "code 137".
  var detail: String?
}
