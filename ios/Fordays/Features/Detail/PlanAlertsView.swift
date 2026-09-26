import SwiftUI

/// Alert and Second alert, as in Calendar. Yours only: nobody else in the
/// Orb sees or shares them. Until you choose, your defaults apply.
struct PlanAlertsView: View {
  @EnvironmentObject private var app: AppModel
  let activityId: String
  let allDay: Bool

  @State private var alerts: [Int]?

  var body: some View {
    Group {
      if let alerts {
        let first = alerts.first ?? Alerts.none
        let second = alerts.count > 1 ? alerts[1] : Alerts.none
        row(title: "Alert", icon: true, value: first) { v in
          save(v == Alerts.none ? [] : (second == Alerts.none ? [v] : [v, second]))
        }
        if first != Alerts.none {
          row(title: "Second alert", icon: false, value: second) { v in
            save(v == Alerts.none ? [first] : [first, v])
          }
        }
      }
    }
    .task(id: "\(activityId)-\(allDay)") {
      alerts = nil
      let mine = await Alerts.loadPlan(activityId, allDay: allDay)
      if let mine {
        alerts = mine
      } else {
        let prefs = await Alerts.loadPrefs()
        alerts = allDay ? prefs.alertAllDay : prefs.alertTimed
      }
    }
  }

  private func row(title: String, icon: Bool, value: Int, onPick: @escaping (Int) -> Void) -> some View {
    Menu {
      Picker(title, selection: Binding(get: { value }, set: onPick)) {
        ForEach(Alerts.options(allDay: allDay), id: \.value) { option in
          Text(option.label).tag(option.value)
        }
      }
    } label: {
      HStack(spacing: Theme.Spacing.md) {
        // Warm grey icon beside ink text, like the tab bar.
        FormGlyphIcon(glyph: .bell)
          .foregroundStyle(Theme.inkSoft)
          .opacity(icon ? 1 : 0)
        Text(title)
          .font(.fdBody)
          .foregroundStyle(Theme.ink)
        Spacer()
        Text(Alerts.label(value, allDay: allDay))
          .font(.fdSubhead)
          .foregroundStyle(Theme.inkSoft)
      }
      .padding(.vertical, Theme.Spacing.md)
      .contentShape(Rectangle())
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Theme.hairline)
        .frame(height: Theme.TouchTarget.hairlineWidth)
    }
  }

  private func save(_ next: [Int]) {
    let before = alerts
    alerts = next
    Task {
      do {
        try await Alerts.savePlan(activityId, allDay: allDay, alerts: next)
      } catch {
        alerts = before
        app.toast = "Couldn’t save that. Check your connection and try again."
      }
    }
  }
}
