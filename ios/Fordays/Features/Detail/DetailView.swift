import SwiftUI

struct DetailView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss

  let activityId: String

  private enum Mode {
    case view, edit, when, suggest, confirmDelete
  }

  @State private var mode: Mode = .view
  @State private var title = ""
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

  private var item: Activity? {
    app.activity(id: activityId)
  }

  private var myId: String {
    app.space?.myId ?? ""
  }

  var body: some View {
    NavigationStack {
      Group {
        if let item {
          content(item)
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear { seed(from: item) }
      .onChange(of: item?.id) { _, _ in seed(from: item) }
      .onChange(of: item?.title) { _, _ in
        if mode == .view { seed(from: item) }
      }
    }
  }

  @ViewBuilder
  private func content(_ item: Activity) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header(item)

        if mode == .view, let urlStr = item.imageUrl, !urlStr.isEmpty {
          RemoteOrDataImage(urlString: urlStr, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        if mode == .view, let description = item.description, !description.isEmpty {
          Text(description)
            .font(.body)
            .foregroundStyle(Theme.ink2)
        }

        if mode == .view, pending(item) {
          suggestionCard(item)
        }

        switch mode {
        case .edit:
          editForm
        case .when, .suggest:
          whenForm(suggest: mode == .suggest)
        case .confirmDelete:
          confirmDelete(item)
        case .view:
          if app.space?.frozen == true {
            Text("This is a copy from when you left — you can look, not change")
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)
              .padding(.top, 8)
          } else {
            actionList(item)
          }
        }
      }
      .padding(20)
      .padding(.bottom, 24)
    }
  }

  private func header(_ item: Activity) -> some View {
    HStack(alignment: .top, spacing: 12) {
      if item.imageUrl == nil || item.imageUrl?.isEmpty == true {
        LinearGradient(
          colors: Theme.orbColors(for: item.id, title: item.title),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
        Text(whenLabel(item))
          .font(.subheadline)
          .foregroundStyle(Theme.inkSoft)
      }
      Spacer(minLength: 8)
      if mode == .view, app.space?.frozen != true {
        Button {
          title = item.title
          notes = item.description ?? ""
          cover = item.imageUrl ?? ""
          mode = .edit
        } label: {
          Image(systemName: "pencil")
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .background(Theme.ink.opacity(0.06), in: Circle())
        }
        .accessibilityLabel("Edit")
      }
    }
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

    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        face(for: item.suggestedBy)
        (
          Text(mine ? "You suggested " : "\(who) suggests ")
            + Text(label).fontWeight(.semibold)
        )
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
      }

      if let note = item.suggestedNote, !note.isEmpty {
        Text(note)
          .font(.subheadline)
          .foregroundStyle(Theme.inkSoft)
      }

      if app.space?.frozen != true {
      HStack(spacing: 8) {
        if mine {
          ghostButton("Cancel") {
            await dismissSuggestion(item, mine: true)
          }
        } else {
          accentButton("Accept") {
            busy = true
            await app.acceptSuggestion(item.id)
            busy = false
            dismiss()
          }
          ghostButton("Dismiss") {
            await dismissSuggestion(item, mine: false)
          }
          ghostButton("Suggest something else") {
            openSuggest(item)
          }
        }
      }
      }
    }
    .padding(14)
    .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var editForm: some View {
    VStack(alignment: .leading, spacing: 12) {
      fieldLabel("Name")
      TextField("Name", text: $title)
        .textFieldStyle(.roundedBorder)

      fieldLabel("Notes", hint: "— optional")
      TextField("Anything worth remembering", text: $notes, axis: .vertical)
        .lineLimit(3...6)
        .textFieldStyle(.roundedBorder)

      fieldLabel("Cover", hint: "— optional")
      CoverPickerView(cover: $cover, titleHint: { title })

      HStack {
        ghostButton("Cancel") { mode = .view }
        accentButton("Save") { await saveEdits() }
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
    let now = Date()
    let c = Calendar.current
    var comps = c.dateComponents([.hour, .minute], from: now)
    let m = comps.minute ?? 0
    let nextM = (m / 5 + 1) * 5
    if nextM >= 60 {
      comps.hour = (comps.hour ?? 0) + 1
      comps.minute = 0
    } else {
      comps.minute = nextM
    }
    fromTime = String(format: "%02d:%02d", comps.hour ?? 19, comps.minute ?? 0)
  }

  private func addDefaultEndTime() {
    if fromTime.isEmpty {
      addDefaultTime()
      return
    }
    let start = parseTime(fromTime)
    let endT = Calendar.current.date(byAdding: .hour, value: 2, to: start) ?? start
    untilTime = formatTime(endT)
  }

  private func whenForm(suggest: Bool) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      fieldLabel("When")

      VStack(spacing: 0) {
        // Starts / When row
        HStack {
          Text(multiDay ? "Starts" : "When")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)

          Spacer()

          HStack(spacing: 8) {
            DatePicker("", selection: $day, displayedComponents: .date)
              .datePickerStyle(.compact)
              .labelsHidden()
              .tint(Theme.rose)

            if fromTime.isEmpty {
              Button(action: addDefaultTime) {
                Text("+ Add time")
                  .font(.subheadline.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
              }
              .buttonStyle(.plain)
            } else {
              HStack(spacing: 6) {
                DatePicker(
                  "",
                  selection: Binding(
                    get: { parseTime(fromTime) },
                    set: { next in fromTime = formatTime(next) }
                  ),
                  displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Theme.rose)

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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)

        // Multi-day Ends row
        if multiDay {
          Divider()
            .padding(.leading, 14)

          HStack {
            Text("Ends")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Theme.ink)

            Spacer()

            HStack(spacing: 8) {
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
                      .padding(.horizontal, 10)
                      .padding(.vertical, 6)
                      .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                  }
                  .buttonStyle(.plain)
                } else {
                  HStack(spacing: 6) {
                    DatePicker(
                      "",
                      selection: Binding(
                        get: { parseTime(untilTime) },
                        set: { next in untilTime = formatTime(next) }
                      ),
                      displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.rose)

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
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
        } else if !fromTime.isEmpty && !untilTime.isEmpty {
          // Single-day Until row
          Divider()
            .padding(.leading, 14)

          HStack {
            Text("Until")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Theme.ink)

            Spacer()

            HStack(spacing: 6) {
              DatePicker(
                "",
                selection: Binding(
                  get: { parseTime(untilTime) },
                  set: { next in untilTime = formatTime(next) }
                ),
                displayedComponents: .hourAndMinute
              )
              .datePickerStyle(.compact)
              .labelsHidden()
              .tint(Theme.rose)

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
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
        }
      }
      .background(Theme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
      .padding(.top, 4)

      if suggest {
        fieldLabel("Why", hint: "— optional, but helpful")
        TextField("I’m free that afternoon…", text: $suggestNote, axis: .vertical)
          .lineLimit(2...4)
          .textFieldStyle(.roundedBorder)
      }

      HStack {
        ghostButton("Cancel") { mode = .view }
        accentButton(
          suggest ? "Suggest" : (item?.isPlan == true ? "Save" : "Make it a plan")
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

  private func confirmDelete(_ item: Activity) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Delete “\(item.title)”? This removes it for everyone in this Orb.")
        .foregroundStyle(Theme.ink2)
      HStack {
        ghostButton("Keep it") { mode = .view }
        Button {
          Task {
            await app.deleteActivity(item.id)
            app.toast = "Deleted"
            dismiss()
          }
        } label: {
          Text("Delete")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.roseInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
    }
    .padding(14)
    .background(Theme.roseWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func actionList(_ item: Activity) -> some View {
    VStack(spacing: 4) {
      actionRow(
        title: item.isPlan ? "Change the day" : "Make it a plan",
        system: "calendar.badge.plus"
      ) {
        seedWhen(from: item)
        mode = .when
      }

      if app.space?.isMatched == true {
        actionRow(title: "Suggest a date", system: "bubble.left.and.bubble.right") {
          openSuggest(item)
        }
      }

      if item.isPlan {
        actionRow(title: Copy.Ideas.backTo, system: "checklist") {
          Task {
            await app.moveToBucket(item.id)
            dismiss()
          }
        }
      }

      actionRow(title: "Delete", system: "trash", destructive: true) {
        mode = .confirmDelete
      }
    }
    .padding(.top, 8)
  }

  private func actionRow(
    title: String,
    system: String,
    destructive: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: system)
          .font(.body.weight(.semibold))
          .frame(width: 22)
        Text(title)
          .font(.body.weight(.medium))
        Spacer()
      }
      .foregroundStyle(destructive ? Theme.roseInk : Theme.ink)
      .padding(.vertical, 14)
      .padding(.horizontal, 4)
    }
  }

  private func fieldLabel(_ text: String, hint: String? = nil) -> some View {
    HStack(spacing: 4) {
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

  @ViewBuilder
  private func accentButton(_ label: String, action: @escaping () async -> Void) -> some View {
    Button {
      Task { await action() }
    } label: {
      Text(label)
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .disabled(busy)
  }

  @ViewBuilder
  private func ghostButton(_ label: String, action: @escaping () async -> Void) -> some View {
    Button {
      Task { await action() }
    } label: {
      Text(label)
        .font(.body.weight(.medium))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .disabled(busy)
  }

  private func ghostButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.body.weight(.medium))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private func face(for userId: String?) -> some View {
    let seat = faceSeat(for: userId)
    let fill = seat == 0 ? Theme.faceSage : Theme.faceRose
    let initial = String(displayName(for: userId ?? "").prefix(1)).uppercased()
    return Text(initial)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: 28, height: 28)
      .background(fill, in: Circle())
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
    notes = item.description ?? ""
    cover = item.imageUrl ?? ""
    suggestNote = ""
    busy = false
    seedWhen(from: item)
  }

  private func seedWhen(from item: Activity) {
    let start = item.suggestedDateTime ?? item.dateTime
    let finish = item.suggestedEndsAt ?? item.endsAt
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
    seedWhen(from: item)
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
      imageUrl: coverTrim
    )
    mode = .view
  }

  private func saveWhen() async {
    let when = composedWhen()
    await app.patchActivity(
      activityId,
      dateTime: .some(when.dateTime),
      endsAt: .some(when.endsAt)
    )
    app.toast = item?.isPlan == true ? "Updated" : "Made it a plan"
    app.tab = .plans
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
    await app.suggestWhen(
      item.id,
      dateTime: when.dateTime,
      endsAt: when.endsAt,
      note: suggestNote
    )
    busy = false
    mode = .view
  }

  private func dismissSuggestion(_ item: Activity, mine: Bool) async {
    busy = true
    await app.dismissSuggestion(item.id)
    app.toast = mine ? "Cancelled" : "Dismissed"
    busy = false
  }
}

private extension Theme {
  static let ink2 = Color(hex: 0x3B352C)
}
