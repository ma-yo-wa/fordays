import Foundation
import Supabase
import UIKit
import UserNotifications

/// Push on iOS: permission, the APNs device token, and the row in
/// `push_subscriptions` that tells push-fan-out where to send. Same table
/// as the PWA; iOS rows are keyed `apns:<token>` (migration 020).
@MainActor
final class Push: ObservableObject {
  static let shared = Push()

  enum State: Equatable {
    case off
    case on
    case denied
  }

  @Published private(set) var state: State = .off

  private var sb: SupabaseClient { SupabaseService.shared.client }
  private let offKey = "fordays.push.off"
  private let tokenKey = "fordays.push.token"

  /// Turned off in Fordays (not in iOS Settings). Kept so a relaunch
  /// doesn't quietly register again.
  private var switchedOff: Bool {
    get { UserDefaults.standard.bool(forKey: offKey) }
    set { UserDefaults.standard.set(newValue, forKey: offKey) }
  }

  private var token: String? {
    get { UserDefaults.standard.string(forKey: tokenKey) }
    set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
  }

  private var endpoint: String? { token.map { "apns:\($0)" } }

  private init() {}

  func refresh() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .denied:
      state = .denied
    case .authorized, .provisional, .ephemeral:
      state = switchedOff ? .off : .on
    default:
      state = .off
    }
  }

  /// On launch and after sign-in: if they already said yes, ask iOS for
  /// the token again. It can change, and the callback re-registers it
  /// under whoever is signed in now.
  func syncIfAllowed() async {
    await refresh()
    guard state == .on else { return }
    UIApplication.shared.registerForRemoteNotifications()
  }

  /// The Settings switch turning on. Returns a line for the toast.
  func enable() async -> String {
    switchedOff = false
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .denied {
      state = .denied
      return "Notifications are blocked. Turn them on in iPhone Settings → Fordays"
    }
    if settings.authorizationStatus == .notDetermined {
      let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
      if !granted {
        await refresh()
        return "Notifications stay off"
      }
    }
    UIApplication.shared.registerForRemoteNotifications()
    await refresh()
    return "Notifications on"
  }

  func disable() async -> String {
    switchedOff = true
    await forgetThisDevice()
    await refresh()
    return "Notifications off"
  }

  /// From AppDelegate once APNs hands over the token.
  func didRegister(deviceToken: Data) async {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    let previous = endpoint
    token = hex
    guard !switchedOff else { return }
    guard sb.auth.currentSession != nil else { return }

    if let previous, previous != "apns:\(hex)" {
      _ = try? await sb.from("push_subscriptions").delete().eq("endpoint", value: previous).execute()
    }

    struct Device: Encodable {
      let device_endpoint: String
      let device_platform: String
      let device_apns_env: String
      let device_tz: String
      let device_agent: String
    }
    #if DEBUG
    let env = "sandbox"
    #else
    let env = "production"
    #endif
    let device = Device(
      device_endpoint: "apns:\(hex)",
      device_platform: "ios",
      device_apns_env: env,
      device_tz: TimeZone.current.identifier,
      device_agent: "Fordays iOS \(UIDevice.current.systemVersion)"
    )
    do {
      try await sb.rpc("register_push_device", params: device).execute()
    } catch {
      print("register_push_device failed:", error)
    }
  }

  /// Before sign-out, while the session can still delete its own row.
  func forgetThisDevice() async {
    guard let endpoint else { return }
    _ = try? await sb.from("push_subscriptions").delete().eq("endpoint", value: endpoint).execute()
  }
}
