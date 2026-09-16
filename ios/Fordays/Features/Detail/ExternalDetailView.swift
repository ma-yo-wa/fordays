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
    target.partnerName ?? target.name
  }

  private func targetOrbLabel(_ target: SpaceInfo) -> String {
    if let partner = target.partnerName {
      return "\(partner) (\(target.name))"
    }
    return target.name
  }

  private var rangeDescription: String {
    let startDay = String(event.startsAt.prefix(10))
    let endDay = event.endsAt.isEmpty ? startDay : String(event.endsAt.prefix(10))
    if event.allDay {
      if startDay == endDay {
        return "\(DateLocal.relativeDay(startDay)) · All day"
      }
      return "\(DateLocal.relativeDay(startDay)) – \(DateLocal.relativeDay(endDay)) · All day"
    }
    let startTime = event.startsAt.count > 10 ? DateLocal.prettyLower(String(event.startsAt.dropFirst(11).prefix(5))) : ""
    let endTime = event.endsAt.count > 10 ? DateLocal.prettyLower(String(event.endsAt.dropFirst(11).prefix(5))) : ""
    if startDay == endDay {
      if !startTime.isEmpty && !endTime.isEmpty {
        return "\(DateLocal.relativeDay(startDay)) · \(startTime) – \(endTime)"
      }
      return "\(DateLocal.relativeDay(startDay)) · \(startTime)"
    }
    return "\(DateLocal.relativeDay(startDay)) \(startTime) – \(DateLocal.relativeDay(endDay)) \(endTime)"
  }

  private func handleDoWith(_ targetSpace: SpaceInfo) async {
    let title = event.title ?? "Plan"
    dismiss()
    await app.createActivity(
      title: title,
      description: nil,
      location: event.location,
      imageUrl: nil,
      dateTime: event.startsAt.isEmpty ? nil : event.startsAt,
      endsAt: event.endsAt.isEmpty ? nil : event.endsAt,
      spaceId: targetSpace.id
    )
    let name = targetOrbName(targetSpace)
    app.toast = "Moved to \(name)’s Plans"
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack(alignment: .top, spacing: 14) {
          LinearGradient(
            colors: Theme.orbColors(for: event.id, title: event.title),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .frame(width: 46, height: 46)
          .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

          VStack(alignment: .leading, spacing: 4) {
            Text(event.title ?? Copy.Availability.busy)
              .font(.title2.weight(.bold))
              .foregroundStyle(Theme.ink)
            Text(rangeDescription)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
            if let loc = event.location, !loc.isEmpty {
              if let url = URL(string: "https://maps.apple.com/?q=\(loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc)") {
                Link(destination: url) {
                  HStack(spacing: 4) {
                    Text("📍")
                      .font(.caption)
                    Text(loc)
                      .font(.subheadline)
                      .foregroundStyle(Theme.inkSoft)
                      .lineLimit(1)
                    Image(systemName: "arrow.up.right")
                      .font(.caption2)
                      .foregroundStyle(Theme.inkFaint)
                  }
                }
              }
            }
          }
        }
        .padding(.bottom, 20)

        Divider()
          .overlay(Theme.hairline)

        // Rows
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 10) {
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
        .padding(.vertical, 16)

        // Do with [Partner] action
        if app.space?.isMatched != true, !activeSharedOrbs.isEmpty {
          if activeSharedOrbs.count == 1, let target = activeSharedOrbs.first {
            FDActionRow(
              title: Copy.Orbs.doWith(targetOrbName(target)),
              systemImage: "person.2.fill"
            ) {
              Task { await handleDoWith(target) }
            }
            .padding(.top, 4)
          } else {
            FDActionRow(
              title: Copy.Orbs.doWithEllipsis,
              systemImage: "person.2.fill"
            ) {
              showMoveDialog = true
            }
            .padding(.top, 4)
          }
        }

        Text(Copy.Availability.importedFoot(possessive))
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
          .lineSpacing(2)
          .padding(.top, 16)

        Spacer(minLength: 0)
      }
      .padding(20)
      .background(Theme.paper.ignoresSafeArea())
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
