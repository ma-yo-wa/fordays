import EventKit
import Foundation
import Supabase

@MainActor
final class AppModel: ObservableObject {
  @Published var authPhase: AuthPhase = .loading
  @Published var space: SpaceInfo?
  @Published var spaces: [SpaceInfo] = []
  @Published var activities: [Activity] = []
  @Published var externalEvents: [ExternalEvent] = []
  @Published var tab: HomeTab = .plans
  @Published var cursorMonth: Date = Date()
  @Published var pickedDay: String = DateLocal.todayISO()
  @Published var errorMessage: String?
  @Published var toast: String?
  @Published var showJoinOrb: Bool = false
  @Published var pendingInviteShare = false
  @Published var pendingInviteCode: String?
  @Published var pendingInvitePeek: InvitePeek?
  @Published var detailActivityId: String?
  @Published var pendingActivityId: String?
  @Published var pendingActivitySpaceId: String?

  func shiftMonth(by delta: Int) {
    cursorMonth = Calendar.current.date(byAdding: .month, value: delta, to: cursorMonth) ?? cursorMonth
  }

  func goToday() {
    pickedDay = DateLocal.todayISO()
    cursorMonth = Date()
  }

  private static let firstOrbSetupKey = "fordays.firstOrbSetupUserId"

  private var firstOrbSetupPending: Bool {
    guard let space else { return false }
    let saved = UserDefaults.standard.string(forKey: Self.firstOrbSetupKey)?.lowercased()
    return saved == space.myId.lowercased()
  }

  func markFirstOrbSetupPending(userId: String) {
    UserDefaults.standard.set(userId.lowercased(), forKey: Self.firstOrbSetupKey)
  }

  func clearFirstOrbSetupPending() {
    UserDefaults.standard.removeObject(forKey: Self.firstOrbSetupKey)
  }

  var needsFirstOrbSetup: Bool {
    guard let space, !space.frozen, !showJoinOrb, firstOrbSetupPending else { return false }
    let others = space.members.filter { $0.id.compare(space.myId, options: .caseInsensitive) != .orderedSame }
    if !others.isEmpty || space.partner2Id != nil { return false }
    let trimmed = space.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty
      || trimmed.caseInsensitiveCompare("Fordays") == .orderedSame
      || trimmed.caseInsensitiveCompare("Someday") == .orderedSame
  }

  func completeFirstOrb(name: String, withPeople: Bool) async {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return }
    if withPeople {
      if let current = space {
        try? await sb.from("spaces")
          .update(SpaceNameUpdate(name: "Personal"))
          .eq("id", value: current.id)
          .execute()
      }
      clearFirstOrbSetupPending()
      await addSpace(name: clean, withPeople: true)
    } else {
      guard let id = space?.id else { return }
      do {
        try await sb.from("spaces")
          .update(SpaceNameUpdate(name: clean))
          .eq("id", value: id)
          .execute()
        try await refreshSpaceAndData()
        clearFirstOrbSetupPending()
      } catch {
        toast = error.localizedDescription
      }
    }
  }

  func renameCurrentSpace(_ name: String) async {
    guard let current = space, !current.frozen else { return }
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return }
    do {
      try await sb.from("spaces")
        .update(SpaceNameUpdate(name: clean))
        .eq("id", value: current.id)
        .execute()
      try await refreshSpaceAndData()
    } catch {
      toast = error.localizedDescription
    }
  }

  private var lastAppleSync: Date?
  private var calendarObserver: NSObjectProtocol?
  private var sb: SupabaseClient { SupabaseService.shared.client }

  func watchDeviceCalendars() {
    guard calendarObserver == nil else { return }
    calendarObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: CalendarSync.store,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.syncAppleIfNeeded(force: true)
      }
    }
  }

  func syncAppleIfNeeded(force: Bool = false) async {
    guard space?.frozen != true else { return }
    guard CalendarSync.isConnected, CalendarSync.selectedId != nil else { return }
    if !force, let last = lastAppleSync, Date().timeIntervalSince(last) < 20 { return }
    lastAppleSync = Date()
    do {
      try await replaceExternal(CalendarSync.fetchEvents(), source: "apple")
    } catch {
      toast = error.localizedDescription
    }
  }

  func replaceExternal(_ events: [ImportedEventDraft], source: String) async throws {
    guard let space else { return }
    guard space.canCompose else { return }
    let session = try await sb.auth.session
    let uid = session.user.id.uuidString.lowercased()
    let now = ISO8601DateFormatter().string(from: Date())

    struct ExistingExt: Decodable {
      let id: String
      let source_id: String
    }

    let existing: [ExistingExt] = try await sb.from("external_events")
      .select("id, source_id")
      .eq("space_id", value: space.id)
      .eq("owner_id", value: uid)
      .eq("calendar_source", value: source)
      .execute()
      .value

    let keep = Set(events.map(\.sourceId))
    let stale = existing.filter { !keep.contains($0.source_id) }.map(\.id)
    if !stale.isEmpty {
      for chunk in stale.chunked(into: 80) {
        try await sb.from("external_events")
          .delete()
          .in("id", values: chunk)
          .execute()
      }
    }

    if !events.isEmpty {
      struct ExternalEventWrite: Encodable {
        let space_id: String
        let owner_id: String
        let source_id: String
        let calendar_source: String
        let title: String?
        let location: String?
        let starts_at: String
        let ends_at: String
        let all_day: Bool
        let calendar_name: String
        let updated_at: String
      }

      let rows = events.map { e in
        ExternalEventWrite(
          space_id: space.id,
          owner_id: uid,
          source_id: e.sourceId,
          calendar_source: source,
          title: e.title,
          location: e.location,
          starts_at: DateLocal.toTimestamptz(e.startsAt),
          ends_at: DateLocal.toTimestamptz(e.endsAt),
          all_day: e.allDay,
          calendar_name: e.calendar,
          updated_at: now
        )
      }
      for chunk in rows.chunked(into: 80) {
        try await sb.from("external_events")
          .upsert(chunk, onConflict: "space_id,owner_id,calendar_source,source_id")
          .execute()
      }
    }

    await refreshExternal()
  }

  func disconnectApple() async {
    CalendarSync.setConnected(false)
    do {
      try await replaceExternal([], source: "apple")
      toast = "Apple Calendar disconnected"
    } catch {
      toast = error.localizedDescription
    }
  }

  func boot() async {
    authPhase = .loading
    do {
      _ = try await sb.auth.session
      hydrateNotebook()
      if space != nil { authPhase = .signedIn }
      try await refreshSpaceAndData()
      authPhase = space == nil ? .signedOut : .signedIn
      if authPhase == .signedIn, let actId = pendingActivityId {
        let spId = pendingActivitySpaceId
        pendingActivityId = nil
        pendingActivitySpaceId = nil
        await navigateToActivity(activityId: actId, spaceId: spId)
      }
    } catch {
      authPhase = space != nil ? .signedIn : .signedOut
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
      if let code = pendingInviteCode {
        pendingInviteCode = nil
        pendingInvitePeek = nil
        do {
          try await joinInvite(code)
        } catch {
          toast = error.localizedDescription
        }
      }
      if authPhase == .signedIn, let actId = pendingActivityId {
        let spId = pendingActivitySpaceId
        pendingActivityId = nil
        pendingActivitySpaceId = nil
        await navigateToActivity(activityId: actId, spaceId: spId)
      }
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
      markFirstOrbSetupPending(userId: uid)
      try await sb.from("profiles")
        .update(ProfileNameUpdate(display_name: name))
        .eq("id", value: uid)
        .execute()
      try await ensureSpace()
      try await refreshSpaceAndData()
      authPhase = .signedIn
      if let code = pendingInviteCode {
        pendingInviteCode = nil
        pendingInvitePeek = nil
        clearFirstOrbSetupPending()
        do {
          try await joinInvite(code)
        } catch {
          toast = error.localizedDescription
        }
      }
      if authPhase == .signedIn, let actId = pendingActivityId {
        let spId = pendingActivitySpaceId
        pendingActivityId = nil
        pendingActivitySpaceId = nil
        await navigateToActivity(activityId: actId, spaceId: spId)
      }
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
      persistNotebook()
      prefetchFirstBoardCovers(activities)
    } catch {
      toast = error.localizedDescription
    }
    Task { await refreshExternal() }
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
      toast = dateTime == nil ? Copy.Ideas.added : "Made it a plan"
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
    toast = Copy.Ideas.backIn
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

  func navigateToActivity(activityId: String, spaceId: String? = nil) async {
    guard !activityId.isEmpty else { return }

    if let spaceId, !spaceId.isEmpty, space?.id != spaceId {
      await switchToSpace(spaceId)
    }

    var act = activity(id: activityId)
    if act == nil {
      for _ in 0..<5 {
        try? await Task.sleep(nanoseconds: 200_000_000)
        act = activity(id: activityId)
        if act != nil { break }
      }
    }

    guard let target = act else {
      toast = "That plan is no longer here"
      return
    }

    if target.isPlan, let dt = target.dateTime {
      let dayISO = String(dt.prefix(10))
      pickedDay = dayISO
      if let d = DateLocal.parseLocalDay(dayISO) {
        cursorMonth = d
      }
      tab = .plans
    } else {
      tab = .bucket
    }

    detailActivityId = target.id
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

    let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
    let actId = components?.queryItems?.first(where: { $0.name == "a" })?.value
    let spId = components?.queryItems?.first(where: { $0.name == "s" })?.value
    if let actId, !actId.isEmpty {
      if authPhase == .signedIn {
        await navigateToActivity(activityId: actId, spaceId: spId)
      } else {
        pendingActivityId = actId
        pendingActivitySpaceId = spId
      }
      return
    }

    if let code = inviteCode(from: url) {
      if authPhase == .signedIn {
        do {
          try await joinInvite(code)
        } catch {
          toast = error.localizedDescription
        }
      } else {
        pendingInviteCode = code
        Task {
          pendingInvitePeek = try? await peekInvite(code)
        }
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
    let allSpaces = (try? await loadSpaces()) ?? []
    let genericSolo = allSpaces.first { sp in
      let otherMembers = sp.members.filter { m in
        m.id.compare(sp.myId, options: .caseInsensitive) != .orderedSame
      }
      let isDefaultName = sp.name.caseInsensitiveCompare("Fordays") == .orderedSame || sp.name.caseInsensitiveCompare("Someday") == .orderedSame
      return otherMembers.isEmpty && sp.partner2Id == nil && isDefaultName
    }
    if let genericSolo {
      try? await sb.from("spaces")
        .update(SpaceNameUpdate(name: "Personal"))
        .eq("id", value: genericSolo.id)
        .execute()
    }
    try await refreshSpaceAndData()
    authPhase = .signedIn
    clearFirstOrbSetupPending()
    let name = space?.peopleLabel.isEmpty == false ? space!.peopleLabel : "this Orb"
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

  @discardableResult
  func addSpace(name: String = "", withPeople: Bool = false) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    do {
      let created: SpaceRow = try await sb.rpc(
        "create_space",
        params: CreateSpaceParams(p_name: trimmed)
      ).execute().value
      storedSpaceId = created.id
      try await refreshSpaceAndData()
      pendingInviteShare = withPeople
      return true
    } catch {
      toast = error.localizedDescription
      return false
    }
  }

  func leaveCurrentSpace() async {
    guard let current = space else { return }
    await leaveSpace(current.id)
  }

  func leaveSpace(_ spaceId: String) async {
    let live = spaces.filter { !$0.frozen }
    let leaving = spaces.first(where: { $0.id == spaceId }) ?? space
    let others = (leaving?.members ?? []).filter {
      $0.id.compare(leaving?.myId ?? "", options: .caseInsensitive) != .orderedSame
    }
    let solo = others.isEmpty && leaving?.partner2Id == nil
    if solo && live.count <= 1 {
      toast = "Keep at least one Orb"
      return
    }
    let soloOrbs = live.filter { sp in
      let otherMembers = sp.members.filter { m in
        m.id.compare(sp.myId, options: .caseInsensitive) != .orderedSame
      }
      return otherMembers.isEmpty && sp.partner2Id == nil
    }
    let isPersonal = solo && (leaving?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "personal" || soloOrbs.count <= 1)
    if isPersonal {
      toast = Copy.Orbs.cannotDeletePersonal
      return
    }
    do {
      _ = try await sb.rpc("leave_space", params: SpaceIdParams(sid: spaceId)).execute()
      let list = try await loadSpaces()
      spaces = list
      let active = list.filter { !$0.frozen }
      if space?.id == spaceId {
        if let next = active.first {
          storedSpaceId = next.id
          space = next
          await refreshActivities()
        } else {
          try await ensureSpace()
          try await refreshSpaceAndData()
        }
      } else if let current = space, let fresh = list.first(where: { $0.id == current.id }) {
        space = fresh
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

  private struct NotebookSnap: Codable {
    var space: SpaceInfo
    var spaces: [SpaceInfo]
    var activities: [Activity]
  }

  private func notebookCacheURL(spaceId: String) -> URL {
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    return dir.appendingPathComponent("fordays-notebook-\(spaceId).json")
  }

  private func prefetchFirstBoardCovers(_ rows: [Activity]) {
    let someday = rows
      .filter(\.isBucketItem)
      .sorted { $0.createdAt > $1.createdAt }
      .prefix(6)
      .compactMap(\.imageUrl)
    let today = DateLocal.todayISO()
    let memories = rows
      .filter { $0.isMemory(today: today) }
      .sorted { ($0.endsAt ?? $0.dateTime ?? "") > ($1.endsAt ?? $1.dateTime ?? "") }
      .prefix(6)
      .compactMap(\.imageUrl)
    CoverImageStore.shared.prefetch(Array(someday) + Array(memories))
  }

  private func hydrateNotebook() {
    guard let id = storedSpaceId else { return }
    guard let data = try? Data(contentsOf: notebookCacheURL(spaceId: id)),
          let snap = try? JSONDecoder().decode(NotebookSnap.self, from: data)
    else { return }
    space = snap.space
    spaces = snap.spaces.isEmpty ? [snap.space] : snap.spaces
    activities = snap.activities
    prefetchFirstBoardCovers(snap.activities)
  }

  private func persistNotebook() {
    guard let space else { return }
    var rows = activities
    for i in rows.indices {
      if rows[i].imageUrl?.hasPrefix("data:") == true {
        rows[i].imageUrl = nil
      }
    }
    let snap = NotebookSnap(
      space: space,
      spaces: spaces.isEmpty ? [space] : spaces,
      activities: rows
    )
    guard let data = try? JSONEncoder().encode(snap) else { return }
    try? data.write(to: notebookCacheURL(spaceId: space.id), options: .atomic)
  }

  private func refreshSpaceAndData() async throws {
    let list = try await loadSpaces()
    spaces = list
    let saved = storedSpaceId
    space = list.first(where: { $0.id == saved }) ?? list.first
    if let space { storedSpaceId = space.id }
    if space != nil {
      await refreshActivities()
      watchDeviceCalendars()
      Task { await syncAppleIfNeeded() }
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
