import SwiftUI

struct MainShellView: View {
  @EnvironmentObject private var app: AppModel
  @State private var showAddChooser = false
  @State private var composer: ComposerKind?
  @State private var composerDraft: PlanDraft?
  @State private var selectedExternal: ExternalEvent?
  @State private var showInvite = false
  @State private var showSettings = false
  @State private var settingsOrbId: String?
  @State private var showSwitcher = false
  @State private var selected: Activity?
  @State private var showSearch = false

  var body: some View {
    ZStack(alignment: .bottom) {
      OrbBackground().ignoresSafeArea()

      Group {
        switch app.tab {
        case .bucket:
          BucketView(
            onSelect: { selected = $0 },
            onInvite: { showInvite = true }
          )
        case .plans:
          PlansView(
            onSelect: { selected = $0 },
            onSelectExternal: { selectedExternal = $0 },
            onMakePlanFromExternal: { event in
              composerDraft = PlanDraft.from(external: event)
              composer = .plan
            },
            onInvite: { showInvite = true }
          )
        case .memories:
          MemoriesView(onSelect: { selected = $0 })
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .safeAreaInset(edge: .top, spacing: Theme.Spacing.none) {
        topBar
      }
      // Settings covers the whole screen, so VoiceOver shouldn't reach behind it.
      .accessibilityHidden(showSettings)

      VStack(spacing: Theme.Spacing.md) {
        Button {
          if app.space?.canCompose == true {
            // The tab already says what you're adding; only Memories asks.
            composerDraft = nil
            switch app.tab {
            case .plans: composer = .plan
            case .bucket: composer = .bucket
            case .memories: showAddChooser = true
            }
          } else {
            app.toast = "This is a copy from when you left"
          }
        } label: {
            Image(systemName: "plus")
              .font(.title2.weight(.medium))
              .foregroundStyle(Theme.ink)
              .frame(width: Theme.TouchTarget.navBar, height: Theme.TouchTarget.navBar)
              .background(
                RadialGradient(
                  colors: [
                    Color(hex: 0xFF7396),
                    Color(hex: 0xFD8696),
                    Color(hex: 0xFDA492),
                    Color(hex: 0xF0C296),
                    Color(hex: 0xCDE7B3),
                  ],
                  center: .center,
                  startRadius: 0,
                  endRadius: Theme.Spacing.xxxl
                ),
                in: Circle()
              )
              .shadow(color: Theme.roseGlow, radius: Theme.Spacing.md, y: Theme.Spacing.s6)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, Theme.Spacing.lg)
        .opacity(app.space?.canCompose == true ? 1 : 0)
        .allowsHitTesting(app.space?.canCompose == true)

        TabDock(tab: $app.tab) { openSettings(orbId: nil) }
          .padding(.bottom, Theme.Spacing.sm)
      }
      .accessibilityHidden(showSettings)

      if let toast = app.toast {
        Text(toast)
          .font(.footnote.weight(.medium))
          .padding(.horizontal, Theme.Spacing.row)
          .padding(.vertical, Theme.Spacing.s10)
          .background(.ultraThinMaterial, in: Capsule())
          .padding(.bottom, Theme.Spacing.toastClearance)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              withAnimation { app.toast = nil }
            }
          }
      }

      if showSearch {
        SearchView(
          onSelect: { activity in
            showSearch = false
            selected = activity
          },
          onClose: {
            showSearch = false
          }
        )
        .environmentObject(app)
        .transition(.opacity)
      }
    }
    .sheet(isPresented: $showAddChooser) {
      AddSheetView(
        onClose: { showAddChooser = false },
        onPick: { kind in
          showAddChooser = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            composer = kind
          }
        }
      )
    }
    .sheet(item: $composer) { kind in
      ComposerView(kind: kind, draft: composerDraft, focusedDay: app.pickedDay, onClose: {
        composer = nil
        composerDraft = nil
      })
      .environmentObject(app)
    }
    .sheet(item: $selectedExternal) { event in
      ExternalDetailView(
        event: event,
        onMakePlan: { draft in
          selectedExternal = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            composerDraft = draft
            composer = .plan
          }
        },
        onClose: { selectedExternal = nil }
      )
      .environmentObject(app)
    }
    .sheet(isPresented: $showInvite) {
      InviteShareView()
        .environmentObject(app)
    }
    .onAppear {
      if app.pendingInviteShare {
        app.pendingInviteShare = false
        showInvite = true
      }
      if let id = app.detailActivityId, let act = app.activity(id: id) {
        selected = act
      }
    }
    .onChange(of: app.pendingInviteShare) { _, pending in
      if pending {
        app.pendingInviteShare = false
        showInvite = true
      }
    }
    .onChange(of: app.detailActivityId) { _, id in
      if let id {
        // Never stack sheets: whatever was open gives way to the card.
        showSettings = false
        showAddChooser = false
        composer = nil
        selectedExternal = nil
        showSearch = false
        showInvite = false
        app.showJoinOrb = false
        selected = app.activity(id: id)
      } else {
        selected = nil
      }
    }
    .sheet(item: $selected, onDismiss: { app.detailActivityId = nil }) { activity in
      DetailView(activityId: activity.id, onDoAgain: { kind, draft in
        selected = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          composerDraft = draft
          composer = kind
        }
      })
      .environmentObject(app)
    }
    .sheet(isPresented: $showSwitcher) {
      OrbSwitcherView { orbId in
        showSwitcher = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.sheetHandoffLong) {
          openSettings(orbId: orbId)
        }
      }
      .environmentObject(app)
    }
    // Settings is a full screen pushed in from the right, not a sheet.
    .overlay {
      if showSettings {
        SettingsView(startOrbId: settingsOrbId) {
          withAnimation(.easeInOut(duration: Theme.Motion.shelf)) { showSettings = false }
        }
        .environmentObject(app)
        .transition(.move(edge: .trailing))
        .zIndex(10)
      }
    }
    .sheet(isPresented: $app.showJoinOrb) {
      JoinOrbView()
        .environmentObject(app)
    }
  }

  private var topBar: some View {
    ZStack {
      // Centered compact title
      Text(title)
        .font(.headline)
        .foregroundStyle(Theme.ink)
        .lineLimit(1)

      // Bar controls pinned to edges
      HStack(spacing: Theme.Spacing.none) {
        // Leading: Orb capsule. Tap to switch; hold to jump back to the last Orb.
        Button { showSwitcher = true } label: {
          HStack(spacing: customOrbName != nil ? Theme.Spacing.s7 : Theme.Spacing.s6) {
            if let custom = customOrbName {
              Text(custom)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            } else {
              HStack(spacing: Theme.Spacing.overlapMd) {
                if let members = app.space?.members, !members.isEmpty {
                  let ordered = orderedHeaderMembers(members, myId: app.space?.myId)
                  ForEach(ordered.prefix(2), id: \.id) { member in
                    face(member.name, id: member.id)
                  }
                  let more = max(0, ordered.count - 2)
                  if more > 0 {
                    moreFace(more)
                  }
                } else {
                  face(app.space?.myName, id: app.space?.myId)
                  if app.space?.isMatched == true {
                    face(app.space?.partnerName, id: nil)
                  }
                }
              }
            }

            Image(systemName: "chevron.down")
              .font(.caption2)
              .foregroundStyle(Theme.inkSoft)
          }
          .padding(.leading, customOrbName != nil ? Theme.Spacing.md : Theme.Spacing.xxs)
          .padding(.trailing, customOrbName != nil ? Theme.Spacing.s10 : Theme.Spacing.sm)
          .frame(height: Theme.TouchTarget.control)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay(Capsule().stroke(Theme.hairline, lineWidth: Theme.TouchTarget.hairlineWidth))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await app.switchBack() }
          }
        )
        .accessibilityLabel(customOrbName.map { "Switch Orb, now in \($0)" } ?? "Switch Orb")
        .accessibilityAction(named: "Back to last Orb") {
          Task { await app.switchBack() }
        }

        Spacer(minLength: Theme.Spacing.sm)

        // Trailing: controls + Search
        HStack(spacing: Theme.Spacing.xxs) {
          if app.tab == .plans {
            trailingCalendarControls
          }

          Button {
            showSearch = true
          } label: {
            Image(systemName: "magnifyingglass")
              .font(.subheadline)
              .foregroundStyle(Theme.roseInk)
              .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Search")

        }
      }
    }
    .padding(.horizontal, Theme.Spacing.base)
    .padding(.top, Theme.Spacing.s6)
    .padding(.bottom, Theme.Spacing.row)
    .background {
      ZStack {
        Theme.paperWarm.opacity(app.isScrolled ? 1 : 0)
          .background(.ultraThinMaterial.opacity(app.isScrolled ? 1 : 0))
          .ignoresSafeArea(edges: .top)
        UnevenRoundedRectangle(bottomLeadingRadius: Theme.Spacing.xl, bottomTrailingRadius: Theme.Spacing.xl, style: .continuous)
          .fill(Theme.paperWarm.opacity(app.isScrolled ? 1 : 0))
          .background {
            UnevenRoundedRectangle(bottomLeadingRadius: Theme.Spacing.xl, bottomTrailingRadius: Theme.Spacing.xl, style: .continuous)
              .fill(.ultraThinMaterial)
              .opacity(app.isScrolled ? 1 : 0)
          }
          .shadow(color: app.isScrolled ? Theme.fillQuaternary : Color.clear, radius: Theme.Spacing.sm, y: Theme.Spacing.xs)
          .ignoresSafeArea(edges: .top)
      }
      .animation(.easeInOut(duration: Theme.Motion.shelf), value: app.isScrolled)
    }
  }

  private func openSettings(orbId: String?) {
    settingsOrbId = orbId
    withAnimation(.easeInOut(duration: Theme.Motion.shelf)) { showSettings = true }
  }

  private var trailingCalendarControls: some View {
    HStack(spacing: Theme.Spacing.xxs) {
      Button {
        app.shiftMonth(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.subheadline)
          .foregroundStyle(Theme.roseInk)
          .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Previous month")

      Button {
        app.shiftMonth(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.subheadline)
          .foregroundStyle(Theme.roseInk)
          .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Next month")
    }
  }

  private var title: String {
    switch app.tab {
    case .bucket: return Copy.Tabs.ideas
    case .plans: return DateLocal.monthTitle(for: app.cursorMonth)
    case .memories: return "Memories"
    }
  }

  private var customOrbName: String? {
    guard let space = app.space else { return nil }
    let named = space.peopleLabel
    return named.isEmpty ? nil : named
  }

  private func face(_ name: String?, id: String?) -> some View {
    return Text(String((name ?? "?").prefix(1)).uppercased())
      .font(.caption.weight(.bold))
      .foregroundStyle(Theme.faceInk)
      .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
      .background(Theme.faceColor(for: id ?? name), in: Circle())
      .overlay(Circle().stroke(Theme.paper, lineWidth: Theme.TouchTarget.strokeThick))
  }

  private func moreFace(_ count: Int) -> some View {
    Text("+\(count)")
      .font(.caption2.weight(.bold))
      .foregroundStyle(Theme.faceInk)
      .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
      .background(Theme.fillSecondary, in: Circle())
      .overlay(Circle().stroke(Theme.paper, lineWidth: Theme.TouchTarget.strokeThick))
  }

  private func orderedHeaderMembers(_ members: [SpaceMember], myId: String?) -> [SpaceMember] {
    guard let myId else { return members }
    let mine = members.filter { $0.id.compare(myId, options: .caseInsensitive) == .orderedSame }
    let others = members.filter { $0.id.compare(myId, options: .caseInsensitive) != .orderedSame }
    return mine + others
  }
}

struct TabDock: View {
  @EnvironmentObject private var app: AppModel
  @Binding var tab: HomeTab
  /// You: not a place in the app, so it opens Settings over it.
  var onYou: () -> Void

  var body: some View {
    HStack(spacing: Theme.Spacing.none) {
      tabButton(.bucket, glyph: .bucket)
      tabButton(.plans, glyph: .calendar)
      tabButton(.memories, glyph: .memories)
      Button(action: onYou) {
        VStack(spacing: Theme.Spacing.xs) {
          FDAvatar(name: app.space?.myName, personId: app.space?.myId, size: .sm)
          Text("You")
            .font(.fdCaption)
            .lineLimit(1)
        }
        .foregroundStyle(Theme.inkSoft)
        .frame(width: Theme.TouchTarget.tabItemWidth, height: Theme.TouchTarget.navBar)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Settings")
    }
    .padding(Theme.Spacing.s5)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay(Capsule().stroke(Theme.hairline, lineWidth: Theme.TouchTarget.hairlineWidth))
    .shadow(color: Theme.shadowCard, radius: Theme.Spacing.base, y: Theme.Spacing.sm)
  }

  private func tabButton(_ value: HomeTab, glyph: TabGlyph) -> some View {
    let on = tab == value
    return Button {
      withAnimation(.spring(response: Theme.Motion.tabSpring, dampingFraction: Theme.Motion.tabDamping)) {
        tab = value
      }
    } label: {
      VStack(spacing: Theme.Spacing.xs) {
        TabIcon(glyph: glyph, on: on)
        Text(value.title)
          .font(.fdCaption)
          .lineLimit(1)
      }
      .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
      .frame(width: Theme.TouchTarget.tabItemWidth, height: Theme.TouchTarget.navBar)
      .background {
        if on {
          Capsule().fill(Theme.fillTertiary)
        }
      }
    }
    .accessibilityLabel(value.title)
  }
}
