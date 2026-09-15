import SwiftUI

enum OrbSetupMode {
  case firstRun
  case create
}

struct OrbSetupView: View {
  var mode: OrbSetupMode = .firstRun
  var onFinished: (() -> Void)? = nil

  @EnvironmentObject private var app: AppModel
  @State private var withPeople = false
  @State private var name = ""
  @State private var busy = false

  private var placeholder: String {
    withPeople ? Copy.Orbs.crewPlaceholder : Copy.Orbs.personalPlaceholder
  }

  var body: some View {
    if mode == .create {
      createBody
    } else {
      firstRunBody
    }
  }

  private var firstRunBody: some View {
    ZStack {
      Theme.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(Copy.Orbs.setupTitle)
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.top, 48)
            .padding(.bottom, 8)

          Text(Copy.Orbs.setupLead)
            .font(.title3.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.bottom, 20)

          formFields
        }
        .padding(24)
      }
    }
  }

  private var createBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(Copy.Orbs.setupTitle)
        .font(.title2.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .padding(.bottom, 8)

      Text(Copy.Orbs.setupLead)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.inkSoft)
        .padding(.bottom, 20)

      formFields
      Spacer(minLength: 0)
    }
    .padding(20)
    .padding(.bottom, 8)
    .background(Theme.paper)
  }

  private var formFields: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        kindTab(Copy.Orbs.justYou, selected: !withPeople) {
          withPeople = false
        }
        kindTab(Copy.Orbs.withSomeone, selected: withPeople) {
          withPeople = true
        }
      }

      Text(Copy.Orbs.orbName)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
        .padding(.top, 20)
        .padding(.bottom, 8)

      TextField(placeholder, text: $name)
        .padding(14)
        .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      Button {
        Task { await submit() }
      } label: {
        HStack {
          Spacer()
          if busy { ProgressView().tint(.white) }
          else {
            Text(withPeople ? Copy.Orbs.invitePerson : Copy.Orbs.startPlanning)
              .font(.headline)
              .foregroundStyle(.white)
          }
          Spacer()
        }
        .padding(.vertical, 14)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .padding(.top, 20)
    }
  }

  private func submit() async {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !busy, !clean.isEmpty else { return }
    busy = true
    defer { busy = false }
    if mode == .create {
      let ok = await app.addSpace(name: clean, withPeople: withPeople)
      if ok { onFinished?() }
    } else {
      await app.completeFirstOrb(name: clean, withPeople: withPeople)
    }
  }

  private func kindTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(selected ? .semibold : .medium))
        .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Theme.paper : Theme.ink.opacity(0.08))
            .shadow(color: selected ? Theme.ink.opacity(0.14) : .clear, radius: selected ? 2 : 0, y: 1)
        }
    }
    .buttonStyle(.plain)
  }
}
