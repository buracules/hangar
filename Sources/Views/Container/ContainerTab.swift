import Foundation

/// The tabs under a container's info: its logs, and for Postgres images its databases.
enum ContainerTab: String, CaseIterable, Identifiable {
  case logs = "Logs"
  case database = "Database"

  var id: Self { self }
}
