import SwiftUI

enum OrbSetupMode {
  case firstRun
  case create
}

struct OrbSetupView: View {
  var mode: OrbSetupMode = .firstRun
  var initialWithPeople: Bool = false
  var onFinished: (() -> Void)? = nil

  @EnvironmentObject private var app: AppModel
  @State private var withPeople: Bool
  @State private var name = ""
  @State private var busy = false

  init(mode: OrbSetupMode = .firstRun, initialWithPeople: Bool = false, onFinished: (() -> Void)? = nil) {
    self.mode = mode
    self.initialWithPeople = initialWithPeople
    self.onFinished = onFinished
    _withPeople = State(initialValue: initialWithPeople)
  }

  private var placeholder: String {
    if withPeople { return Copy.Orbs.crewPlaceholder }
    let mine = SpaceInfo.soloTitle(from: app.space?.myName ?? "")
    return mine.isEmpty ? Copy.Orbs.personalPlaceholder : mine
  }

  var body: some View {
    if mode == .create {
      createBody
    } else {
      firstRunBody
    }
  }

  private var firstRunBody: some View {
    OnboardingScaffold(title: Copy.Orbs.setupTitle, lead: Copy.Orbs.setupLead) {
      formFields
    }
  }

  private var createBody: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      Text(Copy.Orbs.createTitle)
        .font(.title2.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .padding(.bottom, Theme.Spacing.sm)

      Text(Copy.Orbs.setupLead)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.inkSoft)
        .padding(.bottom, Theme.Spacing.lg)

      formFields
      Spacer(minLength: 0)
    }
    .padding(Theme.Spacing.lg)
    .padding(.bottom, Theme.Spacing.sm)
    .background(Theme.paper)
  }

  private var formFields: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      HStack(spacing: Theme.Spacing.sm) {
        kindTab(Copy.Orbs.justYou, selected: !withPeople) {
          withPeople = false
        }
        kindTab(Copy.Orbs.withSomeone, selected: withPeople) {
          withPeople = true
        }
      }

      FDTextField(label: Copy.Orbs.orbName, placeholder: placeholder, text: $name)
        .textInputAutocapitalization(.words)
        .submitLabel(.go)
        .onSubmit { Task { await submit() } }
        .padding(.top, Theme.Spacing.lg)

      FDButton(
        withPeople ? Copy.Orbs.invitePerson : Copy.Orbs.startPlanning,
        variant: .primary,
        loading: busy,
        disabled: busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ) {
        await submit()
      }
      .padding(.top, Theme.Spacing.s26)
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
        .font(.fdSubhead.weight(selected ? .semibold : .medium))
        .foregroundStyle(selected ? Theme.ink : Theme.ink2)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.s7)
        .padding(.horizontal, Theme.Spacing.md)
        // Same as the PWA's segmented tabs: capsules on a soft fill, the
        // chosen one lifted onto warm paper.
        .background {
          Capsule()
            .fill(selected ? Theme.paperWarm : Theme.fillTertiary)
            .shadow(color: selected ? Theme.hairline : .clear, radius: selected ? Theme.Spacing.s3 / 2 : Theme.Spacing.none, y: selected ? Theme.Spacing.px : Theme.Spacing.none)
        }
    }
    .buttonStyle(.plain)
  }
}
