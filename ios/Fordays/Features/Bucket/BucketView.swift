import SwiftUI

struct BucketView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void
  var onInvite: () -> Void = {}

  private var items: [Activity] {
    app.activities
      .filter(\.isBucketItem)
      .sorted { $0.createdAt > $1.createdAt }
  }

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  var body: some View {
    ScrollView {
      ScrollOffsetTracker()

      if items.isEmpty {
        empty
      } else {
        LazyVGrid(columns: columns, spacing: 14) {
          ForEach(items) { a in
            ActivityCard(activity: a) { onSelect(a) }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 132)
      }
    }
    .coordinateSpace(name: "homeScroll")
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
      let scrolled = minY < -6
      if app.isScrolled != scrolled {
        withAnimation(.easeInOut(duration: 0.18)) {
          app.isScrolled = scrolled
        }
      }
    }
  }

  private var empty: some View {
    Text(
      app.space?.frozen == true
        ? Copy.Ideas.emptyFrozen
        : app.space?.isMatched == true
          ? Copy.Ideas.emptyShared
          : Copy.Ideas.emptySolo
    )
    .font(.subheadline)
    .foregroundStyle(Theme.inkSoft)
    .multilineTextAlignment(.center)
    .frame(maxWidth: 260)
    .frame(maxWidth: .infinity)
    .padding(.top, 56)
  }
}

struct MemoriesView: View {
  @EnvironmentObject private var app: AppModel
  var onSelect: (Activity) -> Void

  private var today: String { DateLocal.todayISO() }

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  private var sections: [(key: String, label: String, items: [Activity])] {
    let items = app.activities
      .filter { $0.isMemory(today: today) }
      .sorted {
        ($0.endsAt ?? $0.dateTime ?? "") > ($1.endsAt ?? $1.dateTime ?? "")
      }
    var map: [String: [Activity]] = [:]
    for a in items {
      guard let key = a.monthKey else { continue }
      map[key, default: []].append(a)
    }
    return map.keys.sorted(by: >).map { key in
      (key, DateLocal.monthLabel(key), map[key]!)
    }
  }

  var body: some View {
    ScrollView {
      ScrollOffsetTracker()

      if sections.isEmpty {
        Text(
          app.space?.isMatched == true
            ? "Plans you’ve lived together will land here"
            : "Plans you’ve lived will land here"
        )
        .font(.subheadline)
        .foregroundStyle(Theme.inkSoft)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
      } else {
        // VStack (not LazyVStack) so each month grid lays out with real widths.
        VStack(alignment: .leading, spacing: 22) {
          ForEach(sections, id: \.key) { section in
            VStack(alignment: .leading, spacing: 10) {
              Text(section.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 2)
              LazyVGrid(columns: columns, spacing: 14) {
                ForEach(section.items) { a in
                  ActivityCard(activity: a) { onSelect(a) }
                }
              }
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 132)
      }
    }
    .coordinateSpace(name: "homeScroll")
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
      let scrolled = minY < -6
      if app.isScrolled != scrolled {
        withAnimation(.easeInOut(duration: 0.18)) {
          app.isScrolled = scrolled
        }
      }
    }
  }
}

struct ActivityCard: View {
  @EnvironmentObject private var app: AppModel
  let activity: Activity
  var onTap: () -> Void

  private var who: String {
    guard let space = app.space else { return "" }
    return space.displayName(for: activity.createdBy)
  }

  var body: some View {
    Button(action: onTap) {
      ZStack(alignment: .bottomLeading) {
        LinearGradient(
          colors: Theme.orbColors(for: activity.id, title: activity.title),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        if let urlStr = activity.imageUrl, !urlStr.isEmpty {
          RemoteOrDataImage(urlString: urlStr, contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }

        LinearGradient(
          colors: [.clear, Theme.veil],
          startPoint: UnitPoint(x: 0.5, y: 0.4),
          endPoint: .bottom
        )

        VStack(alignment: .leading, spacing: 6) {
          Text(activity.title)
            .font(.headline)
            .foregroundStyle(Color(hex: 0xFFFDFB))
            .multilineTextAlignment(.leading)
            .lineLimit(4)
          Text(who)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.paperTranslucent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
      }
      .frame(maxWidth: .infinity)
      .aspectRatio(3 / 4, contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
      .shadow(color: Theme.shadowCard, radius: 8, y: 6)
    }
    .buttonStyle(.plain)
  }
}
