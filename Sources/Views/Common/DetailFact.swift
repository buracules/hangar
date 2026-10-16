import Foundation

/// One fact in a detail header's status line, after the status itself.
enum DetailFact {
  /// "Up 2 hours", "healthy".
  case text(String)
  /// An identifier: `postgres:17`.
  case mono(String)
  /// A published port chip that opens it in the browser.
  case port(Int, open: () -> Void)
}
