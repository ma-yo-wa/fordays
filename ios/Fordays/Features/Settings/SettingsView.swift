import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showInvite = false
  @State private var showPastOrbs = false
  @State private var leaveAsk = false
  @State private var removeId: String?
  @State private var deleteAskId: String?
  @State private var spaceBusy = false
  @State private var appleOn = CalendarSync.isConnected
  @State private var appleName = CalendarSync.selectedName
  @State private var appleBusy = false
  @State private var appleCals: [DeviceCalendar] = []
  @State private var showApplePicker = false
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

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          if let space = app.space {
            if space.frozen {
              frozenBanner
            }
            profileSection(space: space)
            orbsSection
            peopleSection(space: space)
            orbActionsSection(space: space)
          }

          calendarsSection

          if !pastOrbs.isEmpty {
            pastOrbsSection
          }

          if app.authPhase == .signedIn {
            signOutSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .onChange(of: app.space?.id) { _, _ in
        leaveAsk = false
        removeId = nil
        deleteAskId = nil
      }
    }
    .sheet(isPresented: $showInvite) {
      InviteShareView()
        .environmentObject(app)
    }
    .sheet(isPresented: $showPastOrbs) {
      pastOrbsSheet
    }
    .sheet(isPresented: $showApplePicker) {
      applePickerSheet
    }
    .onAppear {
      appleOn = CalendarSync.isConnected
      appleName = CalendarSync.selectedName
    }
  }

  private var frozenBanner: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Copy.Orbs.viewingFrozenBanner)
        .font(.footnote)
        .foregroundStyle(Theme.inkSoft)
      if let firstActive = activeOrbs.first {
        Button {
          switchOrb(firstActive.id)
        } label: {
          Text(Copy.Orbs.switchBackToActive)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.paperWarm, in: Capsule())
            .overlay(Capsule().stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func profileSection(space: SpaceInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Your profile")
      HStack(spacing: 12) {
        face(space.myName, mine: true, size: 32)
        Text(space.myName)
          .font(.body)
          .foregroundStyle(Theme.ink)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  private var orbsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Your Orbs")
      VStack(spacing: 0) {
        ForEach(Array(activeOrbs.enumerated()), id: \.element.id) { index, orb in
          if index > 0 { orbRowDivider }
          orbRow(orb)
        }
        if !activeOrbs.isEmpty { orbRowDivider }
        createOrbRow
        orbRowDivider
        joinOrbRow
      }
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private var orbRowDivider: some View {
    Rectangle()
      .fill(Theme.ink.opacity(0.08))
      .frame(height: 0.5)
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

  private func orbRow(_ orb: SpaceInfo) -> some View {
    let active = orb.id == app.space?.id
    let faces = orbFaceChips(for: orb)
    return Button {
      switchOrb(orb.id)
    } label: {
      HStack(spacing: 12) {
        orbFaceStack(faces)
        VStack(alignment: .leading, spacing: 1) {
          Text(orb.peopleLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
          Text(orbSizeLabel(orb))
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(minHeight: 56)
      .background {
        if active {
          LinearGradient(
            colors: [Theme.rose.opacity(0.46), Theme.sage.opacity(0.34)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func orbFaceStack(_ faces: [OrbFaceChip]) -> some View {
    HStack(spacing: -6) {
      ForEach(faces.prefix(3)) { f in
        ZStack {
          Circle()
            .fill(f.them ? Theme.faceRose : Theme.faceSage)
          Text(f.letter)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .offset(y: -0.5)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().stroke(Theme.paperWarm, lineWidth: 1.5))
        .fixedSize()
      }
      if faces.count > 3 {
        ZStack {
          Circle()
            .fill(Theme.inkSoft)
          Text("+\(faces.count - 3)")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .offset(y: -0.5)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().stroke(Theme.paperWarm, lineWidth: 1.5))
        .fixedSize()
      }
    }
  }

  private var createOrbRow: some View {
    Button {
      createOrb()
    } label: {
      orbActionLabel(mark: "+", title: Copy.Orbs.createOrb, subtitle: Copy.Orbs.createOrbSub)
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private var joinOrbRow: some View {
    Button {
      dismiss()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        app.showJoinOrb = true
      }
    } label: {
      orbActionLabel(mark: "→", title: Copy.Orbs.joinOrb, subtitle: Copy.Orbs.joinOrbSub)
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func orbActionLabel(mark: String, title: String, subtitle: String) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(Theme.ink.opacity(0.08))
        Text(mark)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.ink)
          .offset(y: -0.5)
      }
      .frame(width: 28, height: 28)
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.ink)
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minHeight: 56)
  }

  private func peopleSection(space: SpaceInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("People in this Orb")
      VStack(alignment: .leading, spacing: 8) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            if !space.frozen {
              Button {
                showInvite = true
              } label: {
                VStack(spacing: 4) {
                  ZStack {
                    Circle()
                      .fill(Theme.ink.opacity(0.08))
                    Text("+")
                      .font(.system(size: 16, weight: .semibold))
                      .foregroundStyle(Theme.ink)
                      .offset(y: -0.5)
                  }
                  .frame(width: 32, height: 32)
                  .fixedSize()

                  Text("Invite")
                    .font(.caption)
                    .foregroundStyle(Theme.ink)
                  Text("More")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .frame(height: 13)
                }
                .frame(width: 64)
              }
              .buttonStyle(.plain)
            }

            ForEach(space.members, id: \.id) { member in
              let removable = !space.frozen && space.myRole == "admin" && space.members.count >= 3 && member.id != space.myId
              ZStack(alignment: .topLeading) {
                VStack(spacing: 4) {
                  face(member.name, mine: member.id == space.myId, size: 32)
                  Text(member.name)
                    .font(.caption)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(width: 64)
                  Text(member.id == space.myId ? "You" : " ")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .frame(height: 13)
                }
                .frame(width: 64)

                if removable {
                  Button {
                    removeId = member.id
                  } label: {
                    Image(systemName: "minus")
                      .font(.system(size: 9, weight: .bold))
                      .foregroundStyle(Theme.inkSoft)
                      .frame(width: 16, height: 16)
                      .background(Theme.paperWarm, in: Circle())
                      .overlay(Circle().stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
                      .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                  }
                  .buttonStyle(.plain)
                  .offset(x: 10, y: -2)
                }
              }
            }
          }
          .padding(.horizontal, 2)
          .padding(.bottom, 4)
        }
      }
      .padding(10)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      Text(Copy.Orbs.descriptor)
        .font(.footnote)
        .foregroundStyle(Theme.inkFaint)
        .padding(.horizontal, 4)

      if space.frozen {
        Text(Copy.Orbs.frozenNotice)
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, 4)
      }
    }
  }

  @ViewBuilder
  private func orbActionsSection(space: SpaceInfo) -> some View {
    let soloOrb = space.members.count <= 1
    let leaveLabel = soloOrb ? Copy.Orbs.deleteSoloAction : Copy.Orbs.leaveAction
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Orb actions")

      if !space.frozen, space.myRole == "admin", space.members.count >= 3 {
        ForEach(space.members.filter { $0.id != space.myId }, id: \.id) { member in
          if removeId == member.id {
            VStack(alignment: .leading, spacing: 10) {
              Text(Copy.Orbs.removeConfirm(name: member.name))
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)

              HStack(spacing: 10) {
                quietButton("Keep them") {
                  removeId = nil
                }
                dangerButton("Remove \(member.name)") {
                  removeMember(member.id)
                }
              }
            }
            .padding(12)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          } else {
            Button("Remove \(member.name)") {
              removeId = member.id
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .disabled(spaceBusy)
          }
        }
      }

      if !space.frozen {
        if leaveAsk {
          VStack(alignment: .leading, spacing: 10) {
            Text(
              soloOrb
                ? Copy.Orbs.deleteSoloConfirm
                : Copy.Orbs.leaveSharedConfirm
            )
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 10) {
              quietButton("Stay") {
                leaveAsk = false
              }
              dangerButton(leaveLabel) {
                leaveOrb()
              }
            }
          }
          .padding(12)
          .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
          Button(leaveLabel) {
            leaveAsk = true
          }
          .buttonStyle(.plain)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, 4)
          .padding(.top, 4)
          .disabled(spaceBusy)
        }
      } else {
        if deleteAskId == space.id {
          VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Orbs.deletePermanentConfirm)
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 10) {
              quietButton("Keep") {
                deleteAskId = nil
              }
              dangerButton(Copy.Orbs.deletePermanent) {
                deleteOrb(space.id)
              }
            }
          }
          .padding(12)
          .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
          Button(Copy.Orbs.deletePermanent) {
            deleteAskId = space.id
          }
          .buttonStyle(.plain)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, 4)
          .padding(.top, 4)
          .disabled(spaceBusy)
        }
      }
    }
  }

  private var pastOrbsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel(Copy.Orbs.pastOrbs)
      Button {
        showPastOrbs = true
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(Copy.Orbs.pastOrbs)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Theme.ink)
            Text(Copy.Orbs.pastOrbsSub)
              .font(.caption)
              .foregroundStyle(Theme.inkFaint)
          }
          Spacer()
          Text("\(pastOrbs.count)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Theme.ink.opacity(0.06), in: Capsule())
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.inkFaint)
        }
        .padding(14)
        .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private var pastOrbsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(pastOrbs, id: \.id) { pOrb in
            let isCurrent = pOrb.id == app.space?.id
            let faces = orbFaceChips(for: pOrb)

            VStack(alignment: .leading, spacing: 12) {
              HStack(alignment: .center) {
                Text(pOrb.peopleLabel)
                  .font(.headline)
                  .foregroundStyle(Theme.ink)

                Spacer()

                HStack(spacing: -6) {
                  ForEach(faces.prefix(3)) { f in
                    ZStack {
                      Circle()
                        .fill(f.them ? Theme.faceRose : Theme.faceSage)
                      Text(f.letter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: -0.5)
                    }
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Theme.paperWarm, lineWidth: 1.5))
                    .fixedSize()
                  }
                }
              }

              Divider()

              HStack(spacing: 10) {
                if isCurrent {
                  Text("Currently viewing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                  Button("View") {
                    switchOrb(pOrb.id)
                    showPastOrbs = false
                    dismiss()
                  }
                  .buttonStyle(.plain)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.ink)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                  .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
                }

                Spacer()

                if deleteAskId != pOrb.id {
                  Button(Copy.Orbs.deletePermanent) {
                    deleteAskId = pOrb.id
                  }
                  .buttonStyle(.plain)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.roseInk)
                }
              }

              if deleteAskId == pOrb.id {
                VStack(alignment: .leading, spacing: 8) {
                  Text(Copy.Orbs.deletePermanentConfirm)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                  HStack(spacing: 8) {
                    Button("Keep") {
                      deleteAskId = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))

                    Button(Copy.Orbs.deletePermanent) {
                      deleteOrb(pOrb.id)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.roseInk, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                  }
                }
                .padding(10)
                .background(Theme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
            }
            .padding(14)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
        .padding(20)
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationTitle(Copy.Orbs.pastOrbs)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            showPastOrbs = false
            deleteAskId = nil
          }
        }
      }
    }
  }

  private var calendarsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("External calendars")
      VStack(spacing: 0) {
        HStack {
          Text(Copy.Availability.appleCalendar)
            .font(.body)
            .foregroundStyle(Theme.ink)
          Spacer()
          Toggle("Connect Apple Calendar", isOn: appleToggle)
            .labelsHidden()
            .tint(Theme.roseInk)
            .disabled(appleBusy)
        }
        .padding(12)

        if appleOn {
          Button {
            Task { await openApplePicker() }
          } label: {
            HStack {
              Text(appleName ?? "Choose calendar")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
              Spacer()
              Text(appleName == nil ? "›" : "Change ›")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaint)
            }
            .padding(12)
          }
          .buttonStyle(.plain)
          .disabled(appleBusy)

          if appleName != nil {
            Button {
              Task { await importApple() }
            } label: {
              HStack {
                Text("Refresh overlay")
                  .font(.subheadline)
                  .foregroundStyle(Theme.ink)
                Spacer()
                Text(appleBusy ? "…" : "›")
                  .font(.subheadline)
                  .foregroundStyle(Theme.inkFaint)
              }
              .padding(12)
            }
            .buttonStyle(.plain)
            .disabled(appleBusy)
          }
        }
      }
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      Text(Copy.Availability.settingsNoteIos)
        .font(.footnote)
        .foregroundStyle(Theme.inkSoft)
    }
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
    showApplePicker = true
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
    showApplePicker = true
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
    showApplePicker = false
    do {
      try await app.replaceExternal(CalendarSync.fetchEvents(), source: "apple")
      app.watchDeviceCalendars()
      let n = CalendarSync.fetchEvents().count
      app.toast = n == 0
        ? "\(chosen.summary) — nothing in the next few months"
        : "\(chosen.summary) — \(n) events"
    } catch {
      app.toast = error.localizedDescription
    }
    appleBusy = false
  }

  private var applePickerSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
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
        .padding(20)
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationTitle("Import calendars")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showApplePicker = false
            if CalendarSync.selectedId == nil {
              appleOn = false
              CalendarSync.setConnected(false)
            }
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Import") {
            let chosen = appleCals.first(where: { $0.id == pendingAppleId })
              ?? appleCals.first(where: \.primary)
              ?? appleCals.first
            Task { await importApple(chosen) }
          }
          .fontWeight(.semibold)
          .disabled(appleBusy || appleCals.isEmpty)
        }
      }
    }
    .onAppear {
      pendingAppleId = CalendarSync.selectedId
        ?? appleCals.first(where: \.primary)?.id
        ?? appleCals.first?.id
    }
  }

  private func applePickerSection(title: String, items: [DeviceCalendar]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.inkFaint)
      VStack(spacing: 0) {
        ForEach(items) { cal in
          Button {
            pendingAppleId = cal.id
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "calendar")
                .foregroundStyle(Theme.inkSoft)
              Text(cal.primary ? "\(cal.summary) · Primary" : cal.summary)
                .font(.body)
                .foregroundStyle(Theme.ink)
              Spacer()
              Image(systemName: pendingAppleId == cal.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(pendingAppleId == cal.id ? Theme.roseInk : Theme.inkFaint)
            }
            .padding(.vertical, 10)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var signOutSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Session")
      dangerButton("Sign out") {
        Task {
          await app.signOut()
          dismiss()
        }
      }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(Theme.inkFaint)
  }

  private func quietButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func dangerButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.roseInk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func face(_ name: String, mine: Bool, size: CGFloat = 32) -> some View {
    ZStack {
      Circle()
        .fill(mine ? Theme.faceSage : Theme.faceRose)
      Text(initial(name))
        .font(.system(size: size * 0.44, weight: .bold))
        .foregroundStyle(.white)
        .offset(y: -0.5)
    }
    .frame(width: size, height: size)
    .fixedSize()
  }

  private func switchOrb(_ id: String) {
    guard !spaceBusy, id != app.space?.id else { return }
    spaceBusy = true
    Task {
      await app.switchToSpace(id)
      spaceBusy = false
      if app.space?.id == id { dismiss() }
    }
  }

  private func createOrb() {
    guard !spaceBusy else { return }
    let before = app.space?.id
    spaceBusy = true
    Task {
      await app.addSpace()
      spaceBusy = false
      if app.space?.id != before { dismiss() }
    }
  }

  private func removeMember(_ userId: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.removeMember(userId: userId)
      removeId = nil
      spaceBusy = false
    }
  }

  private func leaveOrb() {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.leaveCurrentSpace()
      leaveAsk = false
      spaceBusy = false
    }
  }

  private func deleteOrb(_ id: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.deletePastOrb(id)
      deleteAskId = nil
      if pastOrbs.count <= 1 {
        showPastOrbs = false
      }
      spaceBusy = false
    }
  }

  private func initial(_ name: String) -> String {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(clean.prefix(1)).uppercased()
  }

  private func orbSizeLabel(_ orb: SpaceInfo) -> String {
    let n = orb.members.isEmpty ? (orb.partner2Id == nil ? 1 : 2) : orb.members.count
    return n <= 1 ? "1 person" : "\(n) people"
  }
}
