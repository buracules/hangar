import Foundation

/// A folder added to Hangar as a project, as stored in `projects.json`. Everything else is
/// read from the folder each time, so editing `.hangar.json` takes effect on the next start.
struct Project: Codable, Identifiable, Equatable, Sendable {
  var id = UUID()
  /// The project folder, absolute.
  var path: String

  var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
  var folderName: String { url.lastPathComponent }
}
