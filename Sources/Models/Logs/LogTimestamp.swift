import Foundation

private enum Constants {
  /// `2026-10-16T15:10:54Z` is the shortest form Docker prints.
  static let minimumDockerLength = 20
  /// The `T` between date and time sits after `YYYY-MM-DD`.
  static let dateLength = 10
}

/// Timestamps at the start of log lines: the one Docker adds, and the one many programs
/// print themselves.
enum LogTimestamp {
  /// Docker's prefix: RFC 3339 in UTC with nanoseconds, `2026-10-16T15:10:54.505123456Z`.
  static func dockerTime(_ token: Substring) -> Date? {
    guard token.count >= Constants.minimumDockerLength, token.last == "Z",
      token.dropFirst(Constants.dateLength).first == "T"
    else { return nil }
    let whole = token.prefix { $0 != "." && $0 != "Z" }
    guard let date = try? Date(whole + "Z", strategy: .iso8601) else { return nil }
    let fraction = token.drop { $0 != "." }.dropFirst().prefix(while: \.isNumber)
    guard !fraction.isEmpty, let seconds = Double("0." + fraction) else { return date }
    return date.addingTimeInterval(seconds)
  }

  /// UTF-16 length of a timestamp the program printed itself, plus the space after it:
  /// `2026-10-16 15:10:54.505 UTC`, `2026-10-16T15:10:54Z`, `[2026-10-16 15:10:54,505]` …
  static func ownTimestampLength(in text: String) -> Int {
    let pattern =
      /^\[?\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2}| ?UTC)?\]?\s*/
    guard let match = text.prefixMatch(of: pattern) else { return 0 }
    return text[..<match.range.upperBound].utf16.count
  }
}
