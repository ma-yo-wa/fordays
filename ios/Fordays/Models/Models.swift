import Foundation

struct AuditLog: Identifiable, Hashable, Decodable {
  var id: String
  var activityId: String
  var userId: String
  var details: String
  var timestamp: String

  enum CodingKeys: String, CodingKey {
    case id
    case activityId = "activity_id"
    case userId = "user_id"
    case details
    case timestamp
  }
}

struct Activity: Identifiable, Hashable, Codable {
  var id: String
  var spaceId: String?
  var title: String
  var description: String?
  var location: String?
  var imageUrl: String?
  var createdBy: String
  /// Local `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM`. Nil = bucket item.
  var dateTime: String?
  var endsAt: String?
  var allDay: Bool
  var fromSomeday: Bool?
  var suggestedDateTime: String?
  var suggestedEndsAt: String?
  var suggestedAllDay: Bool
  var suggestedBy: String?
  var suggestedAt: String?
  var suggestedNote: String?
  var createdAt: String

  var isPlan: Bool { dateTime != nil }
  var isBucketItem: Bool { dateTime == nil }

  /// The last day a plan covers: its end day when it has a real one, else its start.
  var lastDay: String? {
    guard let dateTime else { return nil }
    let end = (endsAt?.trimmingCharacters(in: .whitespaces).count ?? 0) >= 10 ? endsAt! : dateTime
    return String(end.prefix(10))
  }

  func isMemory(today: String = DateLocal.todayISO()) -> Bool {
    guard let last = lastDay else { return false }
    if last >= today { return false }
    let hasCover = !(imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    return (fromSomeday == true) || hasCover
  }

  var monthKey: String? {
    lastDay.map { String($0.prefix(7)) }
  }
}

struct SpaceMember: Hashable, Codable {
  var id: String
  var name: String
  var role: String
}

struct SpaceInfo: Hashable, Codable {
  var id: String
  var name: String
  var inviteCode: String
  var frozen: Bool
  var forkedFrom: String?
  var partner1Id: String
  var partner2Id: String?
  var myId: String
  var myName: String
  var myRole: String
  var partnerName: String?
  var members: [SpaceMember]
  var me: Int

  var isMatched: Bool {
    if !members.isEmpty { return members.count >= 2 }
    return partner2Id != nil
  }

  var canCompose: Bool { !frozen }

  /// Notebook name, or empty if they haven’t named it.
  /// Fordays / Someday leftovers stay untitled. The solo default is their name.
  var peopleLabel: String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let generic = trimmed.isEmpty
      || trimmed.caseInsensitiveCompare("Fordays") == .orderedSame
      || trimmed.caseInsensitiveCompare("Someday") == .orderedSame
    return generic ? "" : trimmed
  }

  func displayName(for userId: String) -> String {
    if userId.compare(myId, options: .caseInsensitive) == .orderedSame { return myName }
    if let named = members.first(where: { $0.id.compare(userId, options: .caseInsensitive) == .orderedSame }) {
      return named.name
    }
    return partnerName ?? "Them"
  }

  /// Default title for the solo notebook: their name, first word only.
  static func soloTitle(from displayName: String) -> String {
    let word = displayName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    let lower = word.lowercased()
    if word.isEmpty || lower == "me" || lower == "you" || lower == "them" { return "" }
    return word
  }

  func isHomeSoloName() -> Bool {
    let raw = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if raw == "personal" { return true }
    let title = Self.soloTitle(from: myName).lowercased()
    return !title.isEmpty && raw == title
  }
}

enum AuthPhase: Equatable {
  case loading
  case signedOut
  case signedIn
}

enum HomeTab: String, CaseIterable, Identifiable {
  case bucket
  case plans
  case memories

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bucket: return Copy.Tabs.ideas
    case .plans: return Copy.Tabs.plans
    case .memories: return Copy.Tabs.memories
    }
  }
}

struct NewActivityInsert: Encodable {
  let space_id: String
  let title: String
  let description: String?
  let location: String?
  let image_url: String?
  let created_by: String
  let date_time: String?
  let ends_at: String?
  let all_day: Bool
  let from_someday: Bool?
}

struct NewSpaceInsert: Encodable {
  let partner_1_id: String
  let name: String
}

struct SpaceNameUpdate: Encodable {
  let name: String
}

struct ProfileNameUpdate: Encodable {
  let display_name: String
}

struct JoinCode: Encodable {
  let code: String
}

struct InvitePeek: Codable, Hashable {
  var spaceId: String
  var spaceName: String?
  var inviterName: String
  var isOpen: Bool

  enum CodingKeys: String, CodingKey {
    case spaceId = "space_id"
    case spaceName = "space_name"
    case inviterName = "inviter_name"
    case isOpen = "is_open"
  }
}

struct CreateSpaceParams: Encodable {
  let p_name: String
}

struct LeaveSpaceParams: Encodable {
  let sid: String
}

struct SpaceIdParams: Encodable {
  let sid: String
}

struct RemoveMemberParams: Encodable {
  let sid: String
  let uid: String
}

struct ExternalEvent: Identifiable, Hashable, Codable {
  var id: String
  var spaceId: String?
  var userId: String
  var title: String?
  var location: String?
  var startsAt: String
  var endsAt: String
  var allDay: Bool
  var calendar: String
  var source: String
  var sharedWithSpace: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case spaceId = "space_id"
    case ownerId = "owner_id"
    case userId = "user_id"
    case title
    case location
    case startsAt = "starts_at"
    case endsAt = "ends_at"
    case allDay = "all_day"
    case calendarName = "calendar_name"
    case calendar
    case calendarSource = "calendar_source"
    case sharedWithSpace = "shared_with_space"
  }

  init(
    id: String,
    spaceId: String? = nil,
    userId: String,
    title: String? = nil,
    location: String? = nil,
    startsAt: String,
    endsAt: String,
    allDay: Bool,
    calendar: String,
    source: String = "google",
    sharedWithSpace: Bool = false
  ) {
    self.id = id
    self.spaceId = spaceId
    self.userId = userId
    self.title = title
    self.location = location
    self.startsAt = startsAt
    self.endsAt = endsAt
    self.allDay = allDay
    self.calendar = calendar
    self.source = source
    self.sharedWithSpace = sharedWithSpace
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    spaceId = try container.decodeIfPresent(String.self, forKey: .spaceId)
    userId = try container.decodeIfPresent(String.self, forKey: .ownerId)
      ?? container.decodeIfPresent(String.self, forKey: .userId)
      ?? ""
    title = try container.decodeIfPresent(String.self, forKey: .title)
    location = try container.decodeIfPresent(String.self, forKey: .location)
    startsAt = try container.decode(String.self, forKey: .startsAt)
    endsAt = try container.decode(String.self, forKey: .endsAt)
    allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
    calendar = try container.decodeIfPresent(String.self, forKey: .calendarName)
      ?? container.decodeIfPresent(String.self, forKey: .calendar)
      ?? "Google"
    source = try container.decodeIfPresent(String.self, forKey: .calendarSource) ?? "google"
    sharedWithSpace = try container.decodeIfPresent(Bool.self, forKey: .sharedWithSpace) ?? false
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(spaceId, forKey: .spaceId)
    try container.encode(userId, forKey: .ownerId)
    try container.encodeIfPresent(title, forKey: .title)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encode(startsAt, forKey: .startsAt)
    try container.encode(endsAt, forKey: .endsAt)
    try container.encode(allDay, forKey: .allDay)
    try container.encode(calendar, forKey: .calendarName)
    try container.encode(source, forKey: .calendarSource)
    try container.encode(sharedWithSpace, forKey: .sharedWithSpace)
  }

  func isFutureOrToday(today: String) -> Bool {
    let last = endsAt.isEmpty ? String(startsAt.prefix(10)) : String(endsAt.prefix(10))
    return last >= today
  }

  var sourceLabel: String {
    switch source {
    case "apple": return Copy.Availability.apple
    case "outlook": return Copy.Availability.outlook
    default: return Copy.Availability.google
    }
  }
}

struct PlanDraft: Hashable {
  var title: String?
  var notes: String?
  var location: String?
  var cover: String?
  var date: String?
  var from: String?
  var until: String?
  var end: String?
  var multiDay: Bool?
  /// Do again carries the memory's Someday origin into the new copy.
  var fromSomeday: Bool? = nil

  static func from(external: ExternalEvent) -> PlanDraft {
    let startDate = String(external.startsAt.prefix(10))
    let rawEnd = external.endsAt.isEmpty ? nil : String(external.endsAt.prefix(10))
    let isMulti = rawEnd != nil && (rawEnd ?? "") > startDate
    let startTime = external.allDay ? "" : (external.startsAt.count > 10 ? String(external.startsAt.dropFirst(11).prefix(5)) : "")
    let endTime = external.allDay ? "" : (external.endsAt.count > 10 ? String(external.endsAt.dropFirst(11).prefix(5)) : "")

    return PlanDraft(
      title: external.title,
      notes: nil,
      location: external.location,
      cover: nil,
      date: startDate,
      from: startTime,
      until: endTime,
      end: isMulti ? rawEnd : nil,
      multiDay: isMulti
    )
  }
}
