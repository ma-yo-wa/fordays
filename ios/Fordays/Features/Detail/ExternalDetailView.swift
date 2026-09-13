import SwiftUI

struct ExternalDetailView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss

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

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack(alignment: .top, spacing: 14) {
          Text(Art.emoji(for: event.title))
            .font(.system(size: 36))
            .frame(width: 46, height: 46)

          VStack(alignment: .leading, spacing: 4) {
            Text(event.title ?? Copy.Availability.busy)
              .font(.title2.weight(.bold))
              .foregroundStyle(Theme.ink)
            Text(rangeDescription)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
          }
        }
        .padding(.bottom, 20)

        Divider()
          .overlay(Theme.ink.opacity(0.08))

        // Rows
        VStack(alignment: .leading, spacing: 14) {
          // Owner row
          HStack(spacing: 10) {
            face(for: event.userId)
            Text("\(ownerName)\(event.calendar.isEmpty ? "" : " · \(event.calendar)")")
              .font(.subheadline)
              .foregroundStyle(Theme.ink)
          }

          // Location row
          if let loc = event.location, !loc.isEmpty {
            HStack(spacing: 10) {
              Image(systemName: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 18)
              Text(loc)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            }
          }

          // Privacy / sync note
          HStack(spacing: 10) {
            Image(systemName: "lock.fill")
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
              .frame(width: 18)
            Text(event.title != nil ? Copy.Availability.notSharedPlan(possessive) : Copy.Availability.busyPrivate)
              .font(.subheadline)
              .foregroundStyle(Theme.ink)
          }
        }
        .padding(.vertical, 16)

        Divider()
          .overlay(Theme.ink.opacity(0.08))

        // Make plan primary button
        if event.title != nil && event.isFutureOrToday(today: DateLocal.todayISO()) && app.space?.canCompose == true {
          Button {
            dismiss()
            onMakePlan?(PlanDraft.from(external: event))
          } label: {
            Text(Copy.Availability.makePlan)
              .font(.headline.weight(.semibold))
              .foregroundStyle(Theme.paperWarm)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 13)
              .background(Theme.roseInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
          .padding(.top, 20)
        }

        Text(Copy.Availability.importedFoot(possessive))
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
          .lineSpacing(2)
          .padding(.top, 14)

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
    }
  }

  private func face(for userId: String) -> some View {
    let me = app.space?.myId
    let seat = (me != nil && userId == me) ? (app.space?.me ?? 0) : (1 - (app.space?.me ?? 0))
    let fill = seat == 0 ? Theme.faceSage : Theme.faceRose
    return Text(String(ownerName.prefix(1)).uppercased())
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: 18, height: 18)
      .background(fill, in: Circle())
  }
}
