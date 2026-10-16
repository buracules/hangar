import Foundation

// MARK: - Database

extension HangarStore {
  /// The Database tab's state for a container, created on first use and kept by name so it
  /// survives tab switches and container restarts.
  func databaseModel(for container: Container) -> DatabaseModel {
    if let model = databaseModels[container.name] { return model }
    let model = DatabaseModel()
    databaseModels[container.name] = model
    return model
  }
}
