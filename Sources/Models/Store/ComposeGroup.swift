import Foundation

/// The containers of one compose project.
struct ComposeGroup: Identifiable {
  /// The compose project name.
  let id: String
  let containers: [Container]

  var runningCount: Int { containers.filter(\.isRunning).count }
}
