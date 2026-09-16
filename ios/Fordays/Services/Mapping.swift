import Foundation
import Supabase

struct SpaceRow: Decodable {
  let id: String
  let name: String
  let invite_code: String
  let partner_1_id: String
  let partner_2_id: String?
  let frozen: Bool?
  let forked_from: String?
}

struct SpaceMemberRow: Decodable {
  let space_id: String
  let user_id: String
  let role: String
}

struct ProfileRow: Decodable {
  let id: String
  let display_name: String?
}

struct ActivityRow: Decodable {
  let id: String
  let space_id: String?
  let title: String
  let description: String?
  let image_url: String?
  let created_by: String
  let date_time: String?
  let ends_at: String?
  let all_day: Bool?
  let suggested_date_time: String?
  let suggested_ends_at: String?
  let suggested_all_day: Bool?
  let suggested_by: String?
  let suggested_at: String?
  let suggested_note: String?
  let created_at: String
}

enum DateLocal {
  static func addDays(_ n: Int, from date: Date = Date()) -> String {
    let next = Calendar.current.date(byAdding: .day, value: n, to: date) ?? date
    return todayISO(next)
  }

  static func addDays(_ n: Int, from iso: String) -> String {
    addDays(n, from: parseLocalDay(iso) ?? Date())
  }

  /// Next Saturday. Never today — same as the PWA.
  static func nextSaturday() -> String {
    let weekday = Calendar.current.component(.weekday, from: Date()) // 1 = Sun
    let offset = (7 - weekday + 7) % 7
    return addDays(offset == 0 ? 7 : offset)
  }

  static func monthTitle(for date: Date) -> String {
    let f = DateFormatter()
    let currentYear = Calendar.current.component(.year, from: Date())
    let cursorYear = Calendar.current.component(.year, from: date)
    if cursorYear == currentYear {
      f.dateFormat = "MMMM"
    } else {
      f.dateFormat = "MMMM yyyy"
    }
    return f.string(from: date)
  }

  static func isOffCurrentMonth(_ date: Date) -> Bool {
    let c = Calendar.current
    let now = Date()
    return c.component(.month, from: date) != c.component(.month, from: now)
      || c.component(.year, from: date) != c.component(.year, from: now)
  }

  static func mediumDate(_ dateISO: String) -> String {
    guard let date = parseLocalDay(dateISO) else { return dateISO }
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d"
    return f.string(from: date)
  }

  static func shortDate(_ dateISO: String) -> String {
    let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let parts = dateISO.split(separator: "-").compactMap { Int($0) }
    guard parts.count >= 3 else { return String(dateISO.prefix(10)) }
    let m = parts[1]
    let d = parts[2]
    guard (1...12).contains(m) else { return String(dateISO.prefix(10)) }
    return "\(names[m - 1]) \(d)"
  }

  static func prettyLower(_ hhmm: String) -> String {
    prettyTime(hhmm).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
  }

  static func relativeDay(_ dateISO: String, from: String = todayISO()) -> String {
    guard let start = parseLocalDay(from), let target = parseLocalDay(dateISO) else {
      return String(dateISO.prefix(10))
    }
    let days = Calendar.current.dateComponents([.day], from: start, to: target).day ?? 0
    if days == 0 { return "Today" }
    if days == 1 { return "Tomorrow" }
    if days == -1 { return "Yesterday" }
    if days > 1 && days < 14 { return "In \(days) days" }
    if days >= 14 && days < 60 {
      let weeks = Int((Double(days) / 7).rounded())
      return weeks <= 1 ? "In \(days) days" : "In \(weeks) weeks"
    }
    if days < -1 && days > -14 { return "\(abs(days)) days ago" }
    let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let parts = dateISO.split(separator: "-").compactMap { Int($0) }
    guard parts.count >= 2 else { return String(dateISO.prefix(10)) }
    return "\(names[parts[1] - 1]) \(parts[2])"
  }

  static func todayISO(_ date: Date = Date()) -> String {
    let c = Calendar.current
    let y = c.component(.year, from: date)
    let m = c.component(.month, from: date)
    let d = c.component(.day, from: date)
    return String(format: "%04d-%02d-%02d", y, m, d)
  }

  static func monthLabel(_ key: String) -> String {
    let parts = key.split(separator: "-")
    guard parts.count == 2,
          let y = Int(parts[0]),
          let m = Int(parts[1]),
          (1...12).contains(m)
    else { return key }
    let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return "\(names[m - 1]) \(y)"
  }

  /// Convert timestamptz ISO from server → local `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM`.
  /// All-day plans never have a clock time.
  static func fromTimestamptz(_ value: String?, allDay: Bool) -> String? {
    guard let value, let date = parseServerDate(value) else { return nil }
    let day = todayISO(date)
    if allDay { return day }
    let c = Calendar.current
    let h = c.component(.hour, from: date)
    let min = c.component(.minute, from: date)
    return String(format: "%@T%02d:%02d", day, h, min)
  }

  static func toTimestamptz(_ local: String) -> String {
    let parts = local.split(separator: "T", maxSplits: 1).map(String.init)
    let day = parts[0]
    if parts.count < 2 || parts[1].isEmpty {
      return "\(day)T12:00:00Z"
    }
    let time = parts[1]
    let dp = day.split(separator: "-").compactMap { Int($0) }
    let tp = time.split(separator: ":").compactMap { Int($0) }
    guard dp.count == 3 else { return local }
    var comps = DateComponents()
    comps.year = dp[0]
    comps.month = dp[1]
    comps.day = dp[2]
    comps.hour = tp.count > 0 ? tp[0] : 0
    comps.minute = tp.count > 1 ? tp[1] : 0
    let date = Calendar.current.date(from: comps) ?? Date()
    return ISO8601DateFormatter().string(from: date)
  }

  static func dtDate(_ value: String?) -> String? {
    guard let value, value.count >= 10 else { return nil }
    return String(value.prefix(10))
  }

  static func dtTime(_ value: String?) -> String? {
    guard let value, value.count > 10 else { return nil }
    let start = value.index(value.startIndex, offsetBy: 11)
    let end = value.index(start, offsetBy: min(5, value.distance(from: start, to: value.endIndex)))
    return String(value[start..<end])
  }

  /// Match PWA `describePlan` — weekday + month + day, optional From / Until / span.
  static func describePlan(_ dateTime: String, endsAt: String?) -> String {
    guard let start = parseLocalDay(dateTime) else { return dateTime }
    let df = DateFormatter()
    df.dateFormat = "EEEE, MMMM d"
    let long = df.string(from: start)
    let sTime = dtTime(dateTime)

    if let endsAt,
       let endDayStr = dtDate(endsAt),
       let startDay = dtDate(dateTime),
       let end = parseLocalDay(endsAt)
    {
      let eTime = dtTime(endsAt)
      if endDayStr != startDay {
        let nights = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        let unit = nights == 1 ? "night" : "nights"
        let left = sTime.map { "\(long) at \(prettyTime($0))" } ?? long
        let rightBase = df.string(from: end)
        let right = eTime.map { "\(rightBase) at \(prettyTime($0))" } ?? rightBase
        return "\(left) – \(right) · \(nights) \(unit)"
      }
      if let sTime, let eTime {
        return "\(long), \(prettyTime(sTime)) – \(prettyTime(eTime))"
      }
      if let eTime, sTime == nil {
        return "\(long) until \(prettyTime(eTime))"
      }
      if let sTime {
        return "\(long) at \(prettyTime(sTime))"
      }
    }

    if let sTime {
      return "\(long) at \(prettyTime(sTime))"
    }
    return "\(long), all day"
  }

  /// Compose day + optional From / Until + optional multi-day end (PWA `composeWhen`).
  static func composeWhen(
    date: String,
    from: String,
    until: String,
    endDate: String?
  ) -> (dateTime: String, endsAt: String?) {
    var fromT = from.trimmingCharacters(in: .whitespacesAndNewlines)
    var untilT = until.trimmingCharacters(in: .whitespacesAndNewlines)
    let end = (endDate != nil && endDate! > date) ? endDate : nil

    if end == nil, !fromT.isEmpty, !untilT.isEmpty, untilT < fromT {
      swap(&fromT, &untilT)
    }

    let dateTime = fromT.isEmpty ? date : "\(date)T\(fromT)"
    if let end {
      return (dateTime, untilT.isEmpty ? end : "\(end)T\(untilT)")
    }
    if !untilT.isEmpty {
      return (dateTime, "\(date)T\(untilT)")
    }
    return (dateTime, nil)
  }

  static func prettyTime(_ hhmm: String) -> String {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard let hRaw = parts.first else { return hhmm }
    let m = parts.count > 1 ? parts[1] : 0
    let ampm = hRaw >= 12 ? "PM" : "AM"
    let h = hRaw % 12 == 0 ? 12 : hRaw % 12
    return String(format: "%d:%02d %@", h, m, ampm)
  }

  /// Apple Calendar's Next Half-Hour Rule for default start time:
  /// - Never schedules in the past or mid-minute.
  /// - Always rounds up to the next clean half-hour block (:00 or :30).
  /// - Cutoff buffer: if the current minute is exactly on a half-hour mark
  ///   (e.g. 10:00 or 10:30), it assumes a typing buffer is needed and pushes
  ///   forward by 30 minutes (e.g. 10:00 -> 10:30, 10:30 -> 11:00).
  /// - Returns 24h "HH:MM".
  static func defaultAppleStartTime(now: Date = Date()) -> String {
    let c = Calendar.current
    let h = c.component(.hour, from: now)
    let m = c.component(.minute, from: now)
    var targetH = h
    var targetM = 0
    if m < 30 {
      targetM = 30
    } else {
      targetH = (targetH + 1) % 24
      targetM = 0
    }
    return String(format: "%02d:%02d", targetH, targetM)
  }

  /// Apple Calendar's standard 1-hour duration rule:
  /// Defaults end time to 1 hour after the start time.
  static func defaultAppleEndTime(from: String) -> String {
    guard !from.isEmpty else { return defaultAppleStartTime() }
    let parts = from.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return from }
    let h = parts[0]
    let m = parts[1]
    let endH = (h + 1) % 24
    return String(format: "%02d:%02d", endH, m)
  }

  static func parseLocalDay(_ value: String) -> Date? {
    let day = String(value.prefix(10))
    let dp = day.split(separator: "-").compactMap { Int($0) }
    guard dp.count == 3 else { return nil }
    var comps = DateComponents()
    comps.year = dp[0]
    comps.month = dp[1]
    comps.day = dp[2]
    return Calendar.current.date(from: comps)
  }

  private static func parseServerDate(_ value: String) -> Date? {
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: value) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    if let d = f2.date(from: value) { return d }
    return nil
  }

  static func searchDateTitle(_ dateISO: String) -> String {
    guard let date = parseLocalDay(String(dateISO.prefix(10))) else {
      return String(dateISO.prefix(10))
    }
    let f = DateFormatter()
    let currentYear = Calendar.current.component(.year, from: Date())
    let year = Calendar.current.component(.year, from: date)
    if year == currentYear {
      f.dateFormat = "EEEE – MMM d"
    } else {
      f.dateFormat = "EEEE – MMM d, yyyy"
    }
    return f.string(from: date)
  }

  static func formatItemTime(dateTime: String?, endsAt: String?) -> String {
    guard let dt = dateTime else { return "" }
    guard let sTime = dtTime(dt) else { return "All day" }
    let eTime = endsAt.flatMap { dtTime($0) }
    if let eTime, eTime != sTime {
      return "\(prettyTime(sTime)) – \(prettyTime(eTime))"
    }
    return prettyTime(sTime)
  }
}

extension ActivityRow {
  func asActivity() -> Activity {
    let allDay = all_day ?? ((date_time?.count ?? 0) <= 10)
    let suggestedAllDay = suggested_all_day ?? false
    return Activity(
      id: id,
      spaceId: space_id,
      title: title,
      description: description,
      imageUrl: image_url,
      createdBy: created_by,
      dateTime: DateLocal.fromTimestamptz(date_time, allDay: allDay),
      endsAt: DateLocal.fromTimestamptz(ends_at, allDay: allDay),
      allDay: allDay,
      suggestedDateTime: DateLocal.fromTimestamptz(suggested_date_time, allDay: suggestedAllDay),
      suggestedEndsAt: DateLocal.fromTimestamptz(suggested_ends_at, allDay: suggestedAllDay),
      suggestedAllDay: suggestedAllDay,
      suggestedBy: suggested_by,
      suggestedAt: suggested_at,
      suggestedNote: suggested_note,
      createdAt: created_at
    )
  }
}

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}
