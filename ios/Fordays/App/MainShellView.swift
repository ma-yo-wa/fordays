import SwiftUI

struct MainShellView: View {
  @EnvironmentObject private var app: AppModel
  @State private var showAddChooser = false
  @State private var composer: ComposerKind?
  @State private var composerDraft: PlanDraft?
  @State private var selectedExternal: ExternalEvent?
  @State private var showInvite = false
  @State private var showSettings = false
  @State private var selected: Activity?
  @State private var showSearch = false

  var body: some View {
    ZStack(alignment: .bottom) {
      Theme.paper.ignoresSafeArea()

      VStack(spacing: 0) {
        topBar
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
      }

      VStack(spacing: 12) {
        Button {
          if app.space?.canCompose == true {
            showAddChooser = true
          } else {
            app.toast = "This is a copy from when you left"
          }
        } label: {
            Image(systemName: "plus")
              .font(.title2.weight(.semibold))
              .foregroundStyle(Theme.ink)
              .frame(width: 56, height: 56)
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
                  endRadius: 40
                ),
                in: Circle()
              )
              .shadow(color: Theme.rose.opacity(0.45), radius: 12, y: 6)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 20)
        .opacity(app.space?.canCompose == true ? 1 : 0)
        .allowsHitTesting(app.space?.canCompose == true)

        TabDock(tab: $app.tab)
          .padding(.bottom, 8)
      }

      if let toast = app.toast {
        Text(toast)
          .font(.footnote.weight(.medium))
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(.ultraThinMaterial, in: Capsule())
          .padding(.bottom, 100)
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
      ComposerView(kind: kind, draft: composerDraft, onClose: {
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
        showSettings = false
        showAddChooser = false
        composer = nil
        selectedExternal = nil
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
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .environmentObject(app)
    }
    .sheet(isPresented: $app.showJoinOrb) {
      JoinOrbView()
        .environmentObject(app)
    }
  }

  private var topBar: some View {
    HStack {
      Button { showSettings = true } label: {
        HStack(spacing: customOrbName != nil ? 7 : 6) {
          if let custom = customOrbName {
            Text(custom)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Theme.ink)
              .lineLimit(1)
              .truncationMode(.tail)
              .frame(maxWidth: 110, alignment: .leading)
          } else {
            HStack(spacing: -8) {
              if let members = app.space?.members, !members.isEmpty {
                let ordered = orderedHeaderMembers(members, myId: app.space?.myId)
                ForEach(ordered.prefix(2), id: \.id) { member in
                  face(member.name, them: member.id != app.space?.myId)
                }
                let more = max(0, ordered.count - 2)
                if more > 0 {
                  moreFace(more)
                }
              } else {
                face(app.space?.myName, them: false)
                if app.space?.isMatched == true {
                  face(app.space?.partnerName, them: true)
                }
              }
            }
          }

          Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(.leading, customOrbName != nil ? 12 : 2)
        .padding(.trailing, customOrbName != nil ? 10 : 8)
        .frame(height: 36)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(customOrbName.map { "Open settings for \($0)" } ?? "Open Orb settings")
      Spacer(minLength: 8)

      if app.tab == .plans {
        trailingCalendarControls
      }

      Button {
        showSearch = true
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Search")
    }
    .overlay {
      Text(title)
        .font(.headline)
        .foregroundStyle(Theme.ink)
        .allowsHitTesting(false)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var trailingCalendarControls: some View {
    HStack(spacing: 2) {
      if DateLocal.isOffCurrentMonth(app.cursorMonth) {
        Button {
          app.goToday()
        } label: {
          Text("Today")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Theme.ink.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
      }

      Button {
        app.shiftMonth(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Previous month")

      Button {
        app.shiftMonth(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .frame(width: 32, height: 32)
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

  /// You = sage, everyone else in this space = rose.
  private func face(_ name: String?, them: Bool) -> some View {
    let fill = them ? Theme.faceRose : Theme.faceSage
    return Text(String((name ?? "?").prefix(1)).uppercased())
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: 32, height: 32)
      .background(fill, in: Circle())
      .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
  }

  private func moreFace(_ count: Int) -> some View {
    Text("+\(count)")
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: 32, height: 32)
      .background(Theme.inkSoft, in: Circle())
      .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
  }

  private func orderedHeaderMembers(_ members: [SpaceMember], myId: String?) -> [SpaceMember] {
    guard let myId else { return members }
    let mine = members.filter { $0.id.compare(myId, options: .caseInsensitive) == .orderedSame }
    let others = members.filter { $0.id.compare(myId, options: .caseInsensitive) != .orderedSame }
    return mine + others
  }
}

struct TabDock: View {
  @Binding var tab: HomeTab

  var body: some View {
    HStack(spacing: 0) {
      tabButton(.bucket, glyph: .bucket)
      tabButton(.plans, glyph: .calendar)
      tabButton(.memories, glyph: .memories)
    }
    .padding(5)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay(Capsule().stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
    .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
  }

  private func tabButton(_ value: HomeTab, glyph: TabGlyph) -> some View {
    let on = tab == value
    return Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        tab = value
      }
    } label: {
      VStack(spacing: 4) {
        TabIcon(glyph: glyph, on: on)
        Text(value.title)
          .font(.system(size: 12, weight: .regular))
          .lineLimit(1)
      }
      .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
      .frame(width: 84, height: 56)
      .background {
        if on {
          Capsule().fill(Theme.ink.opacity(0.07))
        }
      }
    }
    .accessibilityLabel(value.title)
  }
}
