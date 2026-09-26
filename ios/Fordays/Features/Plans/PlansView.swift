import SwiftUI

struct PlansView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void
  var onSelectExternal: ((ExternalEvent) -> Void)? = nil
  var onMakePlanFromExternal: ((ExternalEvent) -> Void)? = nil
  var onInvite: () -> Void = {}

  @State private var scrollRest: CGFloat?
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
    .sorted { Self.startKey($0.dateTime) < Self.startKey($1.dateTime) }
  }

  /// Ordered by when a plan actually began, not by clock time alone: a trip
  /// that started yesterday sits above today's plans. All-day sorts last within its day.
  private static func startKey(_ dateTime: String?) -> String {
    "\(DateLocal.dtDate(dateTime) ?? "9999-99-99") \(DateLocal.dtTime(dateTime) ?? "99")"
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

    func sort(on day: String) -> String {
      switch self {
      case .plan(let a): return PlansView.startKey(a.dateTime)
      case .external(let e):
        if e.allDay { return "\(day) 99" }
        return e.startsAt.contains("T")
          ? e.startsAt.replacingOccurrences(of: "T", with: " ")
          : "\(e.startsAt) 99"
      }
    }
  }

  private var dayAgenda: [AgendaItem] {
    let day = app.pickedDay
    let plans = dayPlans.map { AgendaItem.plan($0) }
    let imported = dayExternal.map { AgendaItem.external($0) }
    return (plans + imported).sorted { $0.sort(on: day) < $1.sort(on: day) }
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

              VStack(spacing: Theme.Spacing.none) {
                ForEach(next.plans) { a in
                  planRow(a)
                }
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
          VStack(spacing: Theme.Spacing.none) {
            ForEach(dayAgenda) { item in
              switch item {
              case .plan(let a):
                planRow(a)
              case .external(let e):
                let title = (e.title ?? "").isEmpty ? Copy.Availability.busy : (e.title ?? "")
                agendaRow(time: externalTiming(e), title: title, place: e.location) {
                  onSelectExternal?(e)
                }
              }
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
      if scrollRest == nil { scrollRest = minY }
      let scrolled = minY < (scrollRest ?? minY) - Theme.Spacing.s6
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

  /// A plan on the agenda: time on the left, title and place on the right.
  /// Cover, note and who made it live in Detail.
  /// In a shared Orb, a small face says who put the plan here.
  private func planRow(_ a: Activity) -> some View {
    let who = app.space?.isMatched == true ? app.space?.displayName(for: a.createdBy) : nil
    return agendaRow(time: rowTime(a), title: a.title, place: a.location, who: who) {
      onSelect(a)
    }
  }

  /// A chevron and a press highlight say the row opens something.
  private func agendaRow(
    time: String,
    title: String,
    place: String?,
    who: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
        Text(time)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(Theme.inkSoft)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .frame(width: Theme.TouchTarget.agendaTime, alignment: .leading)
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
          Text(title)
            .font(.body)
            .foregroundStyle(Theme.ink)
          if let place = shortPlace(place, title: title) {
            Text(place)
              .font(.footnote)
              .foregroundStyle(Theme.inkSoft)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        if let who {
          face(who)
        }
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.inkFaint)
          .accessibilityHidden(true)
      }
      .padding(.vertical, Theme.Spacing.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(RowPressStyle())
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Theme.hairline)
        .frame(height: Theme.TouchTarget.hairlineWidth)
    }
    .accessibilityElement(children: .combine)
  }

  private func face(_ name: String) -> some View {
    Text(String(name.prefix(1)).uppercased())
      .font(.caption2.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: Theme.TouchTarget.avatarXs, height: Theme.TouchTarget.avatarXs)
      .background(Theme.inkSoft, in: Circle())
      .accessibilityLabel("Added by \(name)")
  }

  /// The place name without the street address, or nil when the title already says it.
  private func shortPlace(_ place: String?, title: String) -> String? {
    guard let name = place?.split(separator: ",").first?
      .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
    else { return nil }
    return title.localizedCaseInsensitiveContains(name) ? nil : name
  }

  /// The day is already in the heading, so the row gives only the time.
  private func rowTime(_ a: Activity) -> String {
    DateLocal.dtTime(a.dateTime).map(DateLocal.prettyLower) ?? "All day"
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

  private var monthGrid: some View {
    let days = monthDays()
    let today = DateLocal.todayISO()
    return VStack(spacing: Theme.Spacing.sm) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.none), count: 7), spacing: Theme.Spacing.s6) {
        ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, d in
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

/// A quiet grey wash behind a list row while it's held down.
private struct RowPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
          .fill(configuration.isPressed ? Theme.fillQuaternary : Color.clear)
          .padding(.horizontal, -Theme.Spacing.sm)
      )
  }
}
