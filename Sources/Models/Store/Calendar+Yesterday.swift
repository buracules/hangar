import Foundation

// MARK: - Yesterday

extension Calendar {
  /// `isDateInYesterday`, against any "now" so it can be tested.
  func isDateInYesterday(_ date: Date, relativeTo now: Date) -> Bool {
    guard let yesterday = self.date(byAdding: .day, value: -1, to: now) else { return false }
    return isDate(date, inSameDayAs: yesterday)
  }
}
