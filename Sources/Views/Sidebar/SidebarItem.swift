import Foundation

/// What the sidebar can select. Containers by name: a recreated container keeps its name,
/// not its id, so the selection survives `docker compose up`.
enum SidebarItem: Hashable {
  case profile(UUID)
  case vm(String)
  case container(String)
  case project(UUID)
}
