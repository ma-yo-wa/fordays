import SwiftUI

struct ExternalDetailView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showMoveDialog = false

  let event: ExternalEvent
  var onMakePlan: ((PlanDraft) -> Void)? = nil
  var onClose: () -> Void

  private var isMine: Bool {
    app.space?.myId == event.userId || event.userId == "0"
  }

  private var ownerName: String {
    if isMine { return "You" }
    return app.space?.displayName(for: event.userId) ?? "Them"
  }

  private var possessive: String {
    if isMine { return "your" }
    return "\(ownerName)’s"
  }

  private var activeSharedOrbs: [SpaceInfo] {
    app.spaces.filter { !$0.frozen && $0.id != app.space?.id }
  }

  private func targetOrbName(_ target: SpaceInfo) -> String {
    if let partner = target.partnerName, !partner.isEmpty { return partner }
    return target.name
  }

  private func targetOrbLabel(_ target: SpaceInfo) -> String {
    if let partner = target.partnerName, !partner.isEmpty {
      return "\(partner) (\(target.name))"
    }
    return target.name
  }

  /// An imported event is a plan: its when reads like plan Detail's.
  private var rangeDescription: String {
    guard event.allDay else {
      return DateLocal.describePlan(event.startsAt, endsAt: event.endsAt.isEmpty ? nil : event.endsAt)
    }
    let start = String(event.startsAt.prefix(10))
    let end = event.endsAt.isEmpty ? start : String(event.endsAt.prefix(10))
    return DateLocal.describePlan(start, endsAt: end != start ? end : nil)
  }

  private var title: String {
    let t = event.title ?? ""
    return t.isEmpty ? Copy.Availability.busy : t
  }

  private func handleDoWith(_ targetSpace: SpaceInfo) async {
    let planTitle = (event.title ?? "").isEmpty ? "Plan" : event.title!
    let saved = await app.createActivity(
      title: planTitle,
      description: nil,
      location: event.location,
      imageUrl: nil,
      dateTime: event.startsAt.isEmpty ? nil : event.startsAt,
      endsAt: event.endsAt.isEmpty ? nil : event.endsAt,
      spaceId: targetSpace.id
    )
    // Close only once it's saved, like the PWA — a failure keeps the sheet.
    guard saved else { return }
    app.toast = Copy.Orbs.movedToPlans(targetOrbName(targetSpace))
    dismiss()
    onClose()
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: Theme.Spacing.none) {
        // Header
        HStack(alignment: .top, spacing: Theme.Spacing.row) {
          LinearGradient(
            colors: Theme.orbColors(for: event.id, title: event.title),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .frame(width: Theme.TouchTarget.formRow, height: Theme.TouchTarget.formRow)
          .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

          VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
              .font(.title2.weight(.bold))
              .foregroundStyle(Theme.ink)
            Text(rangeDescription)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
            if let loc = event.location, !loc.isEmpty {
              if let url = URL(string: "https://maps.apple.com/?q=\(loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc)") {
                Link(destination: url) {
                  HStack(spacing: Theme.Spacing.xs) {
                    PinGlyph()
                      .foregroundStyle(Theme.inkSoft)
                      .frame(width: Theme.Spacing.base, height: Theme.Spacing.base)
                    Text(loc)
                      .font(.subheadline)
                      .foregroundStyle(Theme.inkSoft)
                      .multilineTextAlignment(.leading)
                    Image(systemName: "arrow.up.right")
                      .font(.caption2)
                      .foregroundStyle(Theme.inkFaint)
                  }
                }
              }
            }
          }
        }
        .padding(.bottom, Theme.Spacing.lg)

        Divider()
          .overlay(Theme.hairline)

        // Rows
        VStack(alignment: .leading, spacing: Theme.Spacing.row) {
          HStack(spacing: Theme.Spacing.s10) {
            FDAvatar(name: ownerName, seat: isMine ? 0 : 1, size: .sm)
            Text(ownerName)
              .font(.subheadline)
              .foregroundStyle(Theme.ink)
            FDPill(
              title: event.calendar.isEmpty ? event.sourceLabel : event.calendar,
              variant: .neutral,
              size: .sm
            )
          }
        }
        .padding(.vertical, Theme.Spacing.base)

        // Do with [Partner] action
        if app.space?.isMatched != true, !activeSharedOrbs.isEmpty {
          if activeSharedOrbs.count == 1, let target = activeSharedOrbs.first {
            FDActionRow(
              title: Copy.Orbs.doWith(targetOrbName(target)),
              systemImage: "person.2.fill"
            ) {
              Task { await handleDoWith(target) }
            }
            .padding(.top, Theme.Spacing.xs)
          } else {
            FDActionRow(
              title: Copy.Orbs.doWithEllipsis,
              systemImage: "person.2.fill"
            ) {
              showMoveDialog = true
            }
            .padding(.top, Theme.Spacing.xs)
          }
        }

        Text(Copy.Availability.importedFoot(possessive))
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
          .lineSpacing(Theme.Spacing.xxs)
          .padding(.top, Theme.Spacing.base)

        Spacer(minLength: 0)
      }
      .padding(Theme.Spacing.lg)
      .background(Theme.paper.ignoresSafeArea())
      .presentationBackground(Theme.paper)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
            onClose()
          }
          .font(.body.weight(.semibold))
          .foregroundStyle(Theme.ink)
        }
      }
      .confirmationDialog(
        Copy.Orbs.doWithEllipsis,
        isPresented: $showMoveDialog,
        titleVisibility: .visible
      ) {
        ForEach(activeSharedOrbs, id: \.id) { target in
          Button(targetOrbLabel(target)) {
            Task { await handleDoWith(target) }
          }
        }
        Button("Cancel", role: .cancel) { }
      }
    }
  }
}
