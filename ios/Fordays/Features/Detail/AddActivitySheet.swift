import SwiftUI

enum ComposerKind: String, Identifiable {
  case plan
  case bucket
  var id: String { rawValue }
  var isPlan: Bool { self == .plan }
}

/// Same chooser as the PWA `AddSheet`: pick plan vs idea in words first.
struct AddSheetView: View {
  var onClose: () -> Void
  var onPick: (ComposerKind) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        Text("Add to your Orb")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
        Spacer(minLength: 12)
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 34, height: 34)
            .background(Theme.ink.opacity(0.08), in: Circle())
        }
        .accessibilityLabel("Close")
      }
      .padding(.bottom, 20)

      option(
        kind: .plan,
        title: "A plan",
        note: "Something you’re doing on a day.",
        glyph: .calendar
      )
      Rectangle()
        .fill(Theme.ink.opacity(0.08))
        .frame(height: 0.5)
      option(
        kind: .bucket,
        title: Copy.Tabs.ideas,
        note: Copy.Ideas.addOptionNote,
        glyph: .bucket
      )
    }
    .padding(20)
    .padding(.bottom, 8)
    .background(Theme.paper)
    .presentationDetents([.height(300)])
    .presentationDragIndicator(.visible)
  }

  private func option(
    kind: ComposerKind,
    title: String,
    note: String,
    glyph: TabGlyph
  ) -> some View {
    Button {
      onPick(kind)
    } label: {
      HStack(alignment: .top, spacing: 16) {
        TabIcon(glyph: glyph, on: false)
          .foregroundStyle(Theme.ink)
          .frame(width: 30, height: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
            .foregroundStyle(Theme.ink)
          Text(note)
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

/// Same composer as the PWA: kind is already decided; bucket has no day.
struct ComposerView: View {
  @EnvironmentObject private var app: AppModel
  let kind: ComposerKind
  var draft: PlanDraft? = nil
  var onClose: () -> Void

  @State private var title: String
  @State private var notes: String
  @State private var cover: String = ""
  @State private var date: String
  @State private var from: String
  @State private var until: String
  @State private var end: String?
  @State private var multiDay: Bool
  @State private var pickerOpen = false
  @State private var saving = false

  init(kind: ComposerKind, draft: PlanDraft? = nil, onClose: @escaping () -> Void) {
    self.kind = kind
    self.draft = draft
    self.onClose = onClose
    _title = State(initialValue: draft?.title ?? "")
    _notes = State(initialValue: draft?.notes ?? "")
    _date = State(initialValue: draft?.date ?? DateLocal.todayISO())
    _from = State(initialValue: draft?.from ?? "")
    _until = State(initialValue: draft?.until ?? "")
    _end = State(initialValue: draft?.end)
    _multiDay = State(initialValue: draft?.multiDay ?? (draft?.end != nil))
  }

  private var isPlan: Bool { kind.isPlan }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(isPlan ? Copy.Composer.newPlan : Copy.Composer.newIdea)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, 14)

        if isPlan {
          fieldLabel("Plan")
        }
        textField(
          isPlan ? "Dinner at Alma" : "Kayak the Grand River",
          text: $title
        )

        fieldLabel("Notes", hint: "— optional")
        textField("Anything worth remembering", text: $notes, lines: 3...6)

        if isPlan {
          fieldLabel("When")
          chips
          if pickerOpen {
            DatePicker(
              "Day",
              selection: Binding(
                get: { DateLocal.parseLocalDay(date) ?? Date() },
                set: { next in
                  let iso = DateLocal.todayISO(next)
                  date = iso
                  if let end, end <= iso { self.end = nil }
                }
              ),
              displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Theme.rose)
          }

          if multiDay {
            fieldLabel("Ends on", hint: "— last day")
            DatePicker(
              "Ends on",
              selection: Binding(
                get: { DateLocal.parseLocalDay(end ?? DateLocal.addDays(1, from: date)) ?? Date() },
                set: { end = DateLocal.todayISO($0) }
              ),
              in: (DateLocal.parseLocalDay(date) ?? Date())...,
              displayedComponents: .date
            )
            Button("Just one day") {
              multiDay = false
              end = nil
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.top, 10)
            .padding(.bottom, 4)
          }

          fieldLabel("Time", hint: "— optional")
          HStack(spacing: 8) {
            timeBox(label: multiDay ? "Starts at" : "From", text: $from)
            timeBox(label: multiDay ? "Ends at" : "Until", text: $until)
          }

          if !multiDay {
            Button("Runs more than one day?") {
              multiDay = true
              if end == nil || (end ?? "") <= date {
                end = DateLocal.addDays(1, from: date)
              }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.top, 14)
          }

          Text(previewWhen)
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 12)

          if let whisper = contextWhisper {
            HStack(spacing: 8) {
              Text("💬")
                .font(.footnote)
              Text(whisper)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 10)
          }
        }

        fieldLabel("Cover", hint: "— optional")
        CoverPickerView(cover: $cover, titleHint: { title })

        HStack(spacing: 10) {
          ghost("Cancel", action: onClose)
          accent(isPlan ? Copy.Composer.addPlan : Copy.Composer.addIdea) {
            await save()
          }
        }
        .padding(.top, 20)
      }
      .padding(20)
      .padding(.bottom, 28)
    }
    .background(Theme.paper.ignoresSafeArea())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private var chips: some View {
    let today = DateLocal.todayISO()
    let tomorrow = DateLocal.addDays(1)
    let weekend = DateLocal.nextSaturday()
    let isQuick = (date == today || date == tomorrow || date == weekend)

    let customLabel: String = {
      let formatted = DateLocal.mediumDate(date)
      if isQuick {
        return pickerOpen ? "Pick date ⌃" : "Pick date ⌵"
      } else {
        return "\(formatted) \(pickerOpen ? "⌃" : "⌵")"
      }
    }()

    return VStack(spacing: 8) {
      HStack(spacing: 8) {
        chip("Today", value: today)
        chip("Tomorrow", value: tomorrow)
      }
      HStack(spacing: 8) {
        chip("This weekend", value: weekend)
        Button {
          pickerOpen.toggle()
        } label: {
          HStack(spacing: 4) {
            Text("📅")
              .font(.caption)
            Text(customLabel)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          }
          .foregroundStyle((!isQuick || pickerOpen) ? .white : Theme.ink)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(
            (!isQuick ? Theme.rose : (pickerOpen ? Theme.ink : Theme.ink.opacity(0.06))),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.bottom, 4)
  }

  private func chip(_ label: String, value: String) -> some View {
    let on = date == value && !pickerOpen
    return Button {
      date = value
      pickerOpen = false
    } label: {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(on ? .white : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(on ? Theme.rose : Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var previewWhen: String {
    let when = DateLocal.composeWhen(
      date: date,
      from: from,
      until: until,
      endDate: multiDay ? end : nil
    )
    return DateLocal.describePlan(when.dateTime, endsAt: when.endsAt)
  }

  private func save() async {
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else {
      app.toast = "Give it a name"
      return
    }
    saving = true
    let when = isPlan
      ? DateLocal.composeWhen(
        date: date,
        from: from,
        until: until,
        endDate: multiDay ? end : nil
      )
      : nil
    let coverTrim = cover.trimmingCharacters(in: .whitespacesAndNewlines)
    await app.createActivity(
      title: clean,
      description: notes.trimmingCharacters(in: .whitespacesAndNewlines),
      imageUrl: coverTrim,
      dateTime: when?.dateTime,
      endsAt: when?.endsAt
    )
    if isPlan {
      app.pickedDay = date
      if let d = DateLocal.parseLocalDay(date) {
        app.cursorMonth = d
      }
      app.tab = .plans
    }
    saving = false
    onClose()
  }

  private var contextWhisper: String? {
    guard isPlan else { return nil }
    let myId = app.space?.myId
    let planDate = date

    let matching = app.externalEvents.filter { e in
      let isMine = myId == e.userId || e.userId == "0"
      if !isMine && !e.sharedWithSpace { return false }

      let eStartDay = String(e.startsAt.prefix(10))
      let eEndDay = e.endsAt.isEmpty ? eStartDay : String(e.endsAt.prefix(10))

      if multiDay, let planEndDate = end, planEndDate > planDate {
        return planDate <= eEndDay && planEndDate >= eStartDay
      }

      if planDate < eStartDay || planDate > eEndDay { return false }
      if e.allDay { return true }
      let fromT = from.trimmingCharacters(in: .whitespacesAndNewlines)
      if fromT.isEmpty { return true }

      if eStartDay < planDate && eEndDay > planDate { return true }

      let eStartTime = eStartDay < planDate
        ? "00:00"
        : (e.startsAt.count > 10 ? String(e.startsAt.dropFirst(11).prefix(5)) : "00:00")
      let eEndTime = eEndDay > planDate
        ? "23:59"
        : (!e.endsAt.isEmpty && e.endsAt.count > 10 ? String(e.endsAt.dropFirst(11).prefix(5)) : (eStartTime.isEmpty ? "23:59" : eStartTime))

      let pStartTime = fromT
      let untilT = until.trimmingCharacters(in: .whitespacesAndNewlines)
      var pEndTime = untilT
      if pEndTime.isEmpty {
        let parts = pStartTime.split(separator: ":").compactMap { Int($0) }
        let h = parts.count > 0 ? parts[0] : 0
        let m = parts.count > 1 ? parts[1] : 0
        let endH = min(h + 2, 23)
        pEndTime = String(format: "%02d:%02d", endH, m)
      }

      let safeEnd: String
      if eEndTime <= eStartTime {
        if eStartTime >= "23:00" {
          safeEnd = "23:59"
        } else {
          let h = Int(eStartTime.prefix(2)) ?? 0
          safeEnd = String(format: "%02d:%@", h + 1, String(eStartTime.suffix(2)))
        }
      } else {
        safeEnd = eEndTime
      }

      return eStartTime < pEndTime && safeEnd > pStartTime
    }

    guard !matching.isEmpty else { return nil }

    func formatEvent(_ ev: ExternalEvent) -> String {
      let isMine = myId == ev.userId || ev.userId == "0"
      let name = isMine ? "You" : (app.space?.displayName(for: ev.userId) ?? "Partner")
      let eventTitle = ev.title ?? Copy.Availability.busy

      var timeStr = "All day"
      if !ev.allDay {
        let tStart = ev.startsAt.count > 10 ? DateLocal.prettyLower(String(ev.startsAt.dropFirst(11).prefix(5))) : ""
        let tEnd = ev.endsAt.count > 10 ? DateLocal.prettyLower(String(ev.endsAt.dropFirst(11).prefix(5))) : ""
        if !tStart.isEmpty && !tEnd.isEmpty && tStart != tEnd {
          timeStr = "\(tStart) – \(tEnd)"
        } else if !tStart.isEmpty {
          timeStr = "from \(tStart)"
        }
      } else {
        let sDate = String(ev.startsAt.prefix(10))
        let eDate = ev.endsAt.isEmpty ? sDate : String(ev.endsAt.prefix(10))
        if sDate != eDate && eDate > sDate {
          timeStr = "\(DateLocal.shortDate(sDate)) – \(DateLocal.shortDate(eDate))"
        }
      }

      return "\(name) · \(eventTitle) (\(timeStr))"
    }

    if matching.count == 1, let first = matching.first {
      return formatEvent(first)
    }
    if matching.count == 2 {
      return "\(formatEvent(matching[0])) · \(formatEvent(matching[1]))"
    }
    let fromT = from.trimmingCharacters(in: .whitespacesAndNewlines)
    return !fromT.isEmpty
      ? "\(matching.count) overlapping events at this time"
      : "\(matching.count) shared events on this day"
  }

  private func fieldLabel(_ text: String, hint: String? = nil) -> some View {
    HStack(spacing: 4) {
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
      if let hint {
        Text(hint)
          .font(.caption)
          .foregroundStyle(Theme.inkFaint)
      }
    }
    .padding(.top, 16)
    .padding(.bottom, 8)
  }

  private func textField(
    _ placeholder: String,
    text: Binding<String>,
    lines: ClosedRange<Int> = 1...1
  ) -> some View {
    TextField(placeholder, text: text, axis: lines.upperBound > 1 ? .vertical : .horizontal)
      .lineLimit(lines)
      .padding(12)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func timeBox(label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption2.weight(.medium))
        .foregroundStyle(Theme.inkFaint)
        .textCase(.uppercase)
        .padding(.leading, 4)

      HStack(spacing: 4) {
        TextField("e.g. 7:00 PM", text: text)
          .keyboardType(.numbersAndPunctuation)
          .font(.subheadline)
          .padding(.vertical, 12)
          .padding(.leading, 12)

        if !text.wrappedValue.isEmpty {
          Button {
            text.wrappedValue = ""
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(Theme.paperWarm)
              .frame(width: 20, height: 20)
              .background(Theme.inkFaint, in: Circle())
              .padding(.trailing, 8)
          }
          .buttonStyle(.plain)
        }
      }
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .frame(maxWidth: .infinity)
  }

  private func ghost(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.body.weight(.medium))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private func accent(_ label: String, action: @escaping () async -> Void) -> some View {
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
    .disabled(saving)
  }
}
