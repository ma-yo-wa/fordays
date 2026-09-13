import SwiftUI

struct PlansView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void
  var onSelectExternal: ((ExternalEvent) -> Void)? = nil
  var onMakePlanFromExternal: ((ExternalEvent) -> Void)? = nil
  var onInvite: () -> Void = {}

  private var calendar: Calendar { Calendar.current }

  private var plans: [Activity] {
    app.activities.filter(\.isPlan)
  }

  private var dayPlans: [Activity] {
    plans.filter { activity in
      guard let start = activity.dateTime.map({ String($0.prefix(10)) }) else { return false }
      let end = activity.endsAt.map { String($0.prefix(10)) } ?? start
      return app.pickedDay >= start && app.pickedDay <= end
    }
    .sorted { ($0.dateTime ?? "") < ($1.dateTime ?? "") }
  }

  private var dayExternal: [ExternalEvent] {
    let day = app.pickedDay
    return app.externalEvents.filter { e in
      let start = String(e.startsAt.prefix(10))
      let end = e.endsAt.isEmpty ? start : String(e.endsAt.prefix(10))
      return day >= start && day <= end
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      monthGrid
        .padding(.horizontal, 12)
        .padding(.bottom, 8)

      VStack(alignment: .leading, spacing: 12) {
        Text(dayTitle)
          .font(.title3.weight(.semibold))
          .foregroundStyle(Theme.ink)
        if dayPlans.isEmpty {
          VStack(spacing: 14) {
            Text(emptyCopy)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 24)
        } else {
          ForEach(dayPlans) { a in
            Button {
              onSelect(a)
            } label: {
              HStack(alignment: .top, spacing: 12) {
                planThumb(a)
                VStack(alignment: .leading, spacing: 4) {
                  Text(a.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                  Text(planTiming(a))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                  if let note = a.description, !note.isEmpty {
                    Text(note)
                      .font(.footnote)
                      .foregroundStyle(Theme.inkFaint)
                  }
                  HStack(spacing: 6) {
                    face(for: a.createdBy)
                    Text(displayName(for: a.createdBy))
                      .font(.footnote)
                      .foregroundStyle(Theme.inkSoft)
                  }
                }
                Spacer(minLength: 0)
              }
              .padding(14)
              .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }

        if !dayExternal.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(Copy.Availability.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkFaint)
              Spacer()
              Text(Copy.Availability.googleCalendar)
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
            }
            .padding(.top, 10)

            ForEach(dayExternal) { e in
              let isMine = app.space?.myId == e.userId || e.userId == "0"
              let ownerName = isMine ? "You" : displayName(for: e.userId)
              HStack(spacing: 10) {
                Text(Art.emoji(for: e.title))
                  .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                  Text(e.title ?? Copy.Availability.busy)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                  Text("\(externalTiming(e)) · \(ownerName)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 4)

                if e.title != nil && app.space?.canCompose == true {
                  Button {
                    onMakePlanFromExternal?(e)
                  } label: {
                    Text(Copy.Availability.makePlanShort)
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(Theme.roseInk)
                      .padding(.horizontal, 9)
                      .padding(.vertical, 4)
                      .background(Theme.rose.opacity(0.18), in: Capsule())
                      .overlay(Capsule().stroke(Theme.roseInk.opacity(0.4), lineWidth: 0.8))
                  }
                  .buttonStyle(.plain)
                }

                face(for: e.userId)
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
              .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .onTapGesture {
                onSelectExternal?(e)
              }
            }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 20)
      .padding(.top, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(Theme.ink.opacity(0.08))
          .frame(height: 0.5)
      }
      .padding(.bottom, 88)
    }
  }

  @ViewBuilder
  private func planThumb(_ a: Activity) -> some View {
    Group {
      if let urlStr = a.imageUrl, !urlStr.isEmpty {
        RemoteOrDataImage(urlString: urlStr, contentMode: .fill)
      } else {
        LinearGradient(
          colors: Theme.orbColors(for: a.id, title: a.title),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
    .frame(width: 42, height: 42)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var dayTitle: String {
    app.pickedDay == DateLocal.todayISO() ? "Today" : prettyDay(app.pickedDay)
  }

  private var emptyCopy: String {
    if app.space?.frozen == true {
      return Copy.Plans.emptyFrozen
    }
    if !dayExternal.isEmpty {
      return Copy.Plans.emptyTogether
    }
    let other = app.space?.isMatched == true ? app.space?.partnerName : nil
    let today = app.pickedDay == DateLocal.todayISO()
    if let other {
      return today
        ? Copy.Plans.emptyTodayPartner(other)
        : Copy.Plans.emptyDayPartner(other)
    }
    return today ? Copy.Plans.emptyToday : Copy.Plans.emptyDay
  }

  private func externalTiming(_ e: ExternalEvent) -> String {
    let day = app.pickedDay
    if e.allDay { return "All day" }
    let startsToday = String(e.startsAt.prefix(10)) == day
    let endsToday = String(e.endsAt.prefix(10)) == day
    if startsToday && endsToday {
      let t = String(e.startsAt.dropFirst(11).prefix(5))
      return DateLocal.prettyLower(t)
    }
    if startsToday {
      let t = String(e.startsAt.dropFirst(11).prefix(5))
      return "From \(DateLocal.prettyLower(t))"
    }
    if endsToday {
      let t = String(e.endsAt.dropFirst(11).prefix(5))
      return "Until \(DateLocal.prettyLower(t))"
    }
    return "All day"
  }

  private func planTiming(_ a: Activity) -> String {
    let start = a.dateTime.map { String($0.prefix(10)) } ?? app.pickedDay
    let when = DateLocal.relativeDay(start)
    if let t = DateLocal.dtTime(a.dateTime) {
      return "\(when) · \(DateLocal.prettyLower(t))"
    }
    return "\(when) · All day"
  }

  private func face(for userId: String) -> some View {
    let me = app.space?.myId
    let seat = (me != nil && userId == me) ? (app.space?.me ?? 0) : (1 - (app.space?.me ?? 0))
    let fill = seat == 0 ? Theme.faceSage : Theme.faceRose
    return Text(String(displayName(for: userId).prefix(1)).uppercased())
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: 18, height: 18)
      .background(fill, in: Circle())
  }

  private func displayName(for userId: String) -> String {
    guard let space = app.space else { return "?" }
    return space.displayName(for: userId)
  }

  private var monthGrid: some View {
    let days = monthDays()
    let today = DateLocal.todayISO()
    return VStack(spacing: 8) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
          Text(d)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.inkFaint)
        }
        ForEach(days.indices, id: \.self) { index in
          let day = days[index]
          if let day {
            let iso = DateLocal.todayISO(day)
            let count = singlePlanCount(on: iso)
            let isToday = iso == today
            let isPicked = app.pickedDay == iso
            Button {
              app.pickedDay = iso
            } label: {
              VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                  .font(.callout.weight(isToday ? .semibold : (isPicked ? .semibold : .regular)))
                  .foregroundStyle(Theme.ink)
                  .frame(width: 30, height: 30)
                  .background {
                    if isToday {
                      Circle().fill(Theme.rose)
                    }
                  }
                  .overlay {
                    if isPicked {
                      Circle()
                        .stroke(Theme.roseInk, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    }
                  }

                HStack(spacing: 2) {
                  ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle().fill(Theme.roseInk).frame(width: 4, height: 4)
                  }
                }
                .frame(height: 5)
              }
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(alignment: .top) {
                multiDayTrack(for: iso, index: index)
              }
            }
            .buttonStyle(.plain)
          } else {
            Color.clear.frame(height: 52)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func multiDayTrack(for iso: String, index: Int) -> some View {
    let isRowStart = index % 7 == 0
    let isRowEnd = index % 7 == 6
    let spanning = plans.filter { a in
      guard let start = a.dateTime.map({ String($0.prefix(10)) }) else { return false }
      let end = a.endsAt.map { String($0.prefix(10)) } ?? start
      return start < end && iso >= start && iso <= end
    }
    let startsHere = spanning.contains { a in
      guard let start = a.dateTime.map({ String($0.prefix(10)) }) else { return false }
      return start == iso
    }
    let endsHere = spanning.contains { a in
      let end = a.endsAt.map { String($0.prefix(10)) } ?? String(a.dateTime?.prefix(10) ?? "")
      return end == iso
    }

    if !spanning.isEmpty {
      GeometryReader { geo in
        let midX = geo.size.width / 2
        let left: CGFloat = startsHere ? (midX - 15) : (isRowStart ? 2 : 0)
        let right: CGFloat = endsHere ? (midX - 15) : (isRowEnd ? 2 : 0)
        let roundL: CGFloat = startsHere ? 15 : (isRowStart ? 6 : 0)
        let roundR: CGFloat = endsHere ? 15 : (isRowEnd ? 6 : 0)
        let width = max(0, geo.size.width - left - right)

        UnevenRoundedRectangle(
          topLeadingRadius: roundL,
          bottomLeadingRadius: roundL,
          bottomTrailingRadius: roundR,
          topTrailingRadius: roundR
        )
        .fill(Theme.sage.opacity(0.26))
        .frame(width: width, height: 30)
        .offset(x: left, y: 0)
      }
    }
  }

  private func singlePlanCount(on day: String) -> Int {
    plans.filter { a in
      guard let start = a.dateTime.map({ String($0.prefix(10)) }) else { return false }
      let end = a.endsAt.map { String($0.prefix(10)) } ?? start
      return start == end && day == start
    }.count
  }

  private func monthDays() -> [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: app.cursorMonth) else { return [] }
    let firstWeekday = calendar.component(.weekday, from: interval.start) // 1=Sun
    var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
    var d = interval.start
    while d < interval.end {
      days.append(d)
      d = calendar.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
    }
    return days
  }

  private func prettyDay(_ iso: String) -> String {
    let parts = iso.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return iso }
    let names = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
    ]
    return "\(names[parts[1] - 1]) \(parts[2])"
  }
}
