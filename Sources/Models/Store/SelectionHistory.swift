import Foundation

/// Back and forward through what was selected, like a browser.
struct SelectionHistory<Item: Equatable> {
  private(set) var back: [Item] = []
  private(set) var forward: [Item] = []

  var canGoBack: Bool { !back.isEmpty }
  var canGoForward: Bool { !forward.isEmpty }

  /// Records leaving `previous` for something new; the forward trail no longer applies.
  mutating func visit(from previous: Item?) {
    guard let previous else { return }
    if back.last != previous { back.append(previous) }
    forward.removeAll()
  }

  /// The item to go back to from `current`, if any.
  mutating func goBack(from current: Item?) -> Item? {
    guard let target = back.popLast() else { return nil }
    if let current { forward.append(current) }
    return target
  }

  /// The item to go forward to from `current`, if any.
  mutating func goForward(from current: Item?) -> Item? {
    guard let target = forward.popLast() else { return nil }
    if let current { back.append(current) }
    return target
  }
}
