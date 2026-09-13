import SwiftUI

struct MainShellView: View {
  @EnvironmentObject private var app: AppModel
  @State private var showAddChooser = false
  @State private var composer: ComposerKind?
  @State private var showInvite = false
  @State private var showSettings = false
  @State private var selected: Activity?

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
              onAddIdea: { composer = .bucket },
              onInvite: { showInvite = true }
            )
          case .plans:
            PlansView(onSelect: { selected = $0 }, onInvite: { showInvite = true })
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
      ComposerView(kind: kind, onClose: { composer = nil })
        .environmentObject(app)
    }
    .sheet(isPresented: $showInvite) {
      InviteShareView()
        .environmentObject(app)
    }
    .sheet(item: $selected) { activity in
      DetailView(activityId: activity.id)
        .environmentObject(app)
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .environmentObject(app)
    }
  }

  private var topBar: some View {
    HStack {
      Button { showSettings = true } label: {
        HStack(spacing: 8) {
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
          .padding(.trailing, 2)

          Text(activeOrbTitle)
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .truncationMode(.tail)

          Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: 190, alignment: .leading)
        .padding(.leading, 2)
        .padding(.trailing, 10)
        .frame(height: 36)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.ink.opacity(0.12), lineWidth: 0.5))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open Orb settings")
      Spacer(minLength: 0)
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

  private var title: String {
    switch app.tab {
    case .bucket: return "Bucket List"
    case .plans: return monthTitle
    case .memories: return "Memories"
    }
  }

  private var monthTitle: String {
    let f = DateFormatter()
    f.dateFormat = "MMMM"
    return f.string(from: Date())
  }

  private var activeOrbTitle: String {
    let orbName = app.space?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !orbName.isEmpty { return orbName }
    let partner = app.space?.partnerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !partner.isEmpty { return "\(partner)'s Orb" }
    return "Your Orb"
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
    HStack(spacing: 4) {
      tabButton(.bucket, glyph: .bucket)
      tabButton(.plans, glyph: .calendar)
      tabButton(.memories, glyph: .memories)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 5)
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
      TabIcon(glyph: glyph, on: on)
        .foregroundStyle(on ? Theme.ink : Theme.inkFaint)
        .frame(width: 52, height: 42)
        .background {
          if on {
            Capsule().fill(Theme.ink.opacity(0.07))
          }
        }
    }
    .accessibilityLabel(value.title)
  }
}
