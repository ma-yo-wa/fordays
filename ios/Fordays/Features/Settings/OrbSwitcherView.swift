import SwiftUI

/// The drawer behind the Orb name: switch Orbs, start or join one, and a way
/// into this Orb's settings. Everything else lives in Settings. Same as the
/// PWA's OrbSwitcher.
struct OrbSwitcherView: View {
  private static let orbSize: CGFloat = Theme.TouchTarget.orbFace

  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var making = false
  @State private var busy = false

  /// Close the drawer and open Settings on this Orb's page.
  var onOpenOrbSettings: (String) -> Void

  private var activeOrbs: [SpaceInfo] {
    let all = app.spaces.isEmpty ? (app.space.map { [$0] } ?? []) : app.spaces
    return all.filter { !$0.frozen }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.s22) {
          // A sheet heading, like the PWA's: bold and on the left.
          Text(Copy.Orbs.yourOrbs)
            .font(.fdTitle2)
            .foregroundStyle(Theme.ink)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, -Theme.Spacing.sm)

          if app.space?.frozen == true {
            frozenBanner
          }

          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Self.orbSize), spacing: Theme.Spacing.base)],
            alignment: .leading,
            spacing: Theme.Spacing.row
          ) {
            ForEach(activeOrbs, id: \.id) { orb in
              orbTile(orb)
            }
          }
          .padding(Theme.Spacing.md)
          .background(Theme.fillQuaternary, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

          VStack(spacing: Theme.Spacing.none) {
            if let space = app.space {
              FDActionRow(
                title: "\(space.peopleLabel.isEmpty ? Copy.Orbs.thisOrb : space.peopleLabel) settings",
                note: "Name, people and notifications",
                glyph: "○"
              ) {
                onOpenOrbSettings(space.id)
              }
              Rectangle()
                .fill(Theme.hairline)
                .frame(height: Theme.TouchTarget.hairlineWidth)
            }
            FDActionRow(title: Copy.Orbs.startNew, note: Copy.Orbs.startNewNote, glyph: "+") {
              making = true
            }
            Rectangle()
              .fill(Theme.hairline)
              .frame(height: Theme.TouchTarget.hairlineWidth)
            FDActionRow(title: Copy.Orbs.joinWithCode, note: Copy.Orbs.joinWithCodeNote, glyph: "→") {
              dismiss()
              DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.sheetHandoffLong) {
                app.showJoinOrb = true
              }
            }
          }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.s30)
      }
      .background(Theme.paper.ignoresSafeArea())
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: $making) {
        OrbSetupView(mode: .create) { dismiss() }
          .environmentObject(app)
          .navigationTitle(Copy.Orbs.startNew)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar(.visible, for: .navigationBar)
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(Theme.paper)
  }

  private var frozenBanner: some View {
    FDCard(variant: .sunk, padding: .md) {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text(Copy.Orbs.viewingFrozenBanner)
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkSoft)
        if let firstActive = activeOrbs.first {
          FDButton(Copy.Orbs.switchBackToActive, variant: .secondary, size: .sm) {
            pick(firstActive)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func orbTile(_ orb: SpaceInfo) -> some View {
    let active = orb.id == app.space?.id
    return Button {
      pick(orb)
    } label: {
      VStack(spacing: Theme.Spacing.s6) {
        ZStack {
          Circle()
            .fill(active ? Theme.sageWash : Theme.fillTertiary)
          OrbFacesView(faces: orb.faceChips)
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
    .disabled(busy)
    .accessibilityAddTraits(active ? .isSelected : [])
  }

  private func pick(_ orb: SpaceInfo) {
    guard !busy else { return }
    dismiss()
    guard orb.id != app.space?.id else { return }
    busy = true
    Task {
      await app.switchToSpace(orb.id)
      busy = false
    }
  }
}
