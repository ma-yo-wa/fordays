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
      .sorted { $0.createdAt > $1.createdAt }

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
      .sorted { $0.createdAt > $1.createdAt }
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
    VStack(spacing: Theme.Spacing.none) {
      topSearchBar
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.vertical, Theme.Spacing.sm)
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
    HStack(spacing: Theme.Spacing.sm) {
      Button {
        onClose()
      } label: {
        Image(systemName: "chevron.left")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .frame(width: Theme.TouchTarget.avatarMd, height: Theme.TouchTarget.avatarMd)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Copy.Search.cancel)

      HStack(spacing: Theme.Spacing.sm) {
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
      .padding(.horizontal, Theme.Spacing.s10)
      .padding(.vertical, Theme.Spacing.sm)
      .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
          .stroke(Theme.hairline, lineWidth: Theme.TouchTarget.hairlineWidth)
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
        VStack(spacing: Theme.Spacing.md) {
          Image(systemName: "magnifyingglass")
            .font(.fdGlyph)
            .foregroundStyle(Theme.inkFaint)
          Text(Copy.Search.emptyPrompt)
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if !recents.plans.isEmpty {
              VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Upcoming Plans")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.inkSoft)
                  .textCase(.uppercase)
                  .padding(.horizontal, Theme.Spacing.xs)

                ForEach(recents.plans) { item in
                  activityRow(item, accentColor: Theme.rose, trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                }
              }
            }

            if !recents.someday.isEmpty {
              VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Recent in Someday")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Theme.inkSoft)
                  .textCase(.uppercase)
                  .padding(.horizontal, Theme.Spacing.xs)

                ForEach(recents.someday) { item in
                  activityRow(item, accentColor: Theme.inkFaint, badge: Copy.Search.someday)
                }
              }
            }
          }
          .padding(.horizontal, Theme.Spacing.base)
          .padding(.top, Theme.Spacing.row)
          .padding(.bottom, Theme.Spacing.xxxl)
        }
      }
    } else if results.totalCount == 0 {
      VStack(spacing: Theme.Spacing.md) {
        Text(Copy.Search.noResults(q))
          .font(.subheadline)
          .foregroundStyle(Theme.inkSoft)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          if !results.plans.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              Text("\(Copy.Search.plans) (\(results.plans.reduce(0) { $0 + $1.items.count }))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Spacing.xs)

              ForEach(results.plans) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
                  if !group.dayLabel.isEmpty {
                    Text(group.dayLabel)
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(Theme.ink)
                      .padding(.horizontal, Theme.Spacing.xs)
                  }

                  ForEach(group.items) { item in
                    activityRow(item, accentColor: Theme.rose, trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                  }
                }
              }
            }
          }

          if !results.someday.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              Text("\(Copy.Search.someday) (\(results.someday.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Spacing.xs)

              ForEach(results.someday) { item in
                activityRow(item, accentColor: Theme.inkFaint, badge: Copy.Search.someday)
              }
            }
          }

          if !results.memories.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              Text("\(Copy.Search.memories) (\(results.memories.reduce(0) { $0 + $1.items.count }))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Spacing.xs)

              ForEach(results.memories) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
                  if !group.dayLabel.isEmpty {
                    Text(group.dayLabel)
                      .font(.subheadline.weight(.semibold))
                      .foregroundStyle(Theme.ink)
                      .padding(.horizontal, Theme.Spacing.xs)
                  }

                  ForEach(group.items) { item in
                    activityRow(item, accentColor: Theme.rose, trailingTime: DateLocal.formatItemTime(dateTime: item.dateTime, endsAt: item.endsAt))
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.vertical, Theme.Spacing.row)
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
      HStack(spacing: Theme.Spacing.md) {
        RoundedRectangle(cornerRadius: Theme.radiusXs, style: .continuous)
          .fill(accentColor)
          .frame(width: Theme.Spacing.s3)
          .frame(maxHeight: .infinity)

        VStack(alignment: .leading, spacing: Theme.Spacing.s3) {
          Text(item.title)
            .font(.headline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)

          if let loc = item.location, !loc.isEmpty {
            HStack(spacing: Theme.Spacing.xs) {
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

        Spacer(minLength: Theme.Spacing.xs)

        if let trailingTime, !trailingTime.isEmpty {
          Text(trailingTime)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
        }

        if let badge {
          FDPill(title: badge, variant: .neutral, size: .sm)
        }
      }
      .padding(Theme.Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
          .stroke(Theme.hairline, lineWidth: Theme.TouchTarget.hairlineWidth)
      )
    }
    .buttonStyle(.plain)
  }
}
