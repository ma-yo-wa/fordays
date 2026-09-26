import SwiftUI

private enum SettingsConfirm: Identifiable, Hashable {
  case leave(orbId: String, solo: Bool)
  case remove(orbId: String, id: String, name: String)
  case purge(String)
  case signOut

  var id: String {
    switch self {
    case .leave(let orbId, _): return "leave-\(orbId)"
    case .remove(_, let id, _): return "rm-\(id)"
    case .purge(let id): return "purge-\(id)"
    case .signOut: return "sign-out"
    }
  }

  var title: String {
    switch self {
    case .leave(_, true): return Copy.Orbs.deleteSoloTitle
    case .leave(_, false): return Copy.Orbs.leaveSharedTitle
    case .remove(_, _, let name): return Copy.Orbs.removeTitle(name: name)
    case .purge: return Copy.Orbs.deletePermanentTitle
    case .signOut: return "Sign out of Fordays?"
    }
  }

  var message: String {
    switch self {
    case .leave(_, true): return Copy.Orbs.deleteSoloBody
    case .leave(_, false): return Copy.Orbs.leaveSharedBody
    case .remove: return Copy.Orbs.removeBody
    case .purge: return Copy.Orbs.deletePermanentBody
    case .signOut: return "Your Orbs stay as they are. Sign back in any time."
    }
  }

  var action: String {
    switch self {
    case .leave(_, true): return Copy.Orbs.deleteSoloAction
    case .leave(_, false): return Copy.Orbs.leaveAction
    case .remove(_, _, let name): return "Remove \(name)"
    case .purge: return Copy.Orbs.deletePermanent
    case .signOut: return "Sign out"
    }
  }

  var cancel: String {
    switch self {
    case .leave: return Copy.Orbs.stay
    case .remove: return Copy.Orbs.keepThem
    case .purge: return Copy.Orbs.keep
    case .signOut: return "Cancel"
    }
  }
}

/// Every page is pushed in the one Settings stack, like iOS Settings: each
/// has its own title and the back button names the page underneath.
private enum SettingsDestination: Hashable {
  case orb(String)
  case account
  case calendars
  case newOrb(withPeople: Bool)
  case pastOrbs
  case applePicker
  case notifications
}

/// One thing you might search for, with the words people use for it.
private struct SettingsHit: Identifiable {
  let id: String
  let label: String
  let note: String
  let words: String
  let go: () -> Void
}

/// Settings as a full screen, opened from your face in the header. Same
/// pages and order as the PWA's Settings.
struct SettingsView: View {
  @EnvironmentObject private var app: AppModel
  @State private var navPath = NavigationPath()
  @State private var confirm: SettingsConfirm?
  @State private var query = ""
  @State private var email: String?
  @State private var orbDraft = ""
  @State private var profileNameDraft = ""
  @State private var spaceBusy = false
  @State private var appleOn = CalendarSync.isConnected
  @State private var appleChosen = CalendarSync.chosen
  @State private var appleBusy = false
  @StateObject private var push = Push.shared
  @State private var pushBusy = false
  @State private var prefs = Alerts.Prefs()
  @State private var orbMuted = false
  @State private var appleCals: [DeviceCalendar] = []
  @State private var pendingAppleIds: Set<String> = []

  /// Open straight on this Orb's page, from the switcher.
  var startOrbId: String? = nil
  /// Leave Settings, back to the tab you came from.
  var onClose: () -> Void

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

  private func orbName(_ orb: SpaceInfo) -> String {
    orb.peopleLabel.isEmpty ? Copy.Orbs.thisOrb : orb.peopleLabel
  }

  private var tabLabel: String {
    switch app.tab {
    case .bucket: return Copy.Tabs.ideas
    case .plans: return Copy.Tabs.plans
    case .memories: return Copy.Tabs.memories
    }
  }

  var body: some View {
    NavigationStack(path: $navPath) {
      rootPage
      .navigationDestination(for: SettingsDestination.self) { dest in
        destination(dest)
      }
      .onAppear { syncProfileDraft() }
      .onDisappear {
        Task { await persistProfileName() }
      }
    }
    .tint(Theme.roseInk)
    .settingsConfirm($confirm) { item in
      runConfirm(item)
    }
    .task {
      email = await app.currentEmail()
    }
    .onAppear {
      appleOn = CalendarSync.isConnected
      appleChosen = CalendarSync.chosen
    }
  }

  /// Back to the tab you came from.
  private var closeItem: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button(action: onClose) {
        HStack(spacing: Theme.Spacing.xxs) {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
          Text(tabLabel)
        }
        .foregroundStyle(Theme.roseInk)
      }
      .accessibilityLabel("Back to \(tabLabel)")
    }
  }

  /// From the switcher, an Orb's page stands alone: back goes straight home.
  @ViewBuilder
  private var rootPage: some View {
    if let startOrbId, let orb = allOrbs.first(where: { $0.id == startOrbId }) {
      orbView(orb)
        .navigationBarBackButtonHidden(true)
        .toolbar { closeItem }
    } else {
      mainPage
    }
  }

  private var mainPage: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.s22) {
          if query.trimmingCharacters(in: .whitespaces).isEmpty {
            mainRows
          } else {
            searchResults
          }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.s30)
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
      .toolbar { closeItem }
  }

  @ViewBuilder
  private func destination(_ dest: SettingsDestination) -> some View {
        switch dest {
        case .orb(let id):
          if let orb = allOrbs.first(where: { $0.id == id }) { orbView(orb) }
        case .account:
          if let space = app.space { accountView(space: space) }
        case .calendars:
          calendarsView
        case .newOrb(let withPeople):
          OrbSetupView(mode: .create, initialWithPeople: withPeople) {
            onClose()
          }
          .environmentObject(app)
          .navigationTitle(Copy.Orbs.startNew)
          .navigationBarTitleDisplayMode(.large)
        case .pastOrbs:
          pastOrbsView
        case .applePicker:
          applePickerView
        case .notifications:
          notificationsView
        }
  }

  // MARK: - Main page

  @ViewBuilder
  private var mainRows: some View {
    if app.space?.frozen == true {
      frozenBanner
    }

    FDFormGroup {
      pictureRow(
        label: app.space?.myName ?? "You",
        note: email ?? "Your name and email",
        action: { navPath.append(SettingsDestination.account) }
      ) {
        FDAvatar(name: app.space?.myName, personId: app.space?.myId, size: .md)
      }
    }

    FDFormGroup(header: Copy.Orbs.yourOrbs) {
      ForEach(Array(activeOrbs.enumerated()), id: \.element.id) { idx, orb in
        if idx > 0 { Divider().overlay(Theme.separator) }
        pictureRow(
          label: orbName(orb),
          note: orb.peopleNote,
          trailing: orb.id == app.space?.id ? "Current ›" : "›",
          action: { navPath.append(SettingsDestination.orb(orb.id)) }
        ) {
          ZStack {
            Circle().fill(Theme.fillTertiary)
            OrbFacesView(faces: orb.faceChips, small: true)
          }
          .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
        }
      }
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
            chevron
          }
        }
      }
    }

    FDFormGroup {
      FDFormRow(label: "Calendars", glyph: .calendar, action: { navPath.append(SettingsDestination.calendars) }) {
        chevron
      }
      Divider().overlay(Theme.separator)
      FDFormRow(label: "Notifications", glyph: .bell, action: { navPath.append(SettingsDestination.notifications) }) {
        chevron
      }
    }

    if app.authPhase == .signedIn {
      FDFormGroup {
        FDFormRow(label: "Sign out", glyph: .signOut, destructive: true, action: { confirm = .signOut })
      }
    }
  }

  private var chevron: some View {
    Text("›")
      .font(.fdSubhead)
      .foregroundStyle(Theme.inkFaint)
  }

  /// A row led by a face or an Orb instead of a small glyph.
  private func pictureRow<Picture: View>(
    label: String,
    note: String,
    trailing: String = "›",
    action: @escaping () -> Void,
    @ViewBuilder picture: () -> Picture
  ) -> some View {
    Button(action: action) {
      HStack(spacing: Theme.Spacing.md) {
        picture()
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
          Text(label)
            .font(.fdBody)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
          Text(note)
            .font(.fdFootnote)
            .foregroundStyle(Theme.inkFaint)
            .lineLimit(1)
        }
        Spacer(minLength: Theme.Spacing.sm)
        Text(trailing)
          .font(.fdSubhead)
          .foregroundStyle(Theme.inkFaint)
      }
      .padding(.horizontal, Theme.Spacing.row)
      .padding(.vertical, Theme.Spacing.s10)
      .frame(minHeight: Theme.TouchTarget.formRow)
      .contentShape(Rectangle())
    }
    .buttonStyle(FDScaleButtonStyle())
  }

  // MARK: - Search

  private var hits: [SettingsHit] {
    var list: [SettingsHit] = [
      SettingsHit(id: "account", label: "Account", note: "Your name and email",
                  words: "account profile name email you me photo") {
        navPath.append(SettingsDestination.account)
      },
      SettingsHit(id: "calendars", label: "Calendars", note: "Apple Calendar",
                  words: "calendars calendar apple google outlook import external busy events") {
        navPath.append(SettingsDestination.calendars)
      },
      SettingsHit(id: "notifications", label: "Notifications", note: "Push, alerts, morning summary, quiet overnight",
                  words: "notifications push alerts alert reminders remind summary morning quiet night sound") {
        navPath.append(SettingsDestination.notifications)
      },
      SettingsHit(id: "new", label: Copy.Orbs.startNew, note: "Orbs", words: "new orb create start make") {
        navPath.append(SettingsDestination.newOrb(withPeople: false))
      },
      SettingsHit(id: "join", label: Copy.Orbs.joinWithCode, note: "Orbs", words: "join code invite link") {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.sheetHandoffLong) {
          app.showJoinOrb = true
        }
      },
      SettingsHit(id: "signout", label: "Sign out", note: "Settings",
                  words: "sign out log out logout signout leave account") {
        confirm = .signOut
      },
    ]
    if !pastOrbs.isEmpty {
      list.append(SettingsHit(id: "past", label: Copy.Orbs.pastOrbs, note: "Orbs",
                              words: "past orbs archive history left old frozen deleted") {
        navPath.append(SettingsDestination.pastOrbs)
      })
    }
    for orb in activeOrbs {
      let name = orbName(orb)
      let toOrb = { navPath.append(SettingsDestination.orb(orb.id)) }
      list.append(SettingsHit(id: "orb-\(orb.id)", label: name, note: "Orbs · \(orb.peopleNote)",
                              words: "\(name) orb rename name people members", go: toOrb))
      if orb.members.count > 1 {
        list.append(SettingsHit(id: "invite-\(orb.id)", label: "Invite to \(name)", note: name,
                                words: "invite add people share link", go: toOrb))
        list.append(SettingsHit(id: "mute-\(orb.id)", label: "Mute \(name)", note: name,
                                words: "mute silence quiet notifications", go: toOrb))
        list.append(SettingsHit(id: "leave-\(orb.id)", label: "Leave \(name)", note: name,
                                words: "leave exit quit remove", go: toOrb))
      }
    }
    return list
  }

  @ViewBuilder
  private var searchResults: some View {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    let found = hits.filter { "\($0.label) \($0.note) \($0.words)".lowercased().contains(q) }
    if found.isEmpty {
      Text("No settings match “\(query.trimmingCharacters(in: .whitespaces))”")
        .font(.fdSubhead)
        .foregroundStyle(Theme.inkFaint)
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xxl)
    } else {
      FDFormGroup {
        ForEach(Array(found.enumerated()), id: \.element.id) { idx, hit in
          if idx > 0 { Divider().overlay(Theme.separator) }
          FDFormRow(label: hit.label, note: hit.note, action: {
            query = ""
            hit.go()
          }) {
            chevron
          }
        }
      }
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
            openOrb(firstActive.id)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - An Orb's page

  private func isPersonal(_ orb: SpaceInfo) -> Bool {
    let soloOrbs = activeOrbs.filter { $0.members.count <= 1 }
    return orb.members.count <= 1 && (orb.isHomeSoloName() || soloOrbs.count <= 1)
  }

  private func orbView(_ orb: SpaceInfo) -> some View {
    let soloOrb = orb.members.count <= 1
    let isPersonalOrb = isPersonal(orb)
    let isCurrent = orb.id == app.space?.id
    let leaveLabel = soloOrb ? Copy.Orbs.deleteSoloAction : Copy.Orbs.leaveAction
    let justYou = SpaceInfo.soloTitle(from: orb.myName)
    let placeholder = soloOrb ? (justYou.isEmpty ? Copy.Orbs.personalPlaceholder : justYou) : Copy.Orbs.crewPlaceholder
    let removable = !orb.frozen && orb.myRole == "admin" && orb.members.count >= 3

    return ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        if !isCurrent && !orb.frozen {
          FDButton("Open this Orb", variant: .secondary) {
            openOrb(orb.id)
          }
          .padding(.bottom, Theme.Spacing.sm)
        }

        sectionLabel(Copy.Orbs.orbName)
        FDTextField(
          placeholder: placeholder,
          text: $orbDraft
        )
        .disabled(orb.frozen || spaceBusy)
        .onSubmit { Task { await persistOrbName(orb) } }

        sectionLabel(Copy.Orbs.people)
          .padding(.top, Theme.Spacing.sm)
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s10) {
              if !orb.frozen && !isPersonalOrb {
                Button {
                  invite(to: orb)
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

              ForEach(orb.members, id: \.id) { member in
                let canRemove = removable && member.id != orb.myId
                ZStack(alignment: .topLeading) {
                  VStack(spacing: Theme.Spacing.xs) {
                    FDAvatar(name: member.name, personId: member.id, size: .md)
                    Text(member.name)
                      .font(.caption)
                      .foregroundStyle(Theme.ink)
                      .lineLimit(1)
                      .frame(width: Theme.TouchTarget.orbTile)
                    Text(member.id == orb.myId ? "You" : " ")
                      .font(.caption2)
                      .foregroundStyle(Theme.inkFaint)
                      .frame(height: Theme.Spacing.s13)
                  }
                  .frame(width: Theme.TouchTarget.orbTile)

                  if canRemove {
                    Button {
                      confirm = .remove(orbId: orb.id, id: member.id, name: member.name)
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
                .font(.fdFootnote)
                .foregroundStyle(Theme.inkFaint)

              Button {
                navPath.append(SettingsDestination.newOrb(withPeople: true))
              } label: {
                Text("+ \(Copy.Orbs.startSharedOrb)")
                  .font(.fdFootnote.weight(.semibold))
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
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, Theme.Spacing.xs)

        if orb.frozen {
          Text(Copy.Orbs.frozenNotice)
            .font(.fdFootnote)
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, Theme.Spacing.xs)
        }

        if !orb.frozen && !soloOrb {
          FDFormGroup(footer: "Alerts you set on plans still ring.") {
            FDFormRow(label: "Mute this Orb", glyph: .bell) {
              Toggle("Mute this Orb", isOn: Binding(
                get: { orbMuted },
                set: { on in
                  orbMuted = on
                  Task {
                    do {
                      try await Alerts.setMuted(orb.id, on)
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
          .task(id: orb.id) { orbMuted = await Alerts.loadMuted(orb.id) }
        }

        if removable {
          ForEach(orb.members.filter { $0.id != orb.myId }, id: \.id) { member in
            Button("Remove \(member.name)") {
              confirm = .remove(orbId: orb.id, id: member.id, name: member.name)
            }
            .buttonStyle(.plain)
            .font(.fdSubhead.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xxs)
            .disabled(spaceBusy)
          }
        }

        if !orb.frozen && !isPersonalOrb {
          Button(leaveLabel) {
            confirm = .leave(orbId: orb.id, solo: soloOrb)
          }
          .buttonStyle(.plain)
          .font(.fdSubhead.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, Theme.Spacing.xs)
          .padding(.top, Theme.Spacing.xs)
          .disabled(spaceBusy)
        } else if orb.frozen {
          Button(Copy.Orbs.deletePermanent) {
            confirm = .purge(orb.id)
          }
          .buttonStyle(.plain)
          .font(.fdSubhead.weight(.semibold))
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
    .navigationTitle(orbName(orb))
    .navigationBarTitleDisplayMode(.large)
    .onAppear {
      orbDraft = isDefaultOrbName(orb.name) ? "" : orb.name
    }
    .onDisappear {
      Task { await persistOrbName(orb) }
    }
  }

  // MARK: - Account

  private func accountView(space: SpaceInfo) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        FDFormGroup(footer: "Your name shows on your face in every Orb.") {
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

          if let email {
            Divider().overlay(Theme.separator)
            FDFormRow(label: "Email") {
              Text(email)
                .font(.fdSubhead)
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Account")
    .navigationBarTitleDisplayMode(.large)
  }

  private var pastOrbsView: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
          ForEach(pastOrbs, id: \.id) { pOrb in
            let isCurrent = pOrb.id == app.space?.id
            let faces = pOrb.faceChips

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
                      openOrb(pOrb.id)
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
    .navigationBarTitleDisplayMode(.large)
  }

  private var calendarsView: some View {
    let home = app.spaces.first(where: { $0.isHomeOrb(in: app.spaces) })
    let appleCount = app.externalEvents.filter { $0.source == "apple" }.count
    return ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.base) {
        Text(Copy.Availability.yoursOnly(home.map(orbName) ?? "your own Orb"))
          .font(.fdSubhead)
          .foregroundStyle(Theme.inkSoft)
          .padding(.horizontal, Theme.Spacing.xs)

        FDFormGroup(footer: appleOn && !appleChosen.isEmpty ? appleFooter(count: appleCount) : nil) {
          FDFormRow(label: Copy.Availability.appleCalendar, glyph: .calendar) {
            Toggle("Connect Apple Calendar", isOn: appleToggle)
              .labelsHidden()
              .tint(Theme.roseInk)
              .disabled(appleBusy)
          }

          if appleOn {
            Divider().overlay(Theme.separator)
            FDFormRow(
              label: appleChosen.isEmpty ? "Choose calendars" : appleChosen.map(\.summary).joined(separator: ", "),
              action: { Task { await openApplePicker() } }
            ) {
              Text(appleChosen.isEmpty ? "›" : "Change ›")
                .font(.fdSubhead)
                .foregroundStyle(Theme.inkFaint)
            }

            if !appleChosen.isEmpty {
              Divider().overlay(Theme.separator)
              FDFormRow(
                label: "Refresh",
                action: { Task { await refreshApple() } }
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
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, Theme.Spacing.xs)
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.base)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Calendars")
    .navigationBarTitleDisplayMode(.large)
  }

  /// "12 events · Updated 5 min ago", like the PWA.
  private func appleFooter(count: Int) -> String {
    let events = count == 1 ? "1 event" : "\(count) events"
    guard let at = CalendarSync.lastSynced?.at else { return events }
    let mins = Int(Date().timeIntervalSince(at) / 60)
    let ago: String
    if mins < 1 { ago = "Updated just now" }
    else if mins < 60 { ago = "Updated \(mins) min ago" }
    else if mins < 60 * 24 { ago = "Updated \(mins / 60) h ago" }
    else { ago = "Updated \(DateLocal.shortDate(DateLocal.todayISO(at)))" }
    return "\(events) · \(ago)"
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
    .navigationBarTitleDisplayMode(.large)
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
      appleChosen = []
      appleCals = []
      await app.disconnectApple()
      return
    }
    await openApplePicker(connecting: true)
  }

  private func openApplePicker(connecting: Bool = false) async {
    appleBusy = true
    let ok = CalendarSync.hasFullAccess ? true : await CalendarSync.requestAccess()
    appleBusy = false
    guard ok else {
      if connecting { appleOn = false }
      app.toast = "Allow calendars in iPhone Settings → Fordays"
      return
    }
    let list = CalendarSync.listCalendars()
    if list.isEmpty {
      if connecting { appleOn = false }
      app.toast = "No calendars found on this iPhone"
      return
    }
    appleOn = true
    appleCals = list
    navPath.append(SettingsDestination.applePicker)
  }

  /// Tick boxes saved: sync the ticked ones, forget the rest.
  private func saveApple(_ list: [DeviceCalendar]) async {
    guard !list.isEmpty else {
      appleOn = false
      appleChosen = []
      await app.disconnectApple()
      return
    }
    CalendarSync.choose(list)
    appleChosen = list
    appleOn = true
    appleBusy = true
    do {
      let n = try await app.syncApple()
      app.watchDeviceCalendars()
      app.toast = n == 0 ? "Nothing in the next few months" : "\(n) events from Apple Calendar"
    } catch {
      app.toast = error.localizedDescription
    }
    appleBusy = false
  }

  private func refreshApple() async {
    appleBusy = true
    do {
      try await app.syncApple()
      app.toast = "Up to date"
    } catch {
      app.toast = error.localizedDescription
    }
    appleBusy = false
  }

  private var applePickerView: some View {
    let counts = CalendarSync.lastSynced?.counts ?? [:]
    return ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        Text(Copy.Availability.pickerLead)
          .font(.fdSubhead)
          .foregroundStyle(Theme.inkFaint)
        let mine = appleCals.filter(\.primary)
        let other = appleCals.filter { !$0.primary }
        if !mine.isEmpty {
          applePickerSection(title: "My calendars", items: mine, counts: counts)
        }
        if !other.isEmpty {
          applePickerSection(title: "Other", items: other, counts: counts)
        }
      }
      .padding(Theme.Spacing.lg)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("Choose calendars")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(appleChosen.isEmpty ? "Import" : "Save") {
          let picked = appleCals.filter { pendingAppleIds.contains($0.id) }
          if !navPath.isEmpty { navPath.removeLast() }
          Task { await saveApple(picked) }
        }
        .fontWeight(.semibold)
        .disabled(appleBusy || (pendingAppleIds.isEmpty && appleChosen.isEmpty))
      }
    }
    .onDisappear {
      // Backed out of a first connect with nothing ticked: Apple Calendar stays off.
      if CalendarSync.chosen.isEmpty {
        appleOn = false
        CalendarSync.setConnected(false)
      }
    }
    .onAppear {
      let saved = Set(CalendarSync.chosen.map(\.id))
      let main = appleCals.first(where: \.primary)?.id ?? appleCals.first?.id
      pendingAppleIds = saved.isEmpty ? Set([main].compactMap { $0 }) : saved
    }
  }

  private func applePickerSection(title: String, items: [DeviceCalendar], counts: [String: Int]) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text(title)
        .font(.fdFootnote.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
        .padding(.horizontal, Theme.Spacing.xs)
      VStack(spacing: Theme.Spacing.none) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, cal in
          if index > 0 { Divider().overlay(Theme.separator) }
          let on = pendingAppleIds.contains(cal.id)
          Button {
            if on { pendingAppleIds.remove(cal.id) } else { pendingAppleIds.insert(cal.id) }
          } label: {
            HStack(spacing: Theme.Spacing.md) {
              FormGlyphIcon(glyph: .calendar)
              Text(cal.primary ? "\(cal.summary) · Primary" : cal.summary)
                .font(.fdBody)
                .foregroundStyle(Theme.ink)
              Spacer()
              if let n = counts[cal.id] {
                Text("\(n)")
                  .font(.fdSubhead)
                  .monospacedDigit()
                  .foregroundStyle(Theme.inkFaint)
              }
              ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(on ? Theme.ink : Color.clear)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .strokeBorder(on ? Theme.ink : Theme.inkFaint, lineWidth: 1.5)
                if on {
                  Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.paperWarm)
                }
              }
              .frame(width: 22, height: 22)
            }
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.row)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(appleBusy)
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      .background(Theme.fillQuaternary, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.fdFootnote.weight(.semibold))
      .foregroundStyle(Theme.inkFaint)
  }

  private func isDefaultOrbName(_ name: String) -> Bool {
    let raw = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return raw.isEmpty
      || raw.caseInsensitiveCompare("Fordays") == .orderedSame
      || raw.caseInsensitiveCompare("Someday") == .orderedSame
  }

  private func syncProfileDraft() {
    guard let space = app.space else { return }
    profileNameDraft = space.myName
  }

  private func persistOrbName(_ orb: SpaceInfo) async {
    guard !orb.frozen else { return }
    let current = isDefaultOrbName(orb.name) ? "" : orb.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let next = orbDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    if next.isEmpty {
      orbDraft = current
      return
    }
    guard next != current else { return }
    await app.renameSpace(orb.id, name: next)
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

  /// Leave Settings and go into this Orb.
  private func openOrb(_ id: String) {
    onClose()
    guard id != app.space?.id else { return }
    Task { await app.switchToSpace(id) }
  }

  /// Inviting shares that Orb's code and can add a first idea to it, so it
  /// happens from inside the Orb: switch there first when it isn't open.
  /// Invite is its own sheet, so Settings closes first — never stacked.
  private func invite(to orb: SpaceInfo) {
    guard !orb.frozen else { return }
    if isPersonal(orb) {
      app.toast = Copy.Orbs.cannotInviteToPersonal
      navPath.append(SettingsDestination.newOrb(withPeople: true))
      return
    }
    onClose()
    Task {
      if orb.id != app.space?.id { await app.switchToSpace(orb.id) }
      try? await Task.sleep(nanoseconds: UInt64(Theme.Motion.sheetHandoffLong * 1_000_000_000))
      app.pendingInviteShare = true
    }
  }

  private func runConfirm(_ item: SettingsConfirm) {
    switch item {
    case .leave(let orbId, _):
      guard !spaceBusy else { return }
      spaceBusy = true
      Task {
        await app.leaveSpace(orbId)
        confirm = nil
        if navPath.isEmpty { onClose() } else { navPath.removeLast() }
        spaceBusy = false
      }
    case .remove(let orbId, let id, _):
      guard !spaceBusy else { return }
      spaceBusy = true
      Task {
        await app.removeMember(spaceId: orbId, userId: id)
        confirm = nil
        spaceBusy = false
      }
    case .purge(let id):
      guard !spaceBusy else { return }
      spaceBusy = true
      Task {
        await app.deletePastOrb(id)
        confirm = nil
        if navPath.isEmpty && startOrbId != nil { onClose() }
        else if pastOrbs.isEmpty || !navPath.isEmpty { navPath.removeLast(min(1, navPath.count)) }
        spaceBusy = false
      }
    case .signOut:
      confirm = nil
      onClose()
      Task { await app.signOut() }
    }
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
