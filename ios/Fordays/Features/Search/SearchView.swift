import SwiftUI

struct SearchView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void
  var onClose: () -> Void

  @State private var query = ""
  @FocusState private var isFocused: Bool

  struct DayGroup: Identifiable {
    var id: String { dayKey }
    let dayKey: String
    let dayLabel: String
    let items: [Activity]
  }

  private var filteredActivities: (plans: [DayGroup], someday: [Activity], memories: [DayGroup], totalCount: Int) {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else {
      return ([], [], [], 0)
    }

    let matches = app.activities.filter { a in
      let matchTitle = a.title.lowercased().contains(q)
      let matchLoc = (a.location ?? "").lowercased().contains(q)
      let matchDesc = (a.description ?? "").lowercased().contains(q)
      return matchTitle || matchLoc || matchDesc
    }

    let plans = matches.filter { $0.isPlan && !$0.isMemory() }
      .sorted { ($0.dateTime ?? "") < ($1.dateTime ?? "") }

    let someday = matches.filter { !$0.isPlan }
      .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }

    let memories = matches.filter { $0.isPlan && $0.isMemory() }
      .sorted { ($0.dateTime ?? "") > ($1.dateTime ?? "") }

    return (
      group(plans),
      someday,
      group(memories),
      matches.count
    )
  }

  private var recentActivities: (plans: [Activity], someday: [Activity]) {
    let upcomingPlans = app.activities
      .filter { $0.isPlan && !$0.isMemory() }
      .sorted { ($0.dateTime ?? "") < ($1.dateTime ?? "") }
      .prefix(4)
    let recentSomeday = app.activities
      .filter { !$0.isPlan }
      .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
      .prefix(4)
    return (Array(upcomingPlans), Array(recentSomeday))
  }

  private func group(_ list: [Activity]) -> [DayGroup] {
    var order: [String] = []
    var map: [String: [Activity]] = [:]
    for item in list {
      let day = DateLocal.dtDate(item.dateTime) ?? "unknown"
      if map[day] == nil {
        order.append(day)
        map[day] = []
      }
      map[day]?.append(item)
    }
    return order.map { day in
      DayGroup(
        dayKey: day,
        dayLabel: day != "unknown" ? DateLocal.searchDateTitle(day) : "",
        items: map[day] ?? []
      )
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      topSearchBar
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.paper)

      Divider()

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
    .background(Theme.paper.ignoresSafeArea())
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isFocused = true
      }
    }
  }

  private var topSearchBar: some View {
    HStack(spacing: 8) {
      Button {
        onClose()
      } label: {
        Image(systemName: "chevron.left")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Copy.Search.cancel)

      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.subheadline)
          .foregroundStyle(Theme.inkFaint)

        TextField(Copy.Search.placeholder, text: $query)
          .font(.body)
          .foregroundStyle(Theme.ink)
          .focused($isFocused)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
          .submitLabel(.search)

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.subheadline)
              .foregroundStyle(Theme.inkFaint)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Theme.ink.opacity(0.06), lineWidth: 0.5)
      )

      Button(Copy.Search.cancel) {
        onClose()
      }
      .font(.body)
      .foregroundStyle(Theme.roseInk)
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var content: some View {
    let results = filteredActivities
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

    if q.isEmpty {
      let recents = recentActivities
      if recents.plans.isEmpty && recents.someday.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 36))
            .foregroundStyle(Theme.inkFaint.opacity(0.4))
          Text(Copy.Search.emptyPrompt)
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 20) {
            if !recents.plans.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Plans")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.inkSoft)
                  .textCase(.uppercase)
                  .padding(.horizontal, 4)

                ForEach(recents.plans) { item in
                  activityRow(item, accentColor: Theme.rose, trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                }
              }
            }

            if !recents.someday.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Recent in Someday")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.inkSoft)
                  .textCase(.uppercase)
                  .padding(.horizontal, 4)

                ForEach(recents.someday) { item in
                  activityRow(item, accentColor: Theme.inkFaint, badge: Copy.Search.someday)
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 14)
          .padding(.bottom, 40)
        }
      }
    } else if results.totalCount == 0 {
      VStack(spacing: 12) {
        Text(Copy.Search.noResults(q))
          .font(.subheadline)
          .foregroundStyle(Theme.inkSoft)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 20) {
          if !results.plans.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("\(Copy.Search.plans) (\(results.plans.reduce(0) { $0 + $1.items.count }))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

              ForEach(results.plans) { group in
                VStack(alignment: .leading, spacing: 6) {
                  if !group.dayLabel.isEmpty {
                    Text(group.dayLabel)
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(Theme.ink)
                      .padding(.horizontal, 4)
                  }

                  ForEach(group.items) { item in
                    activityRow(item, accentColor: Theme.rose, trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                  }
                }
              }
            }
          }

          if !results.someday.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("\(Copy.Search.someday) (\(results.someday.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

              ForEach(results.someday) { item in
                activityRow(item, accentColor: Theme.inkFaint, badge: Copy.Search.someday)
              }
            }
          }

          if !results.memories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("\(Copy.Search.memories) (\(results.memories.reduce(0) { $0 + $1.items.count }))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

              ForEach(results.memories) { group in
                VStack(alignment: .leading, spacing: 6) {
                  if !group.dayLabel.isEmpty {
                    Text(group.dayLabel)
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(Theme.ink)
                      .padding(.horizontal, 4)
                  }

                  ForEach(group.items) { item in
                    activityRow(item, accentColor: Theme.roseInk.opacity(0.6), trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
      }
    }
  }

  private func activityRow(
    _ item: Activity,
    accentColor: Color,
    trailingTime: String? = nil,
    badge: String? = nil
  ) -> some View {
    Button {
      onSelect(item)
    } label: {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(accentColor)
          .frame(width: 3.5)
          .frame(maxHeight: .infinity)

        VStack(alignment: .leading, spacing: 3) {
          Text(item.title)
            .font(.headline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)

          if let loc = item.location, !loc.isEmpty {
            HStack(spacing: 4) {
              Text("📍").font(.caption2)
              Text(loc)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            }
          }

          if let desc = item.description, !desc.isEmpty {
            Text(desc)
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)
              .lineLimit(1)
          }
        }

        Spacer(minLength: 4)

        if let trailingTime, !trailingTime.isEmpty {
          Text(trailingTime)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
        }

        if let badge {
          FDPill(title: badge, variant: .neutral, size: .sm)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(Theme.ink.opacity(0.06), lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
  }
}
