import SwiftUI

struct DetailView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss

  let activityId: String
  var onDoAgain: ((ComposerKind, PlanDraft) -> Void)? = nil

  private enum Mode {
    case view, edit, when, suggest
  }

  @State private var mode: Mode = .view
  @State private var title = ""
  @State private var location = ""
  @State private var notes = ""
  @State private var cover = ""
  @State private var day = Date()
  @State private var fromTime = ""
  @State private var untilTime = ""
  @State private var endDay: Date?
  @State private var multiDay = false
  @State private var suggestNote = ""
  @State private var busy = false
  @State private var seededFor: String?
  @State private var showDoAgainDialog = false
  @State private var showMoveDialog = false
  @State private var showDeleteDialog = false
  @State private var showHistory = false

  private var item: Activity? {
    app.activity(id: activityId)
  }

  private var myId: String {
    app.space?.myId ?? ""
  }

  private var isPersonalOrb: Bool {
    guard let space = app.space else { return false }
    let soloOrb = space.members.count <= 1
    let soloOrbs = app.spaces.filter { !$0.frozen && $0.members.count <= 1 }
    return soloOrb && (space.isHomeSoloName() || soloOrbs.count <= 1)
  }

  private var activeSharedOrbs: [SpaceInfo] {
    let currentId = app.space?.id
    return app.spaces.filter { !$0.frozen && $0.id != currentId }
  }

  private func makeDraft(from item: Activity) -> PlanDraft {
    PlanDraft(
      title: item.title,
      notes: item.description,
      location: item.location,
      cover: item.imageUrl,
      fromSomeday: true
    )
  }

  private func partnerOrName(_ target: SpaceInfo) -> String {
    if let partner = target.partnerName, !partner.isEmpty { return partner }
    return target.name
  }

  private func targetOrbLabel(_ target: SpaceInfo) -> String {
    if let partner = target.partnerName, !partner.isEmpty {
      return "\(partner) (\(target.name))"
    }
    return target.name
  }

  var body: some View {
    NavigationStack {
      mainContainer
        .background(Theme.paper.ignoresSafeArea())
        .presentationBackground(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            if let item, mode == .view, app.space?.frozen != true {
              Button("Edit") { startEditing(item) }
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
          }
        }
        .onAppear { seed(from: item) }
        .onChange(of: item?.id) { _, _ in seed(from: item) }
        .onChange(of: item?.title) { _, _ in
          if mode == .view { seed(from: item) }
        }
        .confirmationDialog(
          item.map { Copy.Memories.doAgainPrompt($0.title) } ?? "",
          isPresented: $showDoAgainDialog,
          titleVisibility: .visible
        ) {
          doAgainButtons
        }
        .confirmationDialog(
          Copy.Orbs.doWithEllipsis,
          isPresented: $showMoveDialog,
          titleVisibility: .visible
        ) {
          moveButtons
        }
        // A confirm is an Action Sheet, never Keep / Delete expanded in the page.
        .confirmationDialog(
          item.map { "Delete “\($0.title)”?" } ?? "",
          isPresented: $showDeleteDialog,
          titleVisibility: .visible
        ) {
          Button("Delete", role: .destructive) {
            guard let id = item?.id else { return }
            dismiss()
            Task {
              if await app.deleteActivity(id) { app.toast = "Deleted" }
            }
          }
          Button("Keep it", role: .cancel) { }
        } message: {
          Text("This removes it for everyone in this Orb.")
        }
    }
  }

  @ViewBuilder
  private var mainContainer: some View {
    if let item {
      content(item)
    } else {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func doAgainAsPlan() {
    guard let item else { return }
    let draft = makeDraft(from: item)
    dismiss()
    onDoAgain?(.plan, draft)
  }

  private func doAgainAsIdea() {
    guard let item else { return }
    let draft = makeDraft(from: item)
    dismiss()
    onDoAgain?(.bucket, draft)
  }

  @ViewBuilder
  private var doAgainButtons: some View {
    Button(Copy.Memories.makePlan, action: doAgainAsPlan)
    Button(Copy.Memories.addToSomeday, action: doAgainAsIdea)
    Button("Cancel", role: .cancel) { }
  }

  @ViewBuilder
  private var moveButtons: some View {
    ForEach(activeSharedOrbs, id: \.id) { target in
      Button(targetOrbLabel(target)) {
        Task { await handleDoWith(target) }
      }
    }
    Button("Cancel", role: .cancel) { }
  }

  @ViewBuilder
  private func content(_ item: Activity) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.base) {
        if mode == .view, let urlStr = item.imageUrl, !urlStr.isEmpty {
          RemoteOrDataImage(urlString: urlStr, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.TouchTarget.coverHero)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }

        header(item)

        if mode == .view, let loc = item.location, !loc.isEmpty {
          placeBlock(loc)
        }

        if mode == .view, let description = item.description, !description.isEmpty {
          Text(AttributedString.linkified(description))
            .font(.body)
            .foregroundStyle(Theme.ink2)
            .tint(Theme.ink2)
            .textSelection(.enabled)
        }

        if mode == .view, pending(item) {
          suggestionCard(item)
        }

        if mode == .view, app.space?.isMatched == true {
          addedBy(item)
        }

        switch mode {
        case .edit:
          editForm
        case .when, .suggest:
          whenForm(suggest: mode == .suggest)
        case .view:
          if app.space?.frozen == true {
            Text("This is a copy from when you left — you can look, not change")
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)
              .padding(.top, Theme.Spacing.sm)
          } else {
            actionList(item)
          }
        }

        if mode == .view {
          historyList(item)
        }
      }
      .padding(Theme.Spacing.lg)
      .padding(.bottom, Theme.Spacing.xl)
    }
  }

  /// Title and when, one left-aligned column. Edit lives in the top bar.
  private func header(_ item: Activity) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      Text(item.title)
        .font(.title2.weight(.semibold))
        .foregroundStyle(Theme.ink)
      Text(whenLabel(item))
        .font(.subheadline)
        .foregroundStyle(Theme.inkSoft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func startEditing(_ item: Activity) {
    title = item.title
    notes = item.description ?? ""
    cover = item.imageUrl ?? ""
    mode = .edit
  }

  /// The place on its own: name, then the rest of the address. Opens Maps.
  @ViewBuilder
  private func placeBlock(_ loc: String) -> some View {
    let parts = loc.split(separator: ",", maxSplits: 1)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    let name = parts.first ?? loc
    let rest = parts.count > 1 ? parts[1] : nil
    let query = loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc
    if let url = URL(string: "https://maps.apple.com/?q=\(query)") {
      Link(destination: url) {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
          VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(name)
              .font(.body)
              .foregroundStyle(Theme.ink)
            if let rest, !rest.isEmpty {
              Text(rest)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            }
          }
          Spacer(minLength: Theme.Spacing.sm)
          Image(systemName: "arrow.up.right")
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)
        }
        .multilineTextAlignment(.leading)
      }
      .accessibilityHint("Opens in Maps")
    }
  }

  private func addedBy(_ item: Activity) -> some View {
    let ago = DateLocal.timeAgo(item.createdAt)
    let who = displayName(for: item.createdBy)
    return Text(ago.isEmpty ? "Added by \(who)" : "Added by \(who) · \(ago)")
      .font(.footnote)
      .foregroundStyle(Theme.inkFaint)
  }

  private func whenLabel(_ item: Activity) -> String {
    if let dt = item.dateTime {
      return DateLocal.describePlan(dt, endsAt: item.endsAt)
    }
    return Copy.Ideas.inList
  }

  private func pending(_ item: Activity) -> Bool {
    item.suggestedDateTime != nil && item.suggestedBy != nil
  }

  private func suggestionCard(_ item: Activity) -> some View {
    let mine = item.suggestedBy == myId
    let who = displayName(for: item.suggestedBy ?? "")
    let label = item.suggestedDateTime.map {
      DateLocal.describePlan($0, endsAt: item.suggestedEndsAt)
    } ?? ""

    return FDCard(variant: .sageWash, padding: .sm) {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        HStack(spacing: Theme.Spacing.s10) {
          FDAvatar(name: who, seat: faceSeat(for: item.suggestedBy), size: .sm)
          (
            Text(mine ? "You suggested " : "\(who) suggests ")
              + Text(label).fontWeight(.semibold)
          )
          .font(.subheadline)
          .foregroundStyle(Theme.ink)
        }

        if let note = item.suggestedNote, !note.isEmpty {
          Text(AttributedString.linkified(note))
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
            .tint(Theme.inkSoft)
        }

        if app.space?.frozen != true {
          HStack(spacing: Theme.Spacing.sm) {
            if mine {
              FDButton("Cancel", variant: .secondary, size: .sm, disabled: busy) {
                await dismissSuggestion(item, mine: true)
              }
            } else {
              FDButton("Accept", variant: .primary, size: .sm, disabled: busy) {
                busy = true
                let day = DateLocal.dtDate(item.suggestedDateTime)
                if await app.acceptSuggestion(item.id), let day {
                  app.showDay(day)
                }
                busy = false
              }
              FDButton("Dismiss", variant: .secondary, size: .sm, disabled: busy) {
                await dismissSuggestion(item, mine: false)
              }
              FDButton("Suggest something else", variant: .secondary, size: .sm, disabled: busy) {
                openSuggest(item)
              }
            }
          }
        }
      }
    }
  }

  private var editForm: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      FDTextField(label: "Name", placeholder: "Name", text: $title)

      fieldLabel("Location", hint: "— optional")
      LocationInputView(text: $location)

      FDTextField(
        label: "Notes",
        hint: "— optional",
        placeholder: "Anything worth remembering",
        text: $notes,
        axis: .vertical,
        lineLimit: 3...6
      )

      fieldLabel("Cover")
      CoverPickerView(cover: $cover, titleHint: { title })

      HStack(spacing: Theme.Spacing.s10) {
        FDButton("Cancel", variant: .secondary) { mode = .view }
        FDButton("Save", variant: .primary, disabled: busy) { await saveEdits() }
      }
    }
  }

  private func parseTime(_ hhmm: String) -> Date {
    guard !hhmm.isEmpty else { return Date() }
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return Date() }
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    comps.hour = parts[0]
    comps.minute = parts[1]
    return Calendar.current.date(from: comps) ?? Date()
  }

  private func formatTime(_ d: Date) -> String {
    let c = Calendar.current
    let h = c.component(.hour, from: d)
    let m = c.component(.minute, from: d)
    return String(format: "%02d:%02d", h, m)
  }

  private func addDefaultTime() {
    let def = DateLocal.defaultAppleStartTime()
    // Late tonight the next half-hour is tomorrow's midnight, so the day follows it.
    let cal = Calendar.current
    if def == "00:00" && cal.isDateInToday(day) {
      day = cal.date(byAdding: .day, value: 1, to: day) ?? day
      if let endDay, cal.startOfDay(for: endDay) <= cal.startOfDay(for: day) {
        self.endDay = nil
      }
    }
    fromTime = def
  }

  private func addDefaultEndTime() {
    if fromTime.isEmpty {
      addDefaultTime()
      return
    }
    untilTime = DateLocal.defaultAppleEndTime(from: fromTime)
  }

  private func whenForm(suggest: Bool) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      fieldLabel("When")

      VStack(spacing: Theme.Spacing.none) {
        // Starts / When row
        HStack {
          Text(multiDay ? "Starts" : "When")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)

          Spacer()

          HStack(spacing: Theme.Spacing.sm) {
            DatePicker("", selection: $day, displayedComponents: .date)
              .datePickerStyle(.compact)
              .labelsHidden()
              .tint(Theme.rose)

            if fromTime.isEmpty {
              Button(action: addDefaultTime) {
                Text("+ Add time")
                  .font(.subheadline.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.horizontal, Theme.Spacing.s10)
                  .padding(.vertical, Theme.Spacing.s6)
                  .background(Theme.fillTertiary, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
              }
              .buttonStyle(.plain)
            } else {
              HStack(spacing: Theme.Spacing.s6) {
                CompactTimePicker(
                  selection: Binding(
                    get: { parseTime(fromTime) },
                    set: { next in fromTime = formatTime(next) }
                  ),
                  minuteInterval: 5
                )

                Button {
                  fromTime = ""
                  untilTime = ""
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .padding(.horizontal, Theme.Spacing.row)
        .padding(.vertical, Theme.Spacing.s10)

        // Multi-day Ends row
        if multiDay {
          Divider()
            .padding(.leading, Theme.Spacing.row)

          HStack {
            Text("Ends")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Theme.ink)

            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
              DatePicker(
                "",
                selection: Binding(
                  get: { endDay ?? Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day },
                  set: { endDay = $0 }
                ),
                in: day...,
                displayedComponents: .date
              )
              .datePickerStyle(.compact)
              .labelsHidden()
              .tint(Theme.rose)

              if !fromTime.isEmpty {
                if untilTime.isEmpty {
                  Button(action: addDefaultEndTime) {
                    Text("+ End time")
                      .font(.subheadline.weight(.medium))
                      .foregroundStyle(Theme.inkSoft)
                      .padding(.horizontal, Theme.Spacing.s10)
                      .padding(.vertical, Theme.Spacing.s6)
                      .background(Theme.fillTertiary, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                  }
                  .buttonStyle(.plain)
                } else {
                  HStack(spacing: Theme.Spacing.s6) {
                    CompactTimePicker(
                      selection: Binding(
                        get: { parseTime(untilTime) },
                        set: { next in untilTime = formatTime(next) }
                      ),
                      minuteInterval: 5
                    )

                    Button {
                      untilTime = ""
                    } label: {
                      Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkFaint)
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
          }
          .padding(.horizontal, Theme.Spacing.row)
          .padding(.vertical, Theme.Spacing.s10)
        } else if !fromTime.isEmpty && !untilTime.isEmpty {
          // Single-day Until row
          Divider()
            .padding(.leading, Theme.Spacing.row)

          HStack {
            Text("Until")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Theme.ink)

            Spacer()

          HStack(spacing: Theme.Spacing.s6) {
            CompactTimePicker(
              selection: Binding(
                get: { parseTime(untilTime) },
                set: { next in untilTime = formatTime(next) }
              ),
              minuteInterval: 5
            )

            Button {
              untilTime = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
          }
          }
          .padding(.horizontal, Theme.Spacing.row)
          .padding(.vertical, Theme.Spacing.s10)
        }
      }
      .background(Theme.fillQuaternary, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

      // Sub-row
      HStack {
        if !multiDay {
          if !fromTime.isEmpty && untilTime.isEmpty {
            Button("+ Add end time", action: addDefaultEndTime)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Theme.roseInk)
          }
          Spacer()
          Button("Runs more than one day?") {
            multiDay = true
            if endDay == nil || (endDay.map { DateLocal.todayISO($0) } ?? "") <= DateLocal.todayISO(day) {
              endDay = Calendar.current.date(byAdding: .day, value: 1, to: day)
            }
          }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
        } else {
          Button("Just one day") {
            multiDay = false
            endDay = nil
          }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          Spacer()
        }
      }
      .padding(.top, Theme.Spacing.xs)

      if suggest {
        FDTextField(
          label: "Why",
          hint: "— optional, but helpful",
          placeholder: "I’m free that afternoon…",
          text: $suggestNote,
          axis: .vertical,
          lineLimit: 2...4
        )
      }

      HStack(spacing: Theme.Spacing.s10) {
        FDButton("Cancel", variant: .secondary) { mode = .view }
        FDButton(
          suggest ? "Suggest" : (item?.isPlan == true ? "Save" : "Make it a plan"),
          variant: .primary,
          disabled: busy
        ) {
          if suggest {
            await saveSuggest()
          } else {
            await saveWhen()
          }
        }
      }
    }
  }

  /// Plain rows between hairlines; Delete sits alone below the rest.
  private func actionList(_ item: Activity) -> some View {
    let rows = actionRows(item)
    return VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
      actionGroup(rows.filter { !$0.destructive })
      actionGroup(rows.filter(\.destructive))
    }
    .padding(.top, Theme.Spacing.sm)
  }

  private func actionGroup(_ rows: [DetailAction]) -> some View {
    VStack(spacing: Theme.Spacing.none) {
      ForEach(rows) { row in
        Button(action: row.run) {
          HStack(spacing: Theme.Spacing.md) {
            // Warm grey icon beside ink text, like the tab bar.
            ActionGlyphIcon(glyph: row.icon)
              .foregroundStyle(row.destructive ? Theme.roseInk : Theme.inkSoft)
            Text(row.title)
              .font(.fdBody)
            Spacer()
          }
          .foregroundStyle(row.destructive ? Theme.roseInk : Theme.ink)
          .padding(.vertical, Theme.Spacing.md)
          .contentShape(Rectangle())
        }
        .buttonStyle(FDScaleButtonStyle())
        .overlay(alignment: .top) { hairline }
      }
    }
    .overlay(alignment: .bottom) { hairline }
  }

  private var hairline: some View {
    Rectangle()
      .fill(Theme.hairline)
      .frame(height: Theme.TouchTarget.hairlineWidth)
  }

  private struct DetailAction: Identifiable {
    let id: String
    let title: String
    let icon: ActionGlyph
    let destructive: Bool
    let run: () -> Void
  }

  private func actionRows(_ item: Activity) -> [DetailAction] {
    var rows: [DetailAction] = []
    if item.isMemory() {
      rows.append(DetailAction(id: "again", title: Copy.Memories.doAgain, icon: .again, destructive: false) {
        showDoAgainDialog = true
      })
    }
    if !item.isMemory(), isPersonalOrb, !activeSharedOrbs.isEmpty {
      if activeSharedOrbs.count == 1 {
        let target = activeSharedOrbs[0]
        let targetName = partnerOrName(target)
        rows.append(DetailAction(id: "with", title: Copy.Orbs.doWith(targetName), icon: .people, destructive: false) {
          Task { await handleDoWith(target) }
        })
      } else {
        rows.append(DetailAction(id: "with", title: Copy.Orbs.doWithEllipsis, icon: .people, destructive: false) {
          showMoveDialog = true
        })
      }
    }
    rows.append(DetailAction(
      id: "when",
      title: item.isPlan ? "Change the day" : "Make it a plan",
      icon: .calendar,
      destructive: false
    ) {
      seedWhen(from: item, suggestion: false)
      mode = .when
    })
    if app.space?.isMatched == true, !item.isMemory() {
      let others = app.space?.members.filter { $0.id != app.space?.myId } ?? []
      let suggestTitle = others.count == 1 ? "Suggest a date to \(others[0].name)" : "Suggest a date"
      rows.append(DetailAction(id: "suggest", title: suggestTitle, icon: .suggest, destructive: false) {
        openSuggest(item)
      })
    }
    if item.isPlan, !item.isMemory() {
      rows.append(DetailAction(id: "bucket", title: Copy.Ideas.backTo, icon: .bucket, destructive: false) {
        Task {
          await app.moveToBucket(item.id)
          dismiss()
        }
      })
    }
    rows.append(DetailAction(id: "delete", title: "Delete", icon: .trash, destructive: true) {
      showDeleteDialog = true
    })
    return rows
  }

  /// Folded away by default: the drawer is about the plan, not its log.
  @ViewBuilder
  private func historyList(_ item: Activity) -> some View {
    let rows = app.logs
      .filter { $0.activityId == item.id }
      .sorted { $0.timestamp > $1.timestamp }
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: Theme.Spacing.none) {
        Button {
          withAnimation(.easeInOut(duration: Theme.Motion.fade)) { showHistory.toggle() }
        } label: {
          HStack(spacing: Theme.Spacing.xs) {
            Text("History")
              .font(.fdFootnote.weight(.semibold))
            Image(systemName: "chevron.right")
              .font(.caption2)
              .rotationEffect(.degrees(showHistory ? 90 : 0))
          }
          .foregroundStyle(Theme.inkFaint)
          .padding(.vertical, Theme.Spacing.sm)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(showHistory ? "Shown" : "Hidden")

        if showHistory {
          ForEach(rows) { log in
            HStack(alignment: .top, spacing: Theme.Spacing.s11) {
              FDAvatar(name: displayName(for: log.userId), seat: faceSeat(for: log.userId), size: .sm)
              historyLine(log, allDay: item.allDay)
            }
            .padding(.vertical, Theme.Spacing.s7)
          }
        }
      }
      .padding(.top, Theme.Spacing.s10)
    }
  }

  private func historyLine(_ log: AuditLog, allDay: Bool) -> Text {
    let who = displayName(for: log.userId)
    let what = DateLocal.localizeAuditDetails(allDay ? Self.dropNoonUTC(log.details) : log.details)
    let ago = DateLocal.timeAgo(log.timestamp)
    let body = Text("\(who) \(what)").foregroundStyle(Theme.ink2)
    if ago.isEmpty {
      return body.font(.fdFootnote)
    }
    return (body + Text(" · \(ago)").foregroundStyle(Theme.inkFaint)).font(.fdFootnote)
  }

  /// All-day plans are stored at noon UTC, so the server logs "at 12:00 PM".
  /// That isn't a time anyone chose; keep only the date.
  static func dropNoonUTC(_ details: String) -> String {
    details.replacingOccurrences(
      of: #"\b([A-Z][a-z]{2}) 0?(\d{1,2}), (\d{4}) at 12:00 PM\b"#,
      with: "$1 $2, $3",
      options: .regularExpression
    )
  }

  private func handleDoWith(_ targetSpace: SpaceInfo) async {
    guard let item else { return }
    let targetName = partnerOrName(targetSpace)
    guard await app.moveActivityToSpace(item.id, targetSpaceId: targetSpace.id) else { return }
    app.toast = item.isPlan
      ? Copy.Orbs.movedToPlans(targetName)
      : Copy.Orbs.movedToSomeday(targetName)
    dismiss()
  }

  private func fieldLabel(_ text: String, hint: String? = nil) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.inkSoft)
      if let hint {
        Text(hint)
          .font(.caption)
          .foregroundStyle(Theme.inkFaint)
      }
    }
  }

  private func face(for userId: String?) -> some View {
    let seat = faceSeat(for: userId)
    let name = displayName(for: userId ?? "")
    return FDAvatar(name: name, seat: seat, size: .sm)
  }

  private func faceSeat(for userId: String?) -> Int {
    guard let space = app.space else { return 0 }
    guard let userId else { return 0 }
    return userId.compare(space.myId, options: .caseInsensitive) == .orderedSame ? 0 : 1
  }

  private func displayName(for userId: String) -> String {
    guard let space = app.space else { return "?" }
    return space.displayName(for: userId)
  }

  private func seed(from item: Activity?) {
    guard let item else { return }
    if seededFor == item.id, mode != .view { return }
    seededFor = item.id
    mode = .view
    title = item.title
    location = item.location ?? ""
    notes = item.description ?? ""
    cover = item.imageUrl ?? ""
    suggestNote = ""
    busy = false
    seedWhen(from: item, suggestion: false)
  }

  /// Change the day starts from the plan's own day; Suggest something else
  /// starts from the pending suggestion — the PWA's seed vs `openSuggest`.
  private func seedWhen(from item: Activity, suggestion: Bool) {
    let start = suggestion ? (item.suggestedDateTime ?? item.dateTime) : item.dateTime
    let finish = suggestion ? (item.suggestedEndsAt ?? item.endsAt) : item.endsAt
    day = DateLocal.parseLocalDay(start ?? DateLocal.todayISO()) ?? Date()
    fromTime = DateLocal.dtTime(start) ?? ""
    untilTime = DateLocal.dtTime(finish) ?? ""
    if let finish,
       let end = DateLocal.dtDate(finish),
       DateLocal.dtDate(start) != end
    {
      endDay = DateLocal.parseLocalDay(end)
      multiDay = true
    } else {
      endDay = nil
      multiDay = false
    }
  }

  private func openSuggest(_ item: Activity) {
    seedWhen(from: item, suggestion: true)
    suggestNote = ""
    mode = .suggest
  }

  private func composedWhen() -> (dateTime: String, endsAt: String?) {
    DateLocal.composeWhen(
      date: DateLocal.todayISO(day),
      from: fromTime,
      until: untilTime,
      endDate: multiDay ? endDay.map { DateLocal.todayISO($0) } : nil
    )
  }

  private func saveEdits() async {
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else {
      app.toast = "It needs a name"
      return
    }
    let coverTrim = cover.trimmingCharacters(in: .whitespacesAndNewlines)
    await app.patchActivity(
      activityId,
      title: clean,
      description: notes.trimmingCharacters(in: .whitespacesAndNewlines),
      location: location.trimmingCharacters(in: .whitespacesAndNewlines),
      imageUrl: coverTrim
    )
    mode = .view
  }

  private func saveWhen() async {
    let when = composedWhen()
    await app.patchActivity(
      activityId,
      dateTime: .some(when.dateTime),
      endsAt: .some(when.endsAt),
      fromSomeday: item?.isPlan == true ? nil : .some(true)
    )
    app.toast = item?.isPlan == true ? "Updated" : "Made it a plan"
    app.tab = .plans
    app.showDay(DateLocal.todayISO(day))
    mode = .view
  }

  private func saveSuggest() async {
    guard let item else { return }
    let when = composedWhen()
    if when.dateTime == item.dateTime, when.endsAt == item.endsAt {
      app.toast = "That’s already the date — change it, or leave a reason in a note"
      return
    }
    if let suggested = item.suggestedDateTime,
       when.dateTime == suggested,
       when.endsAt == item.suggestedEndsAt
    {
      app.toast = "That’s already the suggestion"
      return
    }
    busy = true
    let sent = await app.suggestWhen(
      item.id,
      dateTime: when.dateTime,
      endsAt: when.endsAt,
      note: suggestNote
    )
    busy = false
    // A failed suggestion keeps the form (and the note) open.
    if sent { mode = .view }
  }

  private func dismissSuggestion(_ item: Activity, mine: Bool) async {
    busy = true
    if await app.dismissSuggestion(item.id) {
      app.toast = mine ? "Cancelled" : "Dismissed"
    }
    busy = false
  }
}
