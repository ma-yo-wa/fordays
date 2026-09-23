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
  private static let calendarIdKey = "fordays.appleCalendarId"
  private static let calendarNameKey = "fordays.appleCalendarName"

  static var isConnected: Bool {
    UserDefaults.standard.bool(forKey: connectedKey)
  }

  static var selectedId: String? {
    UserDefaults.standard.string(forKey: calendarIdKey)
  }

  static var selectedName: String? {
    UserDefaults.standard.string(forKey: calendarNameKey)
  }

  static func setConnected(_ on: Bool) {
    UserDefaults.standard.set(on, forKey: connectedKey)
    if !on {
      UserDefaults.standard.removeObject(forKey: calendarIdKey)
      UserDefaults.standard.removeObject(forKey: calendarNameKey)
    }
  }

  static func saveCalendar(_ cal: DeviceCalendar?) {
    if let cal {
      UserDefaults.standard.set(cal.id, forKey: calendarIdKey)
      UserDefaults.standard.set(cal.summary, forKey: calendarNameKey)
      UserDefaults.standard.set(true, forKey: connectedKey)
    } else {
      UserDefaults.standard.removeObject(forKey: calendarIdKey)
      UserDefaults.standard.removeObject(forKey: calendarNameKey)
    }
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

  static func fetchEvents() -> [ImportedEventDraft] {
    guard let selectedId else { return [] }
    let calendars = store.calendars(for: .event).filter { $0.calendarIdentifier == selectedId }
    guard !calendars.isEmpty else { return [] }

    let cal = Calendar.current
    let start = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    let end = cal.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
    let events = store.events(matching: predicate)
    let label = selectedName ?? calendars.first?.title ?? "Apple"

    let drafts: [ImportedEventDraft] = events.compactMap { ev in
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
      // Recurring events share the same base event identifier in EventKit.
      // We append startsAt to ensure all occurrences get a unique ID, but we should make sure we always include it.
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
        calendar: ev.calendar?.title ?? label
      )
    }

    var seen = Set<String>()
    var unique: [ImportedEventDraft] = []
    // Reverse the drafts so that if there are duplicates with the exact same ID + StartsAt,
    // we keep the later/more recently updated one, though they should be identical.
    for draft in drafts.reversed() {
      if seen.insert(draft.sourceId).inserted {
        unique.append(draft)
      }
    }
    return unique.reversed()
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
