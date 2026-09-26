import SwiftUI

private enum SettingsConfirm: Identifiable, Hashable {
  case leave(solo: Bool)
  case remove(id: String, name: String)
  case purge(String)

  var id: String {
    switch self {
    case .leave: return "leave"
    case .remove(let id, _): return "rm-\(id)"
    case .purge(let id): return "purge-\(id)"
    }
  }

  var title: String {
    switch self {
    case .leave(true): return Copy.Orbs.deleteSoloTitle
    case .leave(false): return Copy.Orbs.leaveSharedTitle
    case .remove(_, let name): return Copy.Orbs.removeTitle(name: name)
    case .purge: return Copy.Orbs.deletePermanentTitle
    }
  }

  var message: String {
    switch self {
    case .leave(true): return Copy.Orbs.deleteSoloBody
    case .leave(false): return Copy.Orbs.leaveSharedBody
    case .remove: return Copy.Orbs.removeBody
    case .purge: return Copy.Orbs.deletePermanentBody
    }
  }

  var action: String {
    switch self {
    case .leave(true): return Copy.Orbs.deleteSoloAction
    case .leave(false): return Copy.Orbs.leaveAction
    case .remove(_, let name): return "Remove \(name)"
    case .purge: return Copy.Orbs.deletePermanent
    }
  }

  var cancel: String {
    switch self {
    case .leave: return Copy.Orbs.stay
    case .remove: return Copy.Orbs.keepThem
    case .purge: return Copy.Orbs.keep
    }
  }
}

/// Every sub-flow is a page in the one Settings stack — never a sheet on top.
private enum SettingsDestination: Hashable {
  case orbDetails
  case account
  case calendars
  case anotherOrb
  case orbSetup(withPeople: Bool)
  case pastOrbs
  case applePicker
  case notifications
}

struct SettingsView: View {
  private static let orbSize: CGFloat = Theme.TouchTarget.orbFace

  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var navPath = NavigationPath()
  @State private var confirm: SettingsConfirm?
  @State private var orbDraft = ""
  @State private var profileNameDraft = ""
  @State private var skipPersistOnDisappear = false
  @State private var spaceBusy = false
  @State private var appleOn = CalendarSync.isConnected
  @State private var appleName = CalendarSync.selectedName
  @State private var appleBusy = false
  @StateObject private var push = Push.shared
  @State private var pushBusy = false
  @State private var prefs = Alerts.Prefs()
  @State private var orbMuted = false
  @State private var appleCals: [DeviceCalendar] = []
  @State private var pendingAppleId: String?

  private var allOrbs: [SpaceInfo] {
    if !app.spaces.isEmpty { return app.spaces }
    if let one = app.space { return [one] }
    return []
  }

  private var activeOrbs: [SpaceInfo] {
    allOrbs.filter { !$0.frozen }
  }

  private var pastOrbs: [SpaceInfo] {
    allOrbs.filter { $0.frozen }
  }

  private func spaceOrbLabel(_ space: SpaceInfo) -> String {
    let label = space.peopleLabel
    return label.isEmpty ? "This Orb" : label
  }

  var body: some View {
    NavigationStack(path: $navPath) {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.s22) {
          if let space = app.space {
            if space.frozen {
              frozenBanner
            }
            orbsSection
            
            FDFormGroup {
              NavigationLink(value: SettingsDestination.orbDetails) {
                FDFormRow(label: spaceOrbLabel(space), glyph: .orb, action: nil) {
                  Text("›")
                    .font(.fdSubhead)
                    .foregroundStyle(Theme.inkFaint)
                }
              }
              .buttonStyle(.plain)
              
              Divider().overlay(Theme.separator)
              NavigationLink(value: SettingsDestination.account) {
                FDFormRow(label: "Account", glyph: .account, action: nil) {
                  Text("›")
                    .font(.fdSubhead)
                    .foregroundStyle(Theme.inkFaint)
                }
              }
              .buttonStyle(.plain)
              
              Divider().overlay(Theme.separator)
              NavigationLink(value: SettingsDestination.calendars) {
                FDFormRow(label: "External calendars", glyph: .calendar, action: nil) {
                  Text("›")
                    .font(.fdSubhead)
                    .foregroundStyle(Theme.inkFaint)
                }
              }
              .buttonStyle(.plain)

              Divider().overlay(Theme.separator)
              NavigationLink(value: SettingsDestination.notifications) {
                FDFormRow(label: "Notifications", glyph: .bell, action: nil) {
                  Text("›")
                    .font(.fdSubhead)
                    .foregroundStyle(Theme.inkFaint)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.s30)
      }
      .background(Theme.paper.ignoresSafeArea())
      .presentationBackground(Theme.paper)
      .navigationTitle("Settings")
      .navigationDestination(for: SettingsDestination.self) { dest in
        switch dest {
        case .orbDetails:
          if let space = app.space { orbDetailsView(space: space) }
        case .account:
          if let space = app.space { accountView(space: space) }
        case .calendars:
          calendarsView
        case .anotherOrb:
          anotherOrbView
        case .orbSetup(let withPeople):
          OrbSetupView(mode: .create, initialWithPeople: withPeople) {
            dismiss()
          }
          .environmentObject(app)
          .navigationBarTitleDisplayMode(.inline)
        case .pastOrbs:
          pastOrbsView
        case .applePicker:
          applePickerView
        case .notifications:
          notificationsView
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            Task {
              await persistOrbName()
              dismiss()
            }
          }
        }
      }
      .onChange(of: app.space?.id) { _, _ in
        confirm = nil
        syncOrbDraft()
        syncProfileDraft()
      }
      .onAppear {
        syncOrbDraft()
        syncProfileDraft()
      }
      .onDisappear {
        if skipPersistOnDisappear { return }
        Task {
          await persistOrbName()
          await persistProfileName()
        }
      }
    }
    .settingsConfirm($confirm) { item in
      runConfirm(item)
    }
    .onAppear {
      appleOn = CalendarSync.isConnected
      appleName = CalendarSync.selectedName
    }
  }

  private var frozenBanner: some View {
    FDCard(variant: .sunk, padding: .md) {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text(Copy.Orbs.viewingFrozenBanner)
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)
        if let firstActive = activeOrbs.first {
          FDButton(Copy.Orbs.switchBackToActive, variant: .secondary, size: .sm) {
            switchOrb(firstActive.id)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var orbsSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      sectionLabel(Copy.Orbs.yourOrbs)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.orbSize), spacing: Theme.Spacing.base)], alignment: .leading, spacing: Theme.Spacing.row) {
        plusTile
        ForEach(activeOrbs, id: \.id) { orb in
          orbTile(orb)
        }
      }
      .padding(Theme.Spacing.md)
      .background(Theme.fillQuaternary, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
    }
  }

  private struct OrbFaceChip: Identifiable {
    let id: String
    let letter: String
    let them: Bool
  }

  private func orbFaceChips(for orb: SpaceInfo) -> [OrbFaceChip] {
    if !orb.members.isEmpty {
      let mine = orb.members.first { $0.id.compare(orb.myId, options: .caseInsensitive) == .orderedSame }
      let others = orb.members.filter { $0.id.compare(orb.myId, options: .caseInsensitive) != .orderedSame }
      let ordered = (mine != nil) ? ([mine!] + others) : orb.members
      return ordered.map { m in
        OrbFaceChip(
          id: m.id,
          letter: String(m.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased(),
          them: m.id.compare(orb.myId, options: .caseInsensitive) != .orderedSame
        )
      }
    }
    var list: [OrbFaceChip] = [
      OrbFaceChip(
        id: "me",
        letter: String(orb.myName.prefix(1)).uppercased(),
        them: false
      )
    ]
    if let partner = orb.partnerName, !partner.isEmpty {
      list.append(
        OrbFaceChip(
          id: "them",
          letter: String(partner.prefix(1)).uppercased(),
          them: true
        )
      )
    }
    return list
  }

  private func orbTile(_ orb: SpaceInfo) -> some View {
    let active = orb.id == app.space?.id
    let faces = orbFaceChips(for: orb)
    return Button {
      switchOrb(orb.id)
    } label: {
      VStack(spacing: Theme.Spacing.s6) {
        ZStack {
          Circle()
            .fill(active ? Theme.sageWash : Theme.fillTertiary)
          orbFaceStack(faces)
        }
        .frame(width: Self.orbSize, height: Self.orbSize)
        .overlay {
          if active {
            // A soft green glow, not a hard line: the bold name carries it too.
            Circle()
              .stroke(Theme.sage, lineWidth: Theme.TouchTarget.ringWidth)
          }
        }

        Text(orb.peopleLabel.isEmpty ? " " : orb.peopleLabel)
          .font(active ? .caption.weight(.semibold) : .caption)
          .foregroundStyle(active ? Theme.ink : Theme.inkSoft)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(width: Self.orbSize)
      }
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private var plusTile: some View {
    Button {
      navPath.append(SettingsDestination.anotherOrb)
    } label: {
      VStack(spacing: Theme.Spacing.s6) {
        ZStack {
          Circle()
            .fill(Theme.fillTertiary)
          Text("+")
            .font(.title2.weight(.medium))
            .foregroundStyle(Theme.ink)
            .offset(y: Theme.Spacing.opticalNudge)
        }
        .frame(width: Self.orbSize, height: Self.orbSize)
        Text("\u{00a0}")
          .font(.caption)
          .frame(width: Self.orbSize)
      }
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
    .accessibilityLabel(Copy.Orbs.anotherOrb)
  }

  /// Where each face sits in an Orb tile, in steps of (face − overlap) / 2
  /// from the centre: one centred, two side by side, three as two over one,
  /// four as a square. Past four, the last spot says +N. Same as the PWA.
  private static let orbSpots: [Int: [(CGFloat, CGFloat)]] = [
    1: [(0, 0)],
    2: [(-1, 0), (1, 0)],
    3: [(-1, -1), (1, -1), (0, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
  ]

  private func orbFaceStack(_ faces: [OrbFaceChip]) -> some View {
    let spots = Self.orbSpots[min(max(faces.count, 1), 4)] ?? []
    let more = faces.count > 4 ? faces.count - 3 : 0
    let shown = Array(faces.prefix(more > 0 ? 3 : 4))
    let step = (Theme.TouchTarget.avatarFace - Theme.Spacing.xs) / 2
    return ZStack {
      if more > 0 {
        orbFaceCircle(fill: Theme.fillSecondary) {
          Text("+\(more)")
            .font(.fdTiny)
        }
        .offset(x: spots[3].0 * step, y: spots[3].1 * step)
      }
      // Drawn last-first so the first face sits on top, like the PWA.
      ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { idx, f in
        orbFaceCircle(fill: Theme.faceColor(for: f.id)) {
          Text(f.letter)
            .font(.fdCaption.weight(.bold))
        }
        .offset(x: spots[idx].0 * step, y: spots[idx].1 * step)
      }
    }
  }

  private func orbFaceCircle<Label: View>(fill: Color, @ViewBuilder label: () -> Label) -> some View {
    ZStack {
      Circle().fill(fill)
      label()
        .foregroundStyle(Theme.faceInk)
        .offset(y: Theme.Spacing.opticalNudge)
    }
    .frame(width: Theme.TouchTarget.avatarFace, height: Theme.TouchTarget.avatarFace)
    .overlay(Circle().stroke(Theme.paperWarm, lineWidth: Theme.TouchTarget.ringWidth))
    .fixedSize()
  }

  private var anotherOrbView: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      FDActionRow(
        title: Copy.Orbs.startNew,
        note: Copy.Orbs.startNewNote,
        glyph: "+"
      ) {
        navPath.append(SettingsDestination.orbSetup(withPeople: false))
      }

      Rectangle()
        .fill(Theme.hairline)
        .frame(height: Theme.TouchTarget.hairlineWidth)

      FDActionRow(
        title: Copy.Orbs.joinWithCode,
        note: Copy.Orbs.joinWithCodeNote,
        glyph: "→"
      ) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.sheetHandoffLong) {
          app.showJoinOrb = true
        }
      }
      Spacer(minLength: 0)
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle(Copy.Orbs.anotherOrb)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func orbDetailsView(space: SpaceInfo) -> some View {
    let soloOrb = space.members.count <= 1
    let soloOrbs = activeOrbs.filter { $0.members.count <= 1 }
    let isPersonalOrb = soloOrb && (space.isHomeSoloName() || soloOrbs.count <= 1)
    let leaveLabel = soloOrb ? Copy.Orbs.deleteSoloAction : Copy.Orbs.leaveAction
    let justYou = SpaceInfo.soloTitle(from: space.myName)
    let placeholder = soloOrb ? (justYou.isEmpty ? Copy.Orbs.personalPlaceholder : justYou) : Copy.Orbs.crewPlaceholder
    
    return ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        FDTextField(
          placeholder: placeholder,
          text: $orbDraft
        )
        .disabled(space.frozen || spaceBusy)
        .onSubmit { Task { await persistOrbName() } }

        Text(Copy.Orbs.people)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.inkFaint)
          .padding(.top, Theme.Spacing.sm)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s10) {
              if !space.frozen && !isPersonalOrb {
                Button {
                  openInvite()
                } label: {
                  VStack(spacing: Theme.Spacing.xs) {
                    ZStack {
                      Circle()
                        .fill(Theme.fillTertiary)
                      Text("+")
                        .font(.fdCallout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .offset(y: Theme.Spacing.opticalNudge)
                    }
                    .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
                    .fixedSize()

                    Text("Invite")
                      .font(.caption)
                      .foregroundStyle(Theme.ink)
                    Text("More")
                      .font(.caption2)
                      .foregroundStyle(Theme.inkFaint)
                      .frame(height: Theme.Spacing.s13)
                  }
                  .frame(width: Theme.TouchTarget.orbTile)
                }
                .buttonStyle(.plain)
              }

              ForEach(space.members, id: \.id) { member in
                let removable = !space.frozen && space.myRole == "admin" && space.members.count >= 3 && member.id != space.myId
                ZStack(alignment: .topLeading) {
                  VStack(spacing: Theme.Spacing.xs) {
                    face(member.name, id: member.id, size: Theme.TouchTarget.avatarMd)
                    Text(member.name)
                      .font(.caption)
                      .foregroundStyle(Theme.ink)
                      .lineLimit(1)
                      .frame(width: Theme.TouchTarget.orbTile)
                    Text(member.id == space.myId ? "You" : " ")
                      .font(.caption2)
                      .foregroundStyle(Theme.inkFaint)
                      .frame(height: Theme.Spacing.s13)
                  }
                  .frame(width: Theme.TouchTarget.orbTile)

                  if removable {
                    Button {
                      confirm = .remove(id: member.id, name: member.name)
                    } label: {
                      Image(systemName: "minus")
                        .font(.fdMicro)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: Theme.Spacing.base, height: Theme.Spacing.base)
                        .background(Theme.paperWarm, in: Circle())
                        .overlay(Circle().stroke(Theme.hairline, lineWidth: Theme.TouchTarget.hairlineWidth))
                        .shadow(color: Theme.fillSecondary, radius: Theme.Shadow.badgeRadius, y: Theme.Shadow.badgeY)
                    }
                    .buttonStyle(.plain)
                    .offset(x: Theme.Spacing.removeBadgeX, y: Theme.Spacing.removeBadgeY)
                  }
                }
              }
            }
            .padding(.horizontal, Theme.Spacing.xxs)
            .padding(.bottom, Theme.Spacing.xs)
          }

          if isPersonalOrb {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
              Rectangle()
                .fill(Theme.hairline)
                .frame(height: Theme.TouchTarget.hairlineWidth)

              Text(Copy.Orbs.personalPrivateNote)
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)

              Button {
                navPath.append(SettingsDestination.orbSetup(withPeople: true))
              } label: {
                Text("+ \(Copy.Orbs.startSharedOrb)")
                  .font(.footnote.weight(.semibold))
                  .foregroundStyle(Theme.ink)
                  .padding(.horizontal, Theme.Spacing.md)
                  .padding(.vertical, Theme.Spacing.s7)
                  .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
              }
              .buttonStyle(.plain)
            }
            .padding(.top, Theme.Spacing.xs)
          }
        }
        .padding(Theme.Spacing.s10)
        .background(Theme.fillQuaternary, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))

        Text(Copy.Orbs.descriptor)
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, Theme.Spacing.xs)

        if space.frozen {
          Text(Copy.Orbs.frozenNotice)
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, Theme.Spacing.xs)
        }

        if !space.frozen && !soloOrb {
          FDFormGroup {
            FDFormRow(label: "Mute this Orb", glyph: .bell) {
              Toggle("Mute this Orb", isOn: Binding(
                get: { orbMuted },
                set: { on in
                  orbMuted = on
                  Task {
                    do {
                      try await Alerts.setMuted(space.id, on)
                    } catch {
                      orbMuted = !on
                      app.toast = "Couldn’t save that. Check your connection and try again."
                    }
                  }
                }
              ))
              .labelsHidden()
              .tint(Theme.roseInk)
            }
          }
          .padding(.top, Theme.Spacing.sm)
          .task(id: space.id) { orbMuted = await Alerts.loadMuted(space.id) }
          Text("Alerts you set on plans still ring.")
            .font(.fdFootnote)
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, Theme.Spacing.xs)
        }

        if !space.frozen, space.myRole == "admin", space.members.count >= 3 {
          ForEach(space.members.filter { $0.id != space.myId }, id: \.id) { member in
            Button("Remove \(member.name)") {
              confirm = .remove(id: member.id, name: member.name)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xxs)
            .disabled(spaceBusy)
          }
        }

        if !space.frozen && !isPersonalOrb {
          Button(leaveLabel) {
            confirm = .leave(solo: soloOrb)
          }
          .buttonStyle(.plain)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, Theme.Spacing.xs)
          .padding(.top, Theme.Spacing.xs)
          .disabled(spaceBusy)
        } else if space.frozen {
          Button(Copy.Orbs.deletePermanent) {
            confirm = .purge(space.id)
          }
          .buttonStyle(.plain)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, Theme.Spacing.xs)
          .padding(.top, Theme.Spacing.xs)
          .disabled(spaceBusy)
        }
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      // This Orb, with its name beside it in a lighter weight.
      ToolbarItem(placement: .principal) {
        HStack(spacing: Theme.Spacing.s6) {
          Text(Copy.Orbs.thisOrb)
            .font(.headline)
            .foregroundStyle(Theme.ink)
          if !space.peopleLabel.isEmpty {
            Text(space.peopleLabel)
              .font(.headline.weight(.regular))
              .foregroundStyle(Theme.inkSoft)
          }
        }
        .lineLimit(1)
      }
    }
  }

  private var pastOrbsView: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
          ForEach(pastOrbs, id: \.id) { pOrb in
            let isCurrent = pOrb.id == app.space?.id
            let faces = orbFaceChips(for: pOrb)

            FDCard(variant: .sunk, padding: .md) {
              VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .center) {
                  Text(pOrb.peopleLabel.isEmpty ? " " : pOrb.peopleLabel)
                    .font(.fdHeadline)
                    .foregroundStyle(Theme.ink)

                  Spacer()

                  HStack(spacing: Theme.Spacing.overlapSm) {
                    ForEach(faces.prefix(3)) { f in
                      ZStack {
                        Circle()
                          .fill(Theme.faceColor(for: f.id))
                        Text(f.letter)
                          .font(.fdCaption2.weight(.bold))
                          .foregroundStyle(Theme.faceInk)
                          .offset(y: Theme.Spacing.opticalNudge)
                      }
                      .frame(width: Theme.TouchTarget.avatarChip, height: Theme.TouchTarget.avatarChip)
                      .overlay(Circle().stroke(Theme.paperWarm, lineWidth: Theme.TouchTarget.ringWidth))
                      .fixedSize()
                    }
                  }
                }

                Divider()

                HStack(spacing: Theme.Spacing.s10) {
                  if isCurrent {
                    FDButton("Currently viewing", variant: .primary, size: .sm) {}
                      .disabled(true)
                  } else {
                    FDButton("View", variant: .secondary, size: .sm) {
                      switchOrb(pOrb.id)
                    }
                  }

                  Spacer()

                  FDButton(Copy.Orbs.deletePermanent, variant: .ghost, size: .sm) {
                    confirm = .purge(pOrb.id)
                  }
                }
              }
            }
          }
        }
        .padding(Theme.Spacing.lg)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle(Copy.Orbs.pastOrbs)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func accountView(space: SpaceInfo) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.s22) {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          sectionLabel("Profile")
          FDFormGroup {
            HStack(spacing: Theme.Spacing.md) {
              FDAvatar(name: profileNameDraft.isEmpty ? space.myName : profileNameDraft, personId: space.myId, size: .md)
              TextField("Aline", text: $profileNameDraft)
                .font(.fdBody)
                .foregroundStyle(Theme.ink)
                .submitLabel(.done)
                .onSubmit {
                  Task { await persistProfileName() }
                }
            }
            .padding(.horizontal, Theme.Spacing.row)
            .padding(.vertical, Theme.Spacing.s10)
            .frame(minHeight: Theme.TouchTarget.formRow)
            .contentShape(Rectangle())

            if !pastOrbs.isEmpty {
              Divider().overlay(Theme.separator)
              FDFormRow(
                label: Copy.Orbs.pastOrbs,
                note: Copy.Orbs.pastOrbsSub,
                glyph: .history,
                action: { navPath.append(SettingsDestination.pastOrbs) }
              ) {
                HStack(spacing: Theme.Spacing.s6) {
                  FDPill(title: "\(pastOrbs.count)", variant: .neutral, size: .sm)
                  Text("›")
                    .font(.fdSubhead)
                    .foregroundStyle(Theme.inkFaint)
                }
              }
            }
          }
        }
        
        if app.authPhase == .signedIn {
          signOutSection
        }
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Account")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var calendarsView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        FDFormGroup {
          FDFormRow(label: Copy.Availability.appleCalendar, glyph: .calendar) {
            Toggle("Connect Apple Calendar", isOn: appleToggle)
              .labelsHidden()
              .tint(Theme.roseInk)
              .disabled(appleBusy)
          }

          if appleOn {
            Divider().overlay(Theme.separator)
            FDFormRow(
              label: appleName ?? "Choose calendar",
              note: appleBusy ? "…" : nil,
              action: { Task { await openApplePicker() } }
            ) {
              Text(appleName == nil ? "›" : "Change ›")
                .font(.fdSubhead)
                .foregroundStyle(Theme.inkFaint)
            }

            if appleName != nil {
              Divider().overlay(Theme.separator)
              FDFormRow(
                label: "Refresh overlay",
                note: appleBusy ? "…" : nil,
                action: { Task { await importApple() } }
              ) {
                Text(appleBusy ? "…" : "›")
                  .font(.fdSubhead)
                  .foregroundStyle(Theme.inkFaint)
              }
            }
          }
        }

        Text(Copy.Availability.settingsNoteIos)
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("External calendars")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var notificationsView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        FDFormGroup {
          FDFormRow(label: "Push notifications", glyph: .bell) {
            Toggle("Notifications", isOn: pushToggle)
              .labelsHidden()
              .tint(Theme.roseInk)
              .disabled(pushBusy)
          }
        }

        Text(pushNote)
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)

        sectionLabel("Alerts")
          .padding(.top, Theme.Spacing.base)
        FDFormGroup {
          FDFormRow(label: "Plans") {
            pickMenu(
              "Plans",
              value: prefs.alertTimed.first ?? Alerts.none,
              options: Alerts.options(allDay: false)
            ) { v in changePrefs { $0.alertTimed = v == Alerts.none ? [] : [v] } }
          }
          Divider().overlay(Theme.separator)
          FDFormRow(label: "All-day plans") {
            pickMenu(
              "All-day plans",
              value: prefs.alertAllDay.first ?? Alerts.none,
              options: Alerts.options(allDay: true)
            ) { v in changePrefs { $0.alertAllDay = v == Alerts.none ? [] : [v] } }
          }
        }
        Text("Yours only. Change them on any plan.")
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)

        sectionLabel("Morning summary")
          .padding(.top, Theme.Spacing.base)
        FDFormGroup {
          FDFormRow(label: "Morning summary") {
            Toggle("Morning summary", isOn: Binding(
              get: { prefs.summaryMinute != nil },
              set: { on in changePrefs { $0.summaryMinute = on ? 480 : nil } }
            ))
            .labelsHidden()
            .tint(Theme.roseInk)
          }
          if let minute = prefs.summaryMinute {
            Divider().overlay(Theme.separator)
            FDFormRow(label: "Time") {
              pickMenu("Time", value: minute, options: Alerts.summaryTimes) { v in
                changePrefs { $0.summaryMinute = v }
              }
            }
          }
        }
        Text("Today’s plans, on days you have some")
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)

        FDFormGroup {
          FDFormRow(label: "Quiet overnight") {
            Toggle("Quiet overnight", isOn: Binding(
              get: { prefs.quietHours },
              set: { on in changePrefs { $0.quietHours = on } }
            ))
            .labelsHidden()
            .tint(Theme.roseInk)
          }
        }
        .padding(.top, Theme.Spacing.base)
        Text("From 10 pm to 8 am, news from others waits until morning. Alerts you set still ring.")
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await push.refresh()
      prefs = await Alerts.loadPrefs()
    }
  }

  /// The system pop-up menu with a check beside the current choice, as
  /// Calendar's Alert row.
  private func pickMenu(
    _ title: String,
    value: Int,
    options: [Alerts.Option],
    onPick: @escaping (Int) -> Void
  ) -> some View {
    Menu {
      Picker(title, selection: Binding(get: { value }, set: onPick)) {
        ForEach(options, id: \.value) { option in
          Text(option.label).tag(option.value)
        }
      }
    } label: {
      Text(options.first { $0.value == value }?.label ?? "None")
        .font(.fdSubhead)
        .foregroundStyle(Theme.inkSoft)
    }
  }

  /// Save as they change, like iOS Settings; put it back if it didn't take.
  private func changePrefs(_ edit: (inout Alerts.Prefs) -> Void) {
    let before = prefs
    var next = prefs
    edit(&next)
    prefs = next
    Task {
      do {
        try await Alerts.savePrefs(next)
      } catch {
        prefs = before
        app.toast = "Couldn’t save that. Check your connection and try again."
      }
    }
  }

  private var pushNote: String {
    if pushBusy { return "Working…" }
    switch push.state {
    case .denied:
      return "Blocked. Turn them on in iPhone Settings → Fordays → Notifications"
    case .on:
      return "On. You’ll hear when someone adds to Someday, makes a plan, changes the day, or joins"
    case .off:
      return "Hear when someone adds to Someday, makes a plan, changes the day, or joins"
    }
  }

  private var pushToggle: Binding<Bool> {
    Binding(
      get: { push.state == .on },
      set: { on in
        guard !pushBusy else { return }
        Task {
          pushBusy = true
          app.toast = on ? await push.enable() : await push.disable()
          pushBusy = false
        }
      }
    )
  }

  private var appleToggle: Binding<Bool> {
    Binding(
      get: { appleOn },
      set: { on in
        appleOn = on
        Task { await setAppleConnected(on) }
      }
    )
  }

  private func setAppleConnected(_ on: Bool) async {
    if !on {
      appleOn = false
      appleName = nil
      appleCals = []
      await app.disconnectApple()
      return
    }
    appleBusy = true
    let ok: Bool
    if CalendarSync.hasFullAccess {
      ok = true
    } else {
      ok = await CalendarSync.requestAccess()
    }
    if !ok {
      appleBusy = false
      appleOn = false
      app.toast = "Allow calendars in iPhone Settings → Fordays"
      return
    }
    let list = CalendarSync.listCalendars()
    appleBusy = false
    if list.isEmpty {
      appleOn = false
      app.toast = "No calendars found on this iPhone"
      return
    }
    appleOn = true
    appleCals = list
    navPath.append(SettingsDestination.applePicker)
  }

  private func openApplePicker() async {
    appleBusy = true
    let ok: Bool
    if CalendarSync.hasFullAccess {
      ok = true
    } else {
      ok = await CalendarSync.requestAccess()
    }
    appleBusy = false
    guard ok else {
      app.toast = "Allow calendars in iPhone Settings → Fordays"
      return
    }
    appleCals = CalendarSync.listCalendars()
    navPath.append(SettingsDestination.applePicker)
  }

  private func importApple(_ cal: DeviceCalendar? = nil) async {
    let chosen = cal ?? appleCals.first(where: { $0.id == CalendarSync.selectedId })
    guard let chosen else {
      app.toast = "Choose a calendar first"
      return
    }
    appleBusy = true
    CalendarSync.saveCalendar(chosen)
    appleName = chosen.summary
    appleOn = true
    do {
      try await app.replaceExternal(CalendarSync.fetchEvents(), source: "apple")
      app.watchDeviceCalendars()
      let n = CalendarSync.fetchEvents().count
      app.toast = n == 0
        ? "\(chosen.summary) — nothing in the next few months"
        : "\(chosen.summary) — \(n) events"
    } catch {
      app.toast = app.userFriendlyCalendarError(error)
    }
    appleBusy = false
  }

  private var applePickerView: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
          Text(Copy.Availability.pickerLead)
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
          let mine = appleCals.filter(\.primary)
          let other = appleCals.filter { !$0.primary }
          if !mine.isEmpty {
            applePickerSection(title: "My calendars", items: mine)
          }
          if !other.isEmpty {
            applePickerSection(title: "Other", items: other)
          }
        }
        .padding(Theme.Spacing.lg)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Import calendars")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Import") {
          let chosen = appleCals.first(where: { $0.id == pendingAppleId })
            ?? appleCals.first(where: \.primary)
            ?? appleCals.first
          Task {
            await importApple(chosen)
            if !navPath.isEmpty { navPath.removeLast() }
          }
        }
        .fontWeight(.semibold)
        .disabled(appleBusy || appleCals.isEmpty)
      }
    }
    .onDisappear {
      // Backing out without choosing leaves Apple Calendar off, like the PWA picker.
      if CalendarSync.selectedId == nil {
        appleOn = false
        CalendarSync.setConnected(false)
      }
    }
    .onAppear {
      pendingAppleId = CalendarSync.selectedId
        ?? appleCals.first(where: \.primary)?.id
        ?? appleCals.first?.id
    }
  }

  private func applePickerSection(title: String, items: [DeviceCalendar]) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
      VStack(spacing: Theme.Spacing.none) {
        ForEach(items) { cal in
          Button {
            pendingAppleId = cal.id
          } label: {
            HStack(spacing: Theme.Spacing.md) {
              FormGlyphIcon(glyph: .calendar)
              Text(cal.primary ? "\(cal.summary) · Primary" : cal.summary)
                .font(.body)
                .foregroundStyle(Theme.ink)
              Spacer()
              Image(systemName: pendingAppleId == cal.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(pendingAppleId == cal.id ? Theme.roseInk : Theme.inkFaint)
            }
            .padding(.vertical, Theme.Spacing.s10)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var signOutSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      sectionLabel("Session")
      FDFormGroup {
        FDFormRow(label: "Sign out", glyph: .signOut, destructive: true) {
          Task {
            await app.signOut()
            dismiss()
          }
        }
      }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(Theme.inkFaint)
  }

  private func face(_ name: String, id: String, size: CGFloat = Theme.TouchTarget.avatarMd) -> some View {
    FDAvatar(name: name, personId: id, size: size <= 24 ? .sm : .md)
  }

  private func isDefaultOrbName(_ name: String) -> Bool {
    let raw = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return raw.isEmpty
      || raw.caseInsensitiveCompare("Fordays") == .orderedSame
      || raw.caseInsensitiveCompare("Someday") == .orderedSame
  }

  private func syncOrbDraft() {
    guard let space = app.space else { return }
    orbDraft = isDefaultOrbName(space.name) ? "" : space.name
  }

  private func syncProfileDraft() {
    guard let space = app.space else { return }
    profileNameDraft = space.myName
  }

  private func persistOrbName() async {
    guard let space = app.space, !space.frozen else { return }
    let current = isDefaultOrbName(space.name) ? "" : space.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let next = orbDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if next.isEmpty {
      orbDraft = current
      return
    }
    guard next != current else { return }
    await app.renameCurrentSpace(next)
  }

  private func persistProfileName() async {
    guard let space = app.space else { return }
    let current = space.myName
    let next = profileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if next.isEmpty {
      profileNameDraft = current
      return
    }
    guard next != current else { return }
    do {
      try await app.updateDisplayName(next)
    } catch {
      app.toast = "Couldn’t save name"
    }
  }

  private func switchOrb(_ id: String) {
    guard !spaceBusy, id != app.space?.id else { return }
    skipPersistOnDisappear = true
    spaceBusy = true
    Task {
      await persistOrbName()
      dismiss()
      await app.switchToSpace(id)
      spaceBusy = false
    }
  }

  /// Invite is its own sheet, so Settings closes first — never stacked.
  private func openInvite() {
    dismiss()
    DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.sheetHandoffLong) {
      app.pendingInviteShare = true
    }
  }

  private func runConfirm(_ item: SettingsConfirm) {
    switch item {
    case .leave:
      leaveOrb()
    case .remove(let id, _):
      removeMember(id)
    case .purge(let id):
      deleteOrb(id)
    }
  }

  private func removeMember(_ userId: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.removeMember(userId: userId)
      confirm = nil
      spaceBusy = false
    }
  }

  private func leaveOrb() {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.leaveCurrentSpace()
      confirm = nil
      spaceBusy = false
    }
  }

  private func deleteOrb(_ id: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.deletePastOrb(id)
      confirm = nil
      if pastOrbs.isEmpty {
        navPath = NavigationPath()
      }
      spaceBusy = false
    }
  }

  private func initial(_ name: String) -> String {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(clean.prefix(1)).uppercased()
  }
}

private extension View {
  func settingsConfirm(
    _ confirm: Binding<SettingsConfirm?>,
    run: @escaping (SettingsConfirm) -> Void
  ) -> some View {
    confirmationDialog(
      confirm.wrappedValue?.title ?? "",
      isPresented: Binding(
        get: { confirm.wrappedValue != nil },
        set: { if !$0 { confirm.wrappedValue = nil } }
      ),
      titleVisibility: .visible,
      presenting: confirm.wrappedValue
    ) { item in
      Button(item.action, role: .destructive) { run(item) }
      Button(item.cancel, role: .cancel) { confirm.wrappedValue = nil }
    } message: { item in
      Text(item.message)
    }
  }
}
