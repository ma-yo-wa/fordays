import Foundation

struct Activity: Identifiable, Hashable, Codable {
  var id: String
  var spaceId: String?
  var title: String
  var description: String?
  var imageUrl: String?
  var createdBy: String
  /// Local `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM`. Nil = bucket item.
  var dateTime: String?
  var endsAt: String?
  var allDay: Bool
  var suggestedDateTime: String?
  var suggestedEndsAt: String?
  var suggestedAllDay: Bool
  var suggestedBy: String?
  var suggestedAt: String?
  var suggestedNote: String?
  var createdAt: String

  var isPlan: Bool { dateTime != nil }
  var isBucketItem: Bool { dateTime == nil }

  func isMemory(today: String) -> Bool {
    guard let dateTime else { return false }
    let last = (endsAt ?? dateTime).prefix(10)
    return String(last) < today
  }

  var monthKey: String? {
    guard let dateTime else { return nil }
    return String((endsAt ?? dateTime).prefix(7))
  }
}

struct SpaceMember: Hashable {
  var id: String
  var name: String
  var role: String
}

struct SpaceInfo: Hashable {
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

  var peopleLabel: String {
    let others = members.filter { $0.id != myId }
    if others.isEmpty {
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty && trimmed.caseInsensitiveCompare("Fordays") != .orderedSame && trimmed.caseInsensitiveCompare("Someday") != .orderedSame {
        return trimmed
      }
      return "Just you"
    }
    if others.count == 1 { return others[0].name }
    if others.count == 2 { return "\(others[0].name) and \(others[1].name)" }
    return others.map(\.name).joined(separator: ", ")
  }

  func displayName(for userId: String) -> String {
    if userId.compare(myId, options: .caseInsensitive) == .orderedSame { return myName }
    if let named = members.first(where: { $0.id.compare(userId, options: .caseInsensitive) == .orderedSame }) {
      return named.name
    }
    return partnerName ?? "Them"
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
    case .bucket: return "Bucket List"
    case .plans: return "Plans"
    case .memories: return "Memories"
    }
  }
}

struct NewActivityInsert: Encodable {
  let space_id: String
  let title: String
  let description: String?
  let image_url: String?
  let created_by: String
  let date_time: String?
  let ends_at: String?
  let all_day: Bool
}

struct NewSpaceInsert: Encodable {
  let partner_1_id: String
  let name: String
}

struct ProfileNameUpdate: Encodable {
  let display_name: String
}

struct JoinCode: Encodable {
  let code: String
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

  enum CodingKeys: String, CodingKey {
    case id
    case spaceId = "space_id"
    case userId = "user_id"
    case title
    case location
    case startsAt = "starts_at"
    case endsAt = "ends_at"
    case allDay = "all_day"
    case calendar
  }
}

struct PlanDraft: Hashable {
  var title: String?
  var notes: String?
  var date: String?
  var from: String?
  var until: String?
  var end: String?
  var multiDay: Bool?

  static func from(external: ExternalEvent) -> PlanDraft {
    let startDate = String(external.startsAt.prefix(10))
    let rawEnd = external.endsAt.isEmpty ? nil : String(external.endsAt.prefix(10))
    let isMulti = rawEnd != nil && (rawEnd ?? "") > startDate
    let startTime = external.allDay ? "" : (external.startsAt.count > 10 ? String(external.startsAt.dropFirst(11).prefix(5)) : "")
    let endTime = external.allDay ? "" : (external.endsAt.count > 10 ? String(external.endsAt.dropFirst(11).prefix(5)) : "")
    let notes = (external.location?.isEmpty == false) ? "Location: \(external.location!)" : nil

    return PlanDraft(
      title: external.title,
      notes: notes,
      date: startDate,
      from: startTime,
      until: endTime,
      end: isMulti ? rawEnd : nil,
      multiDay: isMulti
    )
  }
}
