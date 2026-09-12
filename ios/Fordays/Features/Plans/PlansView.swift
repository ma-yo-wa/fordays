import SwiftUI

struct PlansView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void
  var onInvite: () -> Void = {}

  @State private var cursorMonth: Date = Date()
  @State private var pickedDay: String = DateLocal.todayISO()

  private var calendar: Calendar { Calendar.current }

  private var plans: [Activity] {
    app.activities.filter(\.isPlan)
  }

  private var dayPlans: [Activity] {
    plans.filter { activity in
      guard let start = activity.dateTime.map({ String($0.prefix(10)) }) else { return false }
      let end = activity.endsAt.map { String($0.prefix(10)) } ?? start
      return pickedDay >= start && pickedDay <= end
    }
    .sorted { ($0.dateTime ?? "") < ($1.dateTime ?? "") }
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
        Spacer(minLength: 0)
      }
      .padding(20)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(
        Theme.paperWarm
          .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
          .shadow(color: Theme.ink.opacity(0.08), radius: 20, y: -4)
          .ignoresSafeArea(edges: .bottom)
      )
      .padding(.bottom, 88)
    }
  }

  @ViewBuilder
  private func planThumb(_ a: Activity) -> some View {
    Group {
      if let urlStr = a.imageUrl, let url = URL(string: urlStr) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let img):
            img.resizable().scaledToFill()
          default:
            LinearGradient(
              colors: Theme.orbColors(for: a.id, title: a.title),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          }
        }
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
    pickedDay == DateLocal.todayISO() ? "Today" : prettyDay(pickedDay)
  }

  private var emptyCopy: String {
    if app.space?.frozen == true {
      return "A copy from when you left"
    }
    let other = app.space?.isMatched == true ? app.space?.partnerName : nil
    let today = pickedDay == DateLocal.todayISO()
    if let other {
      return today
        ? "Nothing planned between you and \(other) today"
        : "Nothing planned between you and \(other) this day"
    }
    return today ? "Nothing planned today" : "Nothing planned this day"
  }

  private func planTiming(_ a: Activity) -> String {
    let start = a.dateTime.map { String($0.prefix(10)) } ?? pickedDay
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
    return VStack(spacing: 8) {
      HStack {
        Button {
          cursorMonth = calendar.date(byAdding: .month, value: -1, to: cursorMonth) ?? cursorMonth
        } label: {
          Image(systemName: "chevron.left").foregroundStyle(Theme.roseInk)
        }
        Spacer()
        Text(monthHeader)
          .font(.headline)
        Spacer()
        Button {
          cursorMonth = calendar.date(byAdding: .month, value: 1, to: cursorMonth) ?? cursorMonth
        } label: {
          Image(systemName: "chevron.right").foregroundStyle(Theme.roseInk)
        }
      }
      .padding(.horizontal, 8)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
          Text(d)
            .font(.caption2)
            .foregroundStyle(Theme.inkFaint)
        }
        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
          if let day {
            let iso = DateLocal.todayISO(day)
            let count = planCount(on: iso)
            Button {
              pickedDay = iso
            } label: {
              VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                  .font(.body.weight(pickedDay == iso ? .semibold : .regular))
                  .foregroundStyle(Theme.ink)
                  .frame(width: 36, height: 36)
                  .background {
                    if pickedDay == iso {
                      Circle().fill(Theme.rose)
                    }
                  }
                HStack(spacing: 2) {
                  ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle().fill(Theme.rose).frame(width: 4, height: 4)
                  }
                }
                .frame(height: 6)
              }
            }
            .buttonStyle(.plain)
          } else {
            Color.clear.frame(height: 48)
          }
        }
      }
    }
  }

  private var monthHeader: String {
    let f = DateFormatter()
    f.dateFormat = "MMMM"
    return f.string(from: cursorMonth)
  }

  private func monthDays() -> [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: cursorMonth) else { return [] }
    let firstWeekday = calendar.component(.weekday, from: interval.start) // 1=Sun
    var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
    var d = interval.start
    while d < interval.end {
      days.append(d)
      d = calendar.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
    }
    return days
  }

  private func planCount(on day: String) -> Int {
    plans.filter { a in
      guard let start = a.dateTime.map({ String($0.prefix(10)) }) else { return false }
      let end = a.endsAt.map { String($0.prefix(10)) } ?? start
      return day >= start && day <= end
    }.count
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
