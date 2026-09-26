import EventKit
import Foundation

struct DeviceCalendar: Identifiable, Hashable {
  let id: String
  let summary: String
  let primary: Bool
}

struct ImportedEventDraft {
  var sourceId: String
  var title: String?
  var location: String?
  var startsAt: String
  var endsAt: String
  var allDay: Bool
  var calendar: String
}

enum CalendarSync {
  static let store = EKEventStore()

  private static let connectedKey = "fordays.appleConnected"
  private static let calendarsKey = "fordays.appleCalendars"
  private static let syncedKey = "fordays.appleSynced"
  // The first version kept one calendar; it becomes a list of one.
  private static let legacyIdKey = "fordays.appleCalendarId"
  private static let legacyNameKey = "fordays.appleCalendarName"

  static var isConnected: Bool {
    UserDefaults.standard.bool(forKey: connectedKey)
  }

  /// The ticked calendars, as [id: name].
  static var chosen: [DeviceCalendar] {
    let d = UserDefaults.standard
    if let saved = d.array(forKey: calendarsKey) as? [[String: String]] {
      return saved.compactMap { row in
        guard let id = row["id"], let name = row["name"] else { return nil }
        return DeviceCalendar(id: id, summary: name, primary: false)
      }
    }
    if let id = d.string(forKey: legacyIdKey) {
      let one = DeviceCalendar(id: id, summary: d.string(forKey: legacyNameKey) ?? "Apple", primary: false)
      choose([one])
      return [one]
    }
    return []
  }

  static func choose(_ list: [DeviceCalendar]) {
    let d = UserDefaults.standard
    d.removeObject(forKey: legacyIdKey)
    d.removeObject(forKey: legacyNameKey)
    if list.isEmpty {
      d.removeObject(forKey: calendarsKey)
      d.removeObject(forKey: syncedKey)
      return
    }
    d.set(list.map { ["id": $0.id, "name": $0.summary] }, forKey: calendarsKey)
    d.set(true, forKey: connectedKey)
  }

  static func setConnected(_ on: Bool) {
    UserDefaults.standard.set(on, forKey: connectedKey)
    if !on { choose([]) }
  }

  /// When Apple last synced, and how many events each calendar brought.
  static var lastSynced: (at: Date, counts: [String: Int])? {
    guard let row = UserDefaults.standard.dictionary(forKey: syncedKey),
          let at = row["at"] as? Double else { return nil }
    return (Date(timeIntervalSince1970: at), row["counts"] as? [String: Int] ?? [:])
  }

  static func markSynced(_ counts: [String: Int]) {
    UserDefaults.standard.set(
      ["at": Date().timeIntervalSince1970, "counts": counts],
      forKey: syncedKey
    )
  }

  static var hasFullAccess: Bool {
    EKEventStore.authorizationStatus(for: .event) == .fullAccess
  }

  static func requestAccess() async -> Bool {
    do {
      return try await store.requestFullAccessToEvents()
    } catch {
      return false
    }
  }

  static func listCalendars() -> [DeviceCalendar] {
    let def = store.defaultCalendarForNewEvents?.calendarIdentifier
    var list = store.calendars(for: .event).map { cal in
      DeviceCalendar(
        id: cal.calendarIdentifier,
        summary: cal.title,
        primary: cal.calendarIdentifier == def
      )
    }
    list.sort {
      if $0.primary != $1.primary { return $0.primary }
      return $0.summary.localizedCaseInsensitiveCompare($1.summary) == .orderedAscending
    }
    return list
  }

  /// One calendar's events, a month back to six months ahead. Cancelled
  /// ones, and invites you said no to, aren't in your day.
  static func fetchEvents(calendarId: String) -> [ImportedEventDraft] {
    let calendars = store.calendars(for: .event).filter { $0.calendarIdentifier == calendarId }
    guard !calendars.isEmpty else { return [] }

    let cal = Calendar.current
    let start = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    let end = cal.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
    let events = store.events(matching: predicate)
    let label = calendars.first?.title ?? "Apple"

    let drafts: [ImportedEventDraft] = events.compactMap { ev in
      if ev.status == .canceled { return nil }
      if ev.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true {
        return nil
      }
      let baseId = ev.eventIdentifier ?? ev.calendarItemIdentifier
      guard !baseId.isEmpty else { return nil }
      let allDay = ev.isAllDay
      var endsAt = localStamp(ev.endDate, allDay: allDay)
      let startsAt = localStamp(ev.startDate, allDay: allDay)
      if allDay, endsAt > startsAt {
        if let pulled = cal.date(byAdding: .day, value: -1, to: ev.endDate) {
          endsAt = localStamp(pulled, allDay: true)
        }
      }
      // Occurrences of a repeating event share an identifier; the start tells them apart.
      let sourceId = "\(baseId)_\(startsAt)"
      let place = ev.location?.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return ImportedEventDraft(
        sourceId: sourceId,
        title: ev.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
          ? ev.title
          : "Busy",
        location: (place?.isEmpty == false) ? place : nil,
        startsAt: startsAt,
        endsAt: endsAt,
        allDay: allDay,
        calendar: label
      )
    }

    var seen = Set<String>()
    var unique: [ImportedEventDraft] = []
    for draft in drafts.reversed() where seen.insert(draft.sourceId).inserted {
      unique.append(draft)
    }
    return Array(unique.reversed())
  }

  private static func localStamp(_ date: Date, allDay: Bool) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let y = c.year ?? 1970
    let m = c.month ?? 1
    let d = c.day ?? 1
    if allDay {
      return String(format: "%04d-%02d-%02d", y, m, d)
    }
    return String(format: "%04d-%02d-%02dT%02d:%02d", y, m, d, c.hour ?? 0, c.minute ?? 0)
  }
}
