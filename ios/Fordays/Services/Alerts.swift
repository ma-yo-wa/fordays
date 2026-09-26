import Foundation
import Supabase

/// Reminders, the way Google and Apple Calendar do them (migration 021).
/// Alerts are yours, not the plan's: everyone in the Orb has their own.
/// A plan with none of your own uses your defaults. Same tables as the PWA.
enum Alerts {
  struct Option: Hashable {
    let value: Int
    let label: String
  }

  static let none = -1

  /// Minutes before a timed plan. Apple Calendar's list, in its order.
  static let timed: [Option] = [
    Option(value: 0, label: "At time of plan"),
    Option(value: 5, label: "5 minutes before"),
    Option(value: 10, label: "10 minutes before"),
    Option(value: 15, label: "15 minutes before"),
    Option(value: 30, label: "30 minutes before"),
    Option(value: 60, label: "1 hour before"),
    Option(value: 120, label: "2 hours before"),
    Option(value: 1440, label: "1 day before"),
    Option(value: 2880, label: "2 days before"),
    Option(value: 10080, label: "1 week before"),
  ]

  /// Days before an all-day plan, at 9 am. Apple's list.
  static let allDay: [Option] = [
    Option(value: 0, label: "On the day (9 am)"),
    Option(value: 1, label: "1 day before (9 am)"),
    Option(value: 2, label: "2 days before (9 am)"),
    Option(value: 7, label: "1 week before"),
  ]

  static func options(allDay isAllDay: Bool) -> [Option] {
    [Option(value: none, label: "None")] + (isAllDay ? allDay : timed)
  }

  static func label(_ value: Int, allDay isAllDay: Bool) -> String {
    options(allDay: isAllDay).first { $0.value == value }?.label ?? "None"
  }

  /// Morning summary times, every half hour from 5 am to 11 am.
  static let summaryTimes: [Option] = (0..<13).map { i in
    let minute = 300 + i * 30
    return Option(value: minute, label: String(format: "%d:%02d am", minute / 60, minute % 60))
  }

  struct Prefs: Equatable {
    var alertTimed: [Int] = [30]
    var alertAllDay: [Int] = [0]
    var summaryMinute: Int? = 480
    var quietHours = true
  }

  private struct PrefsRow: Codable {
    let user_id: String
    let alert_timed: [Int]?
    let alert_all_day: [Int]?
    let summary_minute: Int?
    let quiet_hours: Bool?
  }

  private struct PlanRow: Codable {
    let user_id: String
    let activity_id: String
    let all_day: Bool
    let alerts: [Int]
  }

  @MainActor private static var sb: SupabaseClient { SupabaseService.shared.client }

  @MainActor private static func uid() -> String? {
    sb.auth.currentSession?.user.id.uuidString.lowercased()
  }

  @MainActor static func loadPrefs() async -> Prefs {
    guard let me = uid() else { return Prefs() }
    let rows: [PrefsRow] = (try? await sb.from("notification_prefs")
      .select("user_id, alert_timed, alert_all_day, summary_minute, quiet_hours")
      .eq("user_id", value: me)
      .execute().value) ?? []
    guard let row = rows.first else { return Prefs() }
    return Prefs(
      alertTimed: row.alert_timed ?? [30],
      alertAllDay: row.alert_all_day ?? [0],
      summaryMinute: row.summary_minute,
      quietHours: row.quiet_hours ?? true
    )
  }

  @MainActor static func savePrefs(_ p: Prefs) async throws {
    guard let me = uid() else { return }
    try await sb.from("notification_prefs")
      .upsert(PrefsRow(
        user_id: me,
        alert_timed: p.alertTimed,
        alert_all_day: p.alertAllDay,
        summary_minute: p.summaryMinute,
        quiet_hours: p.quietHours
      ), onConflict: "user_id")
      .execute()
  }

  /// Your alerts on one plan, or nil when it follows your defaults.
  @MainActor static func loadPlan(_ activityId: String, allDay isAllDay: Bool) async -> [Int]? {
    guard let me = uid() else { return nil }
    let rows: [PlanRow] = (try? await sb.from("activity_alerts")
      .select("user_id, activity_id, all_day, alerts")
      .eq("user_id", value: me)
      .eq("activity_id", value: activityId)
      .execute().value) ?? []
    // Set for the other kind of plan: the defaults apply again.
    guard let row = rows.first, row.all_day == isAllDay else { return nil }
    return row.alerts
  }

  @MainActor static func savePlan(_ activityId: String, allDay isAllDay: Bool, alerts: [Int]) async throws {
    guard let me = uid() else { return }
    try await sb.from("activity_alerts")
      .upsert(PlanRow(user_id: me, activity_id: activityId, all_day: isAllDay, alerts: alerts),
              onConflict: "user_id,activity_id")
      .execute()
  }

  @MainActor static func loadMuted(_ spaceId: String) async -> Bool {
    guard let me = uid() else { return false }
    struct Row: Decodable { let muted: Bool? }
    let rows: [Row] = (try? await sb.from("space_members")
      .select("muted")
      .eq("space_id", value: spaceId)
      .eq("user_id", value: me)
      .execute().value) ?? []
    return rows.first?.muted ?? false
  }

  @MainActor static func setMuted(_ spaceId: String, _ muted: Bool) async throws {
    struct Params: Encodable { let target_space: String; let mute: Bool }
    try await sb.rpc("set_orb_muted", params: Params(target_space: spaceId, mute: muted)).execute()
  }
}
