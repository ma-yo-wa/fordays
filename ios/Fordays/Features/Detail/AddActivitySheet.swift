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
        title: "A bucket-list idea",
        note: "Something you want to do, with no date yet.",
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
  var onClose: () -> Void

  @State private var title = ""
  @State private var notes = ""
  @State private var cover = ""
  @State private var date = DateLocal.todayISO()
  @State private var from = ""
  @State private var until = ""
  @State private var end: String?
  @State private var multiDay = false
  @State private var pickerOpen = false
  @State private var saving = false

  private var isPlan: Bool { kind.isPlan }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(isPlan ? "New plan" : "New bucket-list idea")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, 14)

        fieldLabel(isPlan ? "Plan" : "Idea")
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

          fieldLabel("From", hint: "— optional")
          timeRow($from)

          fieldLabel(
            "Until",
            hint: multiDay ? "— on the last day, optional" : "— optional"
          )
          timeRow($until)

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
            .padding(.top, 14)
          } else {
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
        }

        fieldLabel("Cover", hint: "— optional")
        CoverPickerView(cover: $cover, titleHint: { title })

        HStack(spacing: 10) {
          ghost("Cancel", action: onClose)
          accent(isPlan ? "Add plan" : "Add idea") {
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
    return HStack(spacing: 8) {
      chip("Today", value: today)
      chip("Tomorrow", value: tomorrow)
      chip("This weekend", value: weekend)
      Button {
        pickerOpen.toggle()
      } label: {
        Text(pickerOpen ? "Done" : "Another day…")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            pickerOpen ? Theme.ink.opacity(0.12) : Theme.ink.opacity(0.06),
            in: Capsule()
          )
      }
      .buttonStyle(.plain)
    }
    .padding(.bottom, 8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(on ? Theme.rose : Theme.ink.opacity(0.06), in: Capsule())
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
    saving = false
    onClose()
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

  private func timeRow(_ text: Binding<String>) -> some View {
    HStack(spacing: 8) {
      TextField("HH:MM", text: text)
        .keyboardType(.numbersAndPunctuation)
        .padding(12)
        .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      if !text.wrappedValue.isEmpty {
        Button("Clear") { text.wrappedValue = "" }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.inkFaint)
      }
    }
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
        .background(Theme.rose, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .disabled(saving)
  }
}
