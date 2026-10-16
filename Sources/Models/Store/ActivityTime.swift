import Foundation

private enum Constants {
  static let posixLocale = Locale(identifier: "en_US_POSIX")
  static let clockFormat = "HH:mm"
  static let weekdayFormat = "EEE"
  static let yesterday = "Yest."
  /// Older than this, the timeline shows a date instead of a weekday.
  static let weekdayDays = 6
  static let dateFormat = "d MMM"
  static let secondsPerMinute = 60
  static let minutesPerHour = 60
  static let hoursPerDay = 24
}

/// How the activity timeline labels an event's time: today's events by the clock, older
/// ones by day, with the clock moved into the detail.
enum ActivityTime {
  /// "14:20" today, "Yest.", "Mon" within the week, "3 Oct" before that.
  static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
    if calendar.isDate(date, inSameDayAs: now) { return clock(date, calendar: calendar) }
    if calendar.isDateInYesterday(date, relativeTo: now) { return Constants.yesterday }
    let days =
      calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: date),
        to: calendar.startOfDay(for: now)
      )
      .day ?? 0
    let format = days <= Constants.weekdayDays ? Constants.weekdayFormat : Constants.dateFormat
    return formatted(date, format: format, calendar: calendar)
  }

  /// Whether the label already shows the clock time.
  static func labelShowsClock(
    _ date: Date,
    now: Date = .now,
    calendar: Calendar = .current
  )
    -> Bool
  {
    calendar.isDate(date, inSameDayAs: now)
  }

  static func clock(_ date: Date, calendar: Calendar = .current) -> String {
    formatted(date, format: Constants.clockFormat, calendar: calendar)
  }

  private static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.locale = Constants.posixLocale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  /// "Up 3 h 12 min", "Up 2 d 4 h", "Up 5 min".
  static func uptime(since start: Date, now: Date = .now) -> String {
    let minutes = max(0, Int(now.timeIntervalSince(start)) / Constants.secondsPerMinute)
    let hours = minutes / Constants.minutesPerHour
    let days = hours / Constants.hoursPerDay
    if days > 0 { return "Up \(days) d \(hours % Constants.hoursPerDay) h" }
    if hours > 0 { return "Up \(hours) h \(minutes % Constants.minutesPerHour) min" }
    return "Up \(minutes) min"
  }
}
