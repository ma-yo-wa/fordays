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
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      HStack(alignment: .top) {
        Text("Add to your Orb")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
        Spacer(minLength: 12)
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: Theme.TouchTarget.control, height: Theme.TouchTarget.control)
            .background(Theme.fillTertiary, in: Circle())
        }
        .accessibilityLabel("Close")
      }
      .padding(.bottom, Theme.Spacing.lg)

      option(
        kind: .plan,
        title: "A plan",
        note: "Something you’re doing on a day.",
        glyph: .calendar
      )
      Rectangle()
        .fill(Theme.hairline)
        .frame(height: Theme.TouchTarget.hairlineWidth)
      option(
        kind: .bucket,
        title: Copy.Tabs.ideas,
        note: Copy.Ideas.addOptionNote,
        glyph: .bucket
      )
    }
    .padding(Theme.Spacing.lg)
    .padding(.bottom, Theme.Spacing.sm)
    .background(Theme.paper.ignoresSafeArea())
    .presentationBackground(Theme.paper)
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
      HStack(alignment: .top, spacing: Theme.Spacing.base) {
        TabIcon(glyph: glyph, on: false)
          .foregroundStyle(Theme.ink)
          .frame(width: Theme.Spacing.s30, height: Theme.Spacing.xl)
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
          Text(title)
            .font(.headline)
            .foregroundStyle(Theme.ink)
          Text(note)
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, Theme.Spacing.base)
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
  @State private var location: String
  @State private var notes: String
  @State private var cover: String = ""
  @State private var date: String
  @State private var from: String
  @State private var until: String
  @State private var end: String?
  @State private var multiDay: Bool
  @State private var saving = false

  init(
    kind: ComposerKind,
    draft: PlanDraft? = nil,
    focusedDay: String? = nil,
    onClose: @escaping () -> Void
  ) {
    self.kind = kind
    self.draft = draft
    self.onClose = onClose
    let today = DateLocal.todayISO()
    // A plan opens on the draft date if provided, or the day you were already looking at (never in the past).
    let initialDate: String
    if let d = draft?.date, d >= today {
      initialDate = d
    } else if let d = focusedDay, d >= today {
      initialDate = d
    } else {
      initialDate = today
    }
    _title = State(initialValue: draft?.title ?? "")
    _location = State(initialValue: draft?.location ?? "")
    _notes = State(initialValue: draft?.notes ?? "")
    _cover = State(initialValue: draft?.cover ?? "")
    _date = State(initialValue: initialDate)
    _from = State(initialValue: draft?.from ?? "")
    _until = State(initialValue: draft?.until ?? "")
    _end = State(initialValue: draft?.end)
    _multiDay = State(initialValue: draft?.multiDay ?? (draft?.end != nil))
  }

  private var isPlan: Bool { kind.isPlan }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.none) {
        Text(isPlan ? Copy.Composer.newPlan : Copy.Composer.newIdea)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, Theme.Spacing.row)

        FDTextField(
          label: isPlan ? "Plan" : nil,
          placeholder: isPlan ? "Dinner at Alma" : "Kayak the Grand River",
          text: $title
        )
        .submitLabel(.done)
        .onSubmit { Task { await save() } }

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
        .padding(.top, Theme.Spacing.xl)

        if isPlan {
          fieldLabel("When")
          appleWhenCard
          appleSubRow

          Text(previewWhen)
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, Theme.Spacing.md)
        }

        if cover.isEmpty {
          Button {
            withAnimation(.spring(response: Theme.Motion.spring)) {
              cover = " " // Non-empty string to trigger picker expansion
            }
          } label: {
            HStack(spacing: Theme.Spacing.xxs) {
              Text("+ Add cover")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
              Text("— photo or GIF")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaint)
              Spacer()
            }
            .padding(.top, Theme.Spacing.xl)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        } else {
          HStack(alignment: .bottom) {
            Text("Cover")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Theme.inkFaint)
            Spacer()
            if cover.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Button("Cancel") {
                withAnimation(.spring(response: Theme.Motion.spring)) {
                  cover = ""
                }
              }
              .font(.caption)
              .foregroundStyle(Theme.inkSoft)
            }
          }
          .padding(.top, Theme.Spacing.xl)
          .padding(.bottom, Theme.Spacing.s6)
          
          CoverPickerView(cover: $cover, titleHint: { title })
        }

        HStack(spacing: Theme.Spacing.s10) {
          FDButton("Cancel", variant: .secondary, action: onClose)
          FDButton(
            isPlan ? Copy.Composer.addPlan : Copy.Composer.addIdea,
            variant: .primary,
            loading: saving,
            disabled: saving
          ) {
            await save()
          }
        }
        .padding(.top, cover.isEmpty ? Theme.Spacing.s22 : Theme.Spacing.sm)
      }
      .padding(Theme.Spacing.lg)
      .padding(.bottom, Theme.Spacing.s28)
    }
    .background(Theme.paper.ignoresSafeArea())
    .presentationBackground(Theme.paper)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
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
    if def == "00:00" && date == DateLocal.todayISO() {
      let next = DateLocal.addDays(1, from: date)
      date = next
      if let end, end <= next { self.end = nil }
    }
    from = def
  }

  private func addDefaultEndTime() {
    if from.isEmpty {
      addDefaultTime()
      return
    }
    until = DateLocal.defaultAppleEndTime(from: from)
  }

  private var appleWhenCard: some View {
    VStack(spacing: Theme.Spacing.none) {
      // Starts / When row
      HStack {
        Text(multiDay ? "Starts" : "When")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Theme.ink)

        Spacer()

        HStack(spacing: Theme.Spacing.sm) {
          DatePicker(
            "",
            selection: Binding(
              get: { DateLocal.parseLocalDay(date) ?? Date() },
              set: { next in
                let iso = DateLocal.todayISO(next)
                date = iso
                if let end, end <= iso { self.end = nil }
              }
            ),
            in: isPlan ? (DateLocal.parseLocalDay(DateLocal.todayISO()) ?? Date())... : Date.distantPast...,
            displayedComponents: .date
          )
          .datePickerStyle(.compact)
          .labelsHidden()
          .tint(Theme.rose)

          if from.isEmpty {
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
                  get: { parseTime(from) },
                  set: { next in from = formatTime(next) }
                ),
                minuteInterval: 5
              )

              Button {
                from = ""
                until = ""
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
                get: { DateLocal.parseLocalDay(end ?? DateLocal.addDays(1, from: date)) ?? Date() },
                set: { end = DateLocal.todayISO($0) }
              ),
              in: (DateLocal.parseLocalDay(date) ?? Date())...,
              displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(Theme.rose)

            if !from.isEmpty {
              if until.isEmpty {
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
                      get: { parseTime(until) },
                      set: { next in until = formatTime(next) }
                    ),
                    minuteInterval: 5
                  )

                  Button {
                    until = ""
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
      } else if !from.isEmpty && !until.isEmpty {
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
                get: { parseTime(until) },
                set: { next in until = formatTime(next) }
              ),
              minuteInterval: 5
            )

            Button {
              until = ""
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
  }

  private var appleSubRow: some View {
    HStack {
      if !multiDay {
        if !from.isEmpty && until.isEmpty {
          Button("+ Add end time", action: addDefaultEndTime)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
        }
        Spacer()
        Button("Runs more than one day?") {
          multiDay = true
          if end == nil || (end ?? "") <= date {
            end = DateLocal.addDays(1, from: date)
          }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.roseInk)
      } else {
        Button("Just one day") {
          multiDay = false
          end = nil
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.roseInk)
        Spacer()
      }
    }
    .padding(.top, Theme.Spacing.sm)
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
    guard !saving else { return }
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else {
      app.toast = "Give it a name"
      return
    }
    let today = DateLocal.todayISO()
    if isPlan && date < today {
      app.toast = "Plans can't be set in the past"
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
    let saved = await app.createActivity(
      title: clean,
      description: notes.trimmingCharacters(in: .whitespacesAndNewlines),
      location: location.trimmingCharacters(in: .whitespacesAndNewlines),
      imageUrl: coverTrim,
      dateTime: when?.dateTime,
      endsAt: when?.endsAt,
      fromSomeday: !isPlan || draft?.fromSomeday == true
    )
    // A failed save keeps the sheet open so nothing typed is lost.
    guard saved else {
      saving = false
      return
    }
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

  private func fieldLabel(_ text: String, hint: String? = nil) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
      if let hint {
        Text(hint)
          .font(.caption)
          .foregroundStyle(Theme.inkFaint)
      }
    }
    .padding(.top, Theme.Spacing.xl)
    .padding(.bottom, Theme.Spacing.s6)
  }
}
