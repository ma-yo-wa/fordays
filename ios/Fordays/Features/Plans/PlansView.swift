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
    guard app.space?.isMatched != true else { return [] }
    let day = app.pickedDay
    let myId = app.space?.myId
    return app.externalEvents.filter { e in
      let isMine = myId == e.userId || e.userId == "0"
      if !isMine { return false }
      let start = String(e.startsAt.prefix(10))
      let end = e.endsAt.isEmpty ? start : String(e.endsAt.prefix(10))
      return day >= start && day <= end
    }
  }

  private enum AgendaItem: Identifiable {
    case plan(Activity)
    case external(ExternalEvent)

    var id: String {
      switch self {
      case .plan(let a): return "p-\(a.id)"
      case .external(let e): return "e-\(e.id)"
      }
    }

    var sort: String {
      switch self {
      case .plan(let a): return a.dateTime ?? ""
      case .external(let e):
        if e.allDay { return "\(String(e.startsAt.prefix(10)))T99:00" }
        return e.startsAt
      }
    }
  }

  private var dayAgenda: [AgendaItem] {
    let plans = dayPlans.map { AgendaItem.plan($0) }
    let imported = dayExternal.map { AgendaItem.external($0) }
    return (plans + imported).sorted { $0.sort < $1.sort }
  }

  private var upNext: (date: String, countdown: String, dateFormatted: String, plans: [Activity])? {
    guard app.pickedDay == DateLocal.todayISO(),
          dayPlans.isEmpty && dayExternal.isEmpty else {
      return nil
    }
    let today = DateLocal.todayISO()
    let futurePlans = app.activities
      .filter { $0.isPlan && (DateLocal.dtDate($0.dateTime) ?? "") > today }
      .sorted { ($0.dateTime ?? "") < ($1.dateTime ?? "") }
    guard let first = futurePlans.first, let firstDate = DateLocal.dtDate(first.dateTime) else {
      return nil
    }
    let targetPlans = futurePlans.filter { (DateLocal.dtDate($0.dateTime) ?? "") == firstDate }
    let formatted = DateLocal.formatUpNext(firstDate, from: today)
    return (
      date: firstDate,
      countdown: formatted.countdown,
      dateFormatted: formatted.dateFormatted,
      plans: targetPlans
    )
  }

  var body: some View {
    ScrollView {
      ScrollOffsetTracker()

      VStack(spacing: Theme.Spacing.none) {
      monthGrid
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.row)
        .padding(.bottom, Theme.Spacing.sm)

      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Text(dayTitle)
          .font(.headline)
          .foregroundStyle(Theme.ink)
        if dayPlans.isEmpty && dayExternal.isEmpty {
          if let next = upNext {
            Text(emptyCopy)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, Theme.Spacing.xxs)
              .padding(.bottom, Theme.Spacing.s6)

            VStack(alignment: .leading, spacing: Theme.Spacing.s10) {
              VStack(alignment: .leading, spacing: Theme.Spacing.s3) {
                Text(Copy.Plans.upNext)
                  .font(.headline)
                  .foregroundStyle(Theme.ink)

                HStack(spacing: Theme.Spacing.s6) {
                  Text(next.countdown)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.roseInk)

                  Text("·")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                  Text(next.dateFormatted)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                }
              }
              .padding(.top, Theme.Spacing.xs)
              .padding(.horizontal, Theme.Spacing.xxs)

              ForEach(next.plans) { a in
                Button {
                  onSelect(a)
                } label: {
                  HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    planThumb(a)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                      Text(a.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                      Text(planTiming(a))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                      if let loc = a.location, !loc.isEmpty {
                        HStack(spacing: Theme.Spacing.xs) {
                          Text("📍").font(.caption2)
                          Text(loc)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                        }
                      }
                      if let note = a.description, !note.isEmpty {
                        Text(note)
                          .font(.footnote)
                          .foregroundStyle(Theme.inkFaint)
                      }
                      HStack(spacing: Theme.Spacing.s6) {
                        face(for: a.createdBy)
                        Text(displayName(for: a.createdBy))
                          .font(.footnote)
                          .foregroundStyle(Theme.inkSoft)
                      }
                    }
                    Spacer(minLength: 0)
                  }
                  .padding(Theme.Spacing.row)
                  .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
                }
                .buttonStyle(.plain)
              }
            }
          } else {
            Text(emptyCopy)
              .font(.subheadline)
              .foregroundStyle(Theme.inkSoft)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.top, Theme.Spacing.xl)
          }
        } else {
          ForEach(dayAgenda) { item in
            switch item {
            case .plan(let a):
              Button {
                onSelect(a)
              } label: {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                  planThumb(a)
                  VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(a.title)
                      .font(.body.weight(.medium))
                      .foregroundStyle(Theme.ink)
                    Text(planTiming(a))
                      .font(.footnote)
                      .foregroundStyle(Theme.inkSoft)
                    if let loc = a.location, !loc.isEmpty {
                      HStack(spacing: Theme.Spacing.xs) {
                        Text("📍").font(.caption2)
                        Text(loc)
                          .font(.footnote)
                          .foregroundStyle(Theme.inkSoft)
                      }
                    }
                    if let note = a.description, !note.isEmpty {
                      Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkFaint)
                    }
                    HStack(spacing: Theme.Spacing.s6) {
                      face(for: a.createdBy)
                      Text(displayName(for: a.createdBy))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    }
                  }
                  Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.row)
                .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
              }
              .buttonStyle(.plain)
            case .external(let e):
              let isMine = app.space?.myId == e.userId || e.userId == "0"
              let ownerName = isMine ? (app.space?.myName ?? "You") : displayName(for: e.userId)
              Button {
                onSelectExternal?(e)
              } label: {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                  externalThumb(e)
                  VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(e.title ?? Copy.Availability.busy)
                      .font(.body.weight(.medium))
                      .foregroundStyle(Theme.ink)
                    Text(planExternalTiming(e))
                      .font(.footnote)
                      .foregroundStyle(Theme.inkSoft)
                    if let loc = e.location, !loc.isEmpty {
                      HStack(spacing: Theme.Spacing.xs) {
                        Text("📍")
                          .font(.caption2)
                        Text(loc)
                          .font(.footnote)
                          .foregroundStyle(Theme.inkSoft)
                          .lineLimit(1)
                      }
                    }
                    HStack(spacing: Theme.Spacing.s6) {
                      face(for: e.userId)
                      Text(ownerName)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                      Text(e.sourceLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, Theme.Spacing.s6)
                        .padding(.vertical, Theme.TouchTarget.hairlineWidth)
                        .background(Theme.fillTertiary, in: Capsule())
                    }
                  }
                  Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.row)
                .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
              }
              .buttonStyle(.plain)
            }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.top, Theme.Spacing.s18)
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(Theme.hairline)
          .frame(height: Theme.TouchTarget.hairlineWidth)
      }
      .padding(.bottom, Theme.Spacing.scrollBottomClearance)
      }
    }
    .coordinateSpace(name: "homeScroll")
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
      let scrolled = minY < -6
      if app.isScrolled != scrolled {
        withAnimation(.easeInOut(duration: Theme.Motion.fade)) {
          app.isScrolled = scrolled
        }
      }
    }
    .onAppear {
      Task { await app.syncAppleIfNeeded() }
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
    .frame(width: Theme.TouchTarget.thumb, height: Theme.TouchTarget.thumb)
    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
  }

  @ViewBuilder
  private func externalThumb(_ e: ExternalEvent) -> some View {
    LinearGradient(
      colors: Theme.orbColors(for: e.id, title: e.title),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .frame(width: Theme.TouchTarget.thumb, height: Theme.TouchTarget.thumb)
    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
  }

  private var dayTitle: String {
    app.pickedDay == DateLocal.todayISO() ? "Today" : prettyDay(app.pickedDay)
  }

  private var emptyCopy: String {
    if app.space?.frozen == true {
      return Copy.Plans.emptyFrozen
    }
    var other: String? = nil
    if let space = app.space {
      let others = space.members.filter { $0.id != space.myId }
      if others.count == 1, let name = others.first?.name, name != space.myName {
        other = name
      } else if space.isMatched, others.isEmpty, let name = space.partnerName, name != space.myName {
        other = name
      }
    }
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

  private func planExternalTiming(_ e: ExternalEvent) -> String {
    let start = String(e.startsAt.prefix(10))
    let when = DateLocal.relativeDay(start)
    return "\(when) · \(externalTiming(e))"
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
      .frame(width: Theme.TouchTarget.avatarXs, height: Theme.TouchTarget.avatarXs)
      .background(fill, in: Circle())
  }

  private func displayName(for userId: String) -> String {
    guard let space = app.space else { return "?" }
    return space.displayName(for: userId)
  }

  private var monthGrid: some View {
    let days = monthDays()
    let today = DateLocal.todayISO()
    return VStack(spacing: Theme.Spacing.sm) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.none), count: 7), spacing: Theme.Spacing.s6) {
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
            let extCount = visibleExternalCount(on: iso)
            let isToday = iso == today
            let isPicked = app.pickedDay == iso
            Button {
              app.pickedDay = iso
            } label: {
              VStack(spacing: Theme.Spacing.xxs) {
                Text("\(calendar.component(.day, from: day))")
                  .font(.callout.weight(isToday ? .semibold : (isPicked ? .bold : .regular)))
                  .foregroundStyle(Theme.ink)
                  .frame(width: Theme.Spacing.s30, height: Theme.Spacing.s30)
                  .background {
                    if isToday {
                      Circle().fill(Theme.rose)
                    }
                  }

                let totalDots = min(count + extCount, 3)
                HStack(spacing: Theme.Spacing.xxs) {
                  ForEach(0..<totalDots, id: \.self) { _ in
                    Circle().fill(Theme.roseInk).frame(width: Theme.Spacing.xs, height: Theme.Spacing.xs)
                  }
                }
                .frame(height: Theme.Spacing.s5)
              }
              .padding(.top, Theme.Spacing.xs)
              .frame(maxWidth: .infinity, minHeight: Theme.TouchTarget.dayCellHeight, alignment: .top)
              .background(alignment: .top) {
                multiDayTrack(for: iso, index: index)
              }
            }
            .buttonStyle(.plain)
          } else {
            Color.clear.frame(height: Theme.TouchTarget.dayCellHeight)
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
    let isContinuationToNext = isRowEnd && !endsHere
    let isContinuationFromPrev = isRowStart && !startsHere

    if !spanning.isEmpty {
      GeometryReader { geo in
        let midX = geo.size.width / 2
        let left: CGFloat = startsHere ? (midX - 15) : 0
        let right: CGFloat = endsHere ? (midX - 15) : 0
        let roundL: CGFloat = startsHere ? 15 : 0
        let roundR: CGFloat = endsHere ? 15 : 0
        let width = max(0, geo.size.width - left - right)

        SpanningTrackShape(
          roundLeading: roundL,
          roundTrailing: roundR,
          chevronStart: isContinuationFromPrev,
          chevronEnd: isContinuationToNext
        )
        .fill(Theme.sageWash)
        .frame(width: width, height: Theme.TouchTarget.dayNumber)
        .offset(x: left, y: Theme.Spacing.xs)
      }
    }
  }

  private func visibleExternalCount(on day: String) -> Int {
    guard app.space?.isMatched != true else { return 0 }
    let myId = app.space?.myId
    return app.externalEvents.filter { e in
      let isMine = myId == e.userId || e.userId == "0"
      if !isMine { return false }
      let start = String(e.startsAt.prefix(10))
      let end = e.endsAt.isEmpty ? start : String(e.endsAt.prefix(10))
      return day >= start && day <= end
    }.count
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

struct SpanningTrackShape: Shape {
  let roundLeading: CGFloat
  let roundTrailing: CGFloat
  let chevronStart: Bool
  let chevronEnd: Bool

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let depth: CGFloat = 5
    let startX = rect.minX
    let endX = rect.maxX
    let midY = rect.midY

    // Start at top-left
    if chevronStart {
      path.move(to: CGPoint(x: startX + depth, y: rect.minY))
    } else if roundLeading > 0 {
      path.move(to: CGPoint(x: startX + roundLeading, y: rect.minY))
    } else {
      path.move(to: CGPoint(x: startX, y: rect.minY))
    }

    // Top-right & Right edge
    if chevronEnd {
      path.addLine(to: CGPoint(x: endX - depth, y: rect.minY))
      path.addLine(to: CGPoint(x: endX, y: midY))
      path.addLine(to: CGPoint(x: endX - depth, y: rect.maxY))
    } else if roundTrailing > 0 {
      path.addLine(to: CGPoint(x: endX - roundTrailing, y: rect.minY))
      path.addArc(
        center: CGPoint(x: endX - roundTrailing, y: rect.minY + roundTrailing),
        radius: roundTrailing,
        startAngle: .degrees(-90),
        endAngle: .degrees(90),
        clockwise: false
      )
    } else {
      path.addLine(to: CGPoint(x: endX, y: rect.minY))
      path.addLine(to: CGPoint(x: endX, y: rect.maxY))
    }

    // Bottom-left & Left edge
    if chevronStart {
      path.addLine(to: CGPoint(x: startX + depth, y: rect.maxY))
      path.addLine(to: CGPoint(x: startX, y: midY))
      path.closeSubpath()
    } else if roundLeading > 0 {
      path.addLine(to: CGPoint(x: startX + roundLeading, y: rect.maxY))
      path.addArc(
        center: CGPoint(x: startX + roundLeading, y: rect.minY + roundLeading),
        radius: roundLeading,
        startAngle: .degrees(90),
        endAngle: .degrees(270),
        clockwise: false
      )
      path.closeSubpath()
    } else {
      path.addLine(to: CGPoint(x: startX, y: rect.maxY))
      path.closeSubpath()
    }

    return path
  }
}

