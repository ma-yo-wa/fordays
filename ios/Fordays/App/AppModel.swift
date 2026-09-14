import Foundation
import Supabase

@MainActor
final class AppModel: ObservableObject {
  @Published var authPhase: AuthPhase = .loading
  @Published var space: SpaceInfo?
  @Published var spaces: [SpaceInfo] = []
  @Published var activities: [Activity] = []
  @Published var externalEvents: [ExternalEvent] = []
  @Published var tab: HomeTab = .bucket
  @Published var cursorMonth: Date = Date()
  @Published var pickedDay: String = DateLocal.todayISO()
  @Published var errorMessage: String?
  @Published var toast: String?
  @Published var showJoinOrb: Bool = false

  func shiftMonth(by delta: Int) {
    cursorMonth = Calendar.current.date(byAdding: .month, value: delta, to: cursorMonth) ?? cursorMonth
  }

  func goToday() {
    pickedDay = DateLocal.todayISO()
    cursorMonth = Date()
  }

  private var sb: SupabaseClient { SupabaseService.shared.client }

  func boot() async {
    authPhase = .loading
    do {
      _ = try await sb.auth.session
      try await refreshSpaceAndData()
      authPhase = space == nil ? .signedOut : .signedIn
    } catch {
      authPhase = .signedOut
    }
  }

  func signIn(email: String, password: String) async {
    errorMessage = nil
    do {
      try await sb.auth.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        password: password
      )
      try await ensureSpace()
      try await refreshSpaceAndData()
      authPhase = .signedIn
    } catch {
      errorMessage = FordaysError.fromAuth(error).errorDescription
    }
  }

  func signUp(email: String, password: String, displayName: String) async {
    errorMessage = nil
    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorMessage = "Add a name — it shows on your avatar"
      return
    }
    do {
      let res = try await sb.auth.signUp(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        password: password,
        data: ["display_name": .string(name)]
      )
      guard res.session != nil else {
        errorMessage =
          "Account created, but email confirmation is still on in Supabase. Turn it off, then sign in."
        return
      }
      let uid = res.user.id.uuidString.lowercased()
      try await sb.from("profiles")
        .update(ProfileNameUpdate(display_name: name))
        .eq("id", value: uid)
        .execute()
      try await ensureSpace()
      try await refreshSpaceAndData()
      authPhase = .signedIn
    } catch {
      errorMessage = FordaysError.fromAuth(error).errorDescription
    }
  }

  func signOut() async {
    try? await sb.auth.signOut()
    space = nil
    spaces = []
    storedSpaceId = nil
    activities = []
    authPhase = .signedOut
  }

  func refreshActivities() async {
    guard let space else {
      activities = []
      externalEvents = []
      return
    }
    do {
      let rows: [ActivityRow] = try await sb.from("activities")
        .select()
        .eq("space_id", value: space.id)
        .order("created_at", ascending: false)
        .execute()
        .value
      activities = rows.map { $0.asActivity() }
    } catch {
      toast = error.localizedDescription
    }
    await refreshExternal()
  }

  func refreshExternal() async {
    guard let space else {
      externalEvents = []
      return
    }
    do {
      let rows: [ExternalEvent] = try await sb.from("external_events")
        .select()
        .eq("space_id", value: space.id)
        .order("starts_at", ascending: true)
        .execute()
        .value
      externalEvents = rows
    } catch {
      externalEvents = []
    }
  }

  func toggleExternalShare(event: ExternalEvent, shared: Bool) async {
    struct UpdateShare: Encodable {
      let shared_with_space: Bool
      let updated_at: String
    }
    do {
      try await sb.from("external_events")
        .update(UpdateShare(
          shared_with_space: shared,
          updated_at: ISO8601DateFormatter().string(from: Date())
        ))
        .eq("id", value: event.id)
        .execute()
      if let idx = externalEvents.firstIndex(where: { $0.id == event.id }) {
        externalEvents[idx].sharedWithSpace = shared
      }
      toast = shared ? Copy.Availability.sharedTitle : Copy.Availability.privateTitle
    } catch {
      toast = error.localizedDescription
    }
  }

  func createActivity(
    title: String,
    description: String? = nil,
    imageUrl: String? = nil,
    dateTime: String? = nil,
    endsAt: String? = nil
  ) async {
    guard let space else { return }
    guard space.canCompose else {
      toast = "This is a copy from when you left — it can’t take new plans"
      return
    }
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      toast = "Give it a name"
      return
    }
    do {
      let session = try await sb.auth.session
      let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
      let cover = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
      let insert = NewActivityInsert(
        space_id: space.id,
        title: trimmed,
        description: (desc?.isEmpty == false) ? desc : nil,
        image_url: (cover?.isEmpty == false) ? cover : nil,
        created_by: session.user.id.uuidString.lowercased(),
        date_time: dateTime.map(DateLocal.toTimestamptz),
        ends_at: endsAt.map(DateLocal.toTimestamptz),
        all_day: dateTime == nil || (dateTime?.count ?? 0) <= 10
      )
      try await sb.from("activities").insert(insert).execute()
      await refreshActivities()
      tab = dateTime == nil ? .bucket : .plans
      toast = dateTime == nil ? "Added an idea" : "Made it a plan"
    } catch {
      toast = error.localizedDescription
    }
  }

  func deleteActivity(_ id: String) async {
    guard space?.canCompose == true else {
      toast = "This is a copy from when you left"
      return
    }
    do {
      try await sb.from("activities").delete().eq("id", value: id).execute()
      activities.removeAll { $0.id == id }
    } catch {
      toast = error.localizedDescription
    }
  }

  /// Patch fields like the PWA `backend.patch`.
  /// Pass `.some(nil)` for `dateTime` / `endsAt` to clear those columns.
  func patchActivity(
    _ id: String,
    title: String? = nil,
    description: String? = nil,
    imageUrl: String? = nil,
    dateTime: String?? = nil,
    endsAt: String?? = nil
  ) async {
    guard space?.canCompose == true else {
      toast = "This is a copy from when you left"
      return
    }
    do {
      var patch: [String: AnyJSON] = [:]
      if let title { patch["title"] = .string(title) }
      if let description {
        patch["description"] = description.isEmpty ? .null : .string(description)
      }
      if let imageUrl {
        patch["image_url"] = imageUrl.isEmpty ? .null : .string(imageUrl)
      }
      if let dateOpt = dateTime {
        clearSuggestion(&patch)
        if let value = dateOpt {
          patch["date_time"] = .string(DateLocal.toTimestamptz(value))
          patch["all_day"] = .bool(value.count <= 10)
        } else {
          patch["date_time"] = .null
          patch["ends_at"] = .null
          patch["all_day"] = .bool(true)
        }
      }
      if let endOpt = endsAt {
        if let value = endOpt {
          patch["ends_at"] = .string(DateLocal.toTimestamptz(value))
        } else {
          patch["ends_at"] = .null
        }
      }
      guard !patch.isEmpty else { return }
      try await sb.from("activities").update(patch).eq("id", value: id).execute()
      await refreshActivities()
    } catch {
      toast = error.localizedDescription
    }
  }

  private func clearSuggestion(_ patch: inout [String: AnyJSON]) {
    patch["suggested_date_time"] = .null
    patch["suggested_ends_at"] = .null
    patch["suggested_all_day"] = .bool(false)
    patch["suggested_by"] = .null
    patch["suggested_at"] = .null
    patch["suggested_note"] = .null
  }

  func moveToBucket(_ id: String) async {
    await patchActivity(id, dateTime: .some(nil), endsAt: .some(nil))
    toast = "Back in Ideas"
    tab = .bucket
  }

  func suggestWhen(
    _ id: String,
    dateTime: String,
    endsAt: String?,
    note: String?
  ) async {
    guard space?.isMatched == true, space?.canCompose == true else {
      toast = "Suggest a date when someone else is in this Orb"
      return
    }
    do {
      let session = try await sb.auth.session
      let allDay = dateTime.count <= 10
      let patch: [String: AnyJSON] = [
        "suggested_date_time": .string(DateLocal.toTimestamptz(dateTime)),
        "suggested_ends_at": endsAt.map { .string(DateLocal.toTimestamptz($0)) } ?? .null,
        "suggested_all_day": .bool(allDay),
        "suggested_by": .string(session.user.id.uuidString.lowercased()),
        "suggested_at": .string(ISO8601DateFormatter().string(from: Date())),
        "suggested_note": {
          let n = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          return n.isEmpty ? .null : .string(n)
        }(),
      ]
      try await sb.from("activities").update(patch).eq("id", value: id).execute()
      await refreshActivities()
      toast = "Suggested"
    } catch {
      toast = error.localizedDescription
    }
  }

  func acceptSuggestion(_ id: String) async {
    guard space?.canCompose == true else {
      toast = "This is a copy from when you left"
      return
    }
    do {
      struct Sug: Decodable {
        let suggested_date_time: String?
        let suggested_ends_at: String?
        let suggested_all_day: Bool?
      }
      let rows: [Sug] = try await sb.from("activities")
        .select("suggested_date_time, suggested_ends_at, suggested_all_day")
        .eq("id", value: id)
        .limit(1)
        .execute()
        .value
      guard let data = rows.first, let when = data.suggested_date_time else {
        toast = "That suggestion is gone — ask them to send it again"
        return
      }
      let patch: [String: AnyJSON] = [
        "date_time": .string(when),
        "ends_at": data.suggested_ends_at.map { .string($0) } ?? .null,
        "all_day": .bool(data.suggested_all_day ?? false),
        "suggested_date_time": .null,
        "suggested_ends_at": .null,
        "suggested_all_day": .bool(false),
        "suggested_by": .null,
        "suggested_at": .null,
        "suggested_note": .null,
      ]
      try await sb.from("activities").update(patch).eq("id", value: id).execute()
      await refreshActivities()
      toast = "Locked in"
      tab = .plans
    } catch {
      toast = error.localizedDescription
    }
  }

  func dismissSuggestion(_ id: String) async {
    guard space?.canCompose == true else {
      toast = "This is a copy from when you left"
      return
    }
    do {
      let patch: [String: AnyJSON] = [
        "suggested_date_time": .null,
        "suggested_ends_at": .null,
        "suggested_all_day": .bool(false),
        "suggested_by": .null,
        "suggested_at": .null,
        "suggested_note": .null,
      ]
      try await sb.from("activities").update(patch).eq("id", value: id).execute()
      await refreshActivities()
      toast = "Dismissed"
    } catch {
      toast = error.localizedDescription
    }
  }

  func activity(id: String) -> Activity? {
    activities.first { $0.id == id }
  }

  func handleOpenURL(_ url: URL) async {
    if url.absoluteString.contains("auth/callback")
      || url.absoluteString.contains("access_token")
      || url.absoluteString.contains("code=")
    {
      do {
        try await sb.auth.session(from: url)
        try await refreshSpaceAndData()
        authPhase = space == nil ? .signedOut : .signedIn
      } catch {
        errorMessage = FordaysError.fromAuth(error).errorDescription
      }
      return
    }
    if let code = inviteCode(from: url) {
      do {
        try await joinInvite(code)
        toast = "You’re in"
      } catch {
        toast = error.localizedDescription
      }
    }
  }

  func extractInviteCode(from string: String) -> String {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    if let range = trimmed.range(of: #"[?&]invite=([a-zA-Z0-9]+)"#, options: .regularExpression) {
      let matched = String(trimmed[range])
      if let eqIdx = matched.firstIndex(of: "=") {
        return String(matched[matched.index(after: eqIdx)...]).lowercased()
      }
    }
    if let range = trimmed.range(of: #"/invite/([a-zA-Z0-9]+)"#, options: .regularExpression) {
      let matched = String(trimmed[range])
      if let slashIdx = matched.lastIndex(of: "/") {
        return String(matched[matched.index(after: slashIdx)...]).lowercased()
      }
    }
    return trimmed.filter { $0.isLetter || $0.isNumber }.lowercased()
  }

  func peekInvite(_ code: String) async throws -> InvitePeek? {
    let cleaned = extractInviteCode(from: code)
    guard !cleaned.isEmpty else { return nil }
    let list: [InvitePeek] = try await sb.rpc("peek_invite", params: JoinCode(code: cleaned)).execute().value
    return list.first
  }

  func joinInvite(_ code: String) async throws {
    let cleaned = extractInviteCode(from: code)
    guard !cleaned.isEmpty else {
      throw FordaysError.message("That invite link is missing a code")
    }
    do {
      let joined: SpaceRow = try await sb.rpc("join_space", params: JoinCode(code: cleaned)).execute().value
      storedSpaceId = joined.id
    } catch {
      try await sb.rpc("join_space", params: JoinCode(code: cleaned)).execute()
    }
    try await refreshSpaceAndData()
    authPhase = .signedIn
    let name = space?.peopleLabel ?? "Orb"
    toast = Copy.Invite.joinedSuccess(name)
  }

  func switchToSpace(_ id: String) async {
    storedSpaceId = id
    do {
      try await refreshSpaceAndData()
      if space?.frozen == true {
        toast = "This is a copy from when you left"
      }
    } catch {
      toast = error.localizedDescription
    }
  }

  func addSpace() async {
    do {
      let created: SpaceRow = try await sb.rpc(
        "create_space",
        params: CreateSpaceParams(p_name: Theme.brandName)
      ).execute().value
      storedSpaceId = created.id
      try await refreshSpaceAndData()
      toast = "New Orb — just you, until you invite"
    } catch {
      toast = error.localizedDescription
    }
  }

  func leaveCurrentSpace() async {
    guard let current = space else { return }
    do {
      _ = try await sb.rpc("leave_space", params: SpaceIdParams(sid: current.id)).execute()
      let list = try await loadSpaces()
      spaces = list
      let active = list.filter { !$0.frozen }
      if let next = active.first {
        storedSpaceId = next.id
        space = next
        await refreshActivities()
      } else {
        try await ensureSpace()
        try await refreshSpaceAndData()
      }
      toast = "Saved to Past Orbs"
    } catch {
      toast = error.localizedDescription
    }
  }

  func restorePastOrb(_ spaceId: String) async {
    do {
      _ = try await sb.rpc("restore_space", params: SpaceIdParams(sid: spaceId)).execute()
      let list = try await loadSpaces()
      spaces = list
      if let restored = list.first(where: { $0.id == spaceId }) {
        storedSpaceId = restored.id
        space = restored
        await refreshActivities()
      }
      toast = "Orb restored to active"
    } catch {
      toast = error.localizedDescription
    }
  }

  func deletePastOrb(_ spaceId: String) async {
    do {
      _ = try await sb.rpc("delete_frozen_space", params: SpaceIdParams(sid: spaceId)).execute()
      let list = try await loadSpaces()
      spaces = list
      if space?.id == spaceId {
        let active = list.filter { !$0.frozen }
        if let next = active.first {
          storedSpaceId = next.id
          space = next
          await refreshActivities()
        } else {
          try await ensureSpace()
          try await refreshSpaceAndData()
        }
      }
      toast = "Orb permanently deleted"
    } catch {
      toast = error.localizedDescription
    }
  }

  func removeMember(userId: String) async {
    guard let current = space else { return }
    do {
      try await sb.rpc(
        "remove_space_member",
        params: RemoveMemberParams(sid: current.id, uid: userId)
      ).execute()
      try await refreshSpaceAndData()
    } catch {
      toast = error.localizedDescription
    }
  }

  private var storedSpaceId: String? {
    get { UserDefaults.standard.string(forKey: "fordays.spaceId") }
    set { UserDefaults.standard.set(newValue, forKey: "fordays.spaceId") }
  }

  private func refreshSpaceAndData() async throws {
    let list = try await loadSpaces()
    spaces = list
    let saved = storedSpaceId
    space = list.first(where: { $0.id == saved }) ?? list.first
    if let space { storedSpaceId = space.id }
    if space != nil {
      await refreshActivities()
    } else {
      activities = []
    }
  }

  private func loadSpaces() async throws -> [SpaceInfo] {
    let session = try await sb.auth.session
    let uid = session.user.id.uuidString.lowercased()
    do {
      return try await loadSpacesFromMembers(uid: uid, session: session)
    } catch {
      if let one = try await loadSpaceLegacy(uid: uid, session: session) {
        return [one]
      }
      return []
    }
  }

  private func loadSpacesFromMembers(uid: String, session: Session) async throws -> [SpaceInfo] {
    let memberships: [SpaceMemberRow] = try await sb.from("space_members")
      .select("space_id, user_id, role")
      .eq("user_id", value: uid)
      .execute()
      .value

    let ids = memberships.map(\.space_id)
    guard !ids.isEmpty else { return [] }

    let rows: [SpaceRow] = try await sb.from("spaces")
      .select("id, name, invite_code, partner_1_id, partner_2_id, frozen, forked_from")
      .in("id", values: ids)
      .execute()
      .value

    let allMembers: [SpaceMemberRow] = try await sb.from("space_members")
      .select("space_id, user_id, role")
      .in("space_id", values: ids)
      .execute()
      .value

    let userIds = Array(Set(allMembers.map { $0.user_id.lowercased() }))
    let profiles: [ProfileRow] = try await sb.from("profiles")
      .select("id, display_name")
      .in("id", values: userIds.isEmpty ? [uid] : userIds)
      .execute()
      .value

    let meta = session.user.userMetadata
    let metaName =
      meta["display_name"]?.stringValue
      ?? meta["full_name"]?.stringValue
      ?? meta["name"]?.stringValue

    func nameOf(_ id: String) -> String {
      let fromProfile = profiles
        .first(where: { $0.id.lowercased() == id.lowercased() })?
        .display_name?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if let fromProfile, !fromProfile.isEmpty { return fromProfile }
      if id.lowercased() == uid, let metaName, !metaName.isEmpty { return metaName }
      return id.lowercased() == uid ? "Me" : "Them"
    }

    let list = rows.map { row in
      hydrateSpace(row, uid: uid, myName: nameOf(uid), nameOf: nameOf, allMembers: allMembers, myMemberships: memberships)
    }
    return list.sorted {
      if $0.frozen != $1.frozen { return !$0.frozen && $1.frozen }
      return $0.peopleLabel.localizedCaseInsensitiveCompare($1.peopleLabel) == .orderedAscending
    }
  }

  private func hydrateSpace(
    _ space: SpaceRow,
    uid: String,
    myName: String,
    nameOf: (String) -> String,
    allMembers: [SpaceMemberRow],
    myMemberships: [SpaceMemberRow]
  ) -> SpaceInfo {
    let mine = allMembers.filter { $0.space_id == space.id }
    let members = mine.map {
      SpaceMember(id: $0.user_id.lowercased(), name: nameOf($0.user_id), role: $0.role)
    }
    let others = members.filter { $0.id != uid }
    let myRole = myMemberships.first(where: { $0.space_id == space.id })?.role ?? "member"
    let partnerName: String? = {
      if others.count == 1 { return others[0].name }
      if others.isEmpty { return nil }
      return others.map(\.name).joined(separator: ", ")
    }()

    return SpaceInfo(
      id: space.id,
      name: space.name,
      inviteCode: space.invite_code,
      frozen: space.frozen ?? false,
      forkedFrom: space.forked_from,
      partner1Id: space.partner_1_id.lowercased(),
      partner2Id: space.partner_2_id?.lowercased(),
      myId: uid,
      myName: myName,
      myRole: myRole,
      partnerName: partnerName,
      members: members,
      me: 0
    )
  }

  private func loadSpaceLegacy(uid: String, session: Session) async throws -> SpaceInfo? {
    let spaces: [SpaceRow] = try await sb.from("spaces")
      .select("id, name, invite_code, partner_1_id, partner_2_id")
      .or("partner_1_id.eq.\(uid),partner_2_id.eq.\(uid)")
      .limit(1)
      .execute()
      .value

    guard let space = spaces.first else { return nil }

    let partnerId = space.partner_1_id.lowercased() == uid
      ? space.partner_2_id?.lowercased()
      : space.partner_1_id.lowercased()
    var ids = [space.partner_1_id.lowercased()]
    if let partnerId { ids.append(partnerId) }

    let profiles: [ProfileRow] = try await sb.from("profiles")
      .select("id, display_name")
      .in("id", values: ids)
      .execute()
      .value

    func nameOf(_ id: String?) -> String? {
      guard let id else { return nil }
      return profiles
        .first(where: { $0.id.lowercased() == id.lowercased() })?
        .display_name?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let meta = session.user.userMetadata
    let metaName =
      meta["display_name"]?.stringValue
      ?? meta["full_name"]?.stringValue
      ?? meta["name"]?.stringValue
    let myName = nameOf(uid) ?? metaName ?? "Me"
    var members = [
      SpaceMember(id: space.partner_1_id.lowercased(), name: nameOf(space.partner_1_id) ?? "Me", role: "admin")
    ]
    if let p2 = space.partner_2_id {
      members.append(SpaceMember(id: p2.lowercased(), name: nameOf(p2) ?? "Them", role: "member"))
    }

    return SpaceInfo(
      id: space.id,
      name: space.name,
      inviteCode: space.invite_code,
      frozen: false,
      forkedFrom: nil,
      partner1Id: space.partner_1_id.lowercased(),
      partner2Id: space.partner_2_id?.lowercased(),
      myId: uid,
      myName: myName,
      myRole: space.partner_1_id.lowercased() == uid ? "admin" : "member",
      partnerName: nameOf(partnerId),
      members: members,
      me: 0
    )
  }

  private func ensureSpace() async throws {
    if !(try await loadSpaces()).isEmpty { return }
    do {
      let created: SpaceRow = try await sb.rpc(
        "create_space",
        params: CreateSpaceParams(p_name: Theme.brandName)
      ).execute().value
      storedSpaceId = created.id
    } catch {
      let session = try await sb.auth.session
      try await sb.from("spaces")
        .insert(
          NewSpaceInsert(
            partner_1_id: session.user.id.uuidString.lowercased(),
            name: Theme.brandName
          )
        )
        .execute()
    }
  }

  private func decodeUUID(_ data: Data) -> String? {
    if let raw = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n"))
      .lowercased(),
      raw.count == 36
    {
      return raw
    }
    if let id = try? JSONDecoder().decode(UUID.self, from: data) {
      return id.uuidString.lowercased()
    }
    if let id = try? JSONDecoder().decode(String.self, from: data), id.count == 36 {
      return id.lowercased()
    }
    return nil
  }

  private func inviteCode(from url: URL) -> String? {
    let extracted = extractInviteCode(from: url.absoluteString)
    return extracted.isEmpty ? nil : extracted
  }
}

private extension AnyJSON {
  var stringValue: String? {
    if case .string(let s) = self { return s }
    return nil
  }
}
