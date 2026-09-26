import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  weak var appModel: AppModel? {
    didSet {
      guard let app = appModel else { return }
      if pendingToday {
        pendingToday = false
        Task { @MainActor in
          app.goToday()
          app.tab = .plans
        }
      }
      if pendingActivityId == nil, let spId = pendingSpaceId {
        pendingSpaceId = nil
        Task { @MainActor in
          if app.space?.id != spId { await app.switchToSpace(spId) }
        }
      }
      if let actId = pendingActivityId {
        let spId = pendingSpaceId
        pendingActivityId = nil
        pendingSpaceId = nil
        Task { @MainActor in
          await app.navigateToActivity(activityId: actId, spaceId: spId)
        }
      }
    }
  }

  private var pendingActivityId: String?
  private var pendingSpaceId: String?
  private var pendingToday = false

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Task { @MainActor in
      await Push.shared.didRegister(deviceToken: deviceToken)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("APNs registration failed:", error)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let activityId = (userInfo["activityId"] as? String)
      ?? (userInfo["activity_id"] as? String)
      ?? (userInfo["a"] as? String)
    let spaceId = (userInfo["spaceId"] as? String)
      ?? (userInfo["space_id"] as? String)
      ?? (userInfo["s"] as? String)

    let kind = userInfo["kind"] as? String

    if kind == "summary" {
      // The morning summary: Plans, on today.
      Task { @MainActor in
        if let app = self.appModel {
          app.goToday()
          app.tab = .plans
        } else {
          self.pendingToday = true
        }
      }
    } else if let activityId, !activityId.isEmpty {
      if let app = appModel {
        Task { @MainActor in
          await app.navigateToActivity(activityId: activityId, spaceId: spaceId)
        }
      } else {
        pendingActivityId = activityId
        pendingSpaceId = spaceId
      }
    } else if let spaceId, !spaceId.isEmpty {
      // Joined, left, removed, or several adds: open that Orb.
      Task { @MainActor in
        if let app = self.appModel {
          if app.space?.id != spaceId { await app.switchToSpace(spaceId) }
        } else {
          self.pendingSpaceId = spaceId
        }
      }
    } else if let urlStr = userInfo["url"] as? String, let url = URL(string: urlStr) {
      if let app = appModel {
        Task { @MainActor in
          await app.handleOpenURL(url)
        }
      } else {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        pendingActivityId = components?.queryItems?.first(where: { $0.name == "a" })?.value
        pendingSpaceId = components?.queryItems?.first(where: { $0.name == "s" })?.value
      }
    }
    completionHandler()
  }
}

@main
struct FordaysApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var app = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(app)
        .preferredColorScheme(.light)
        // Never smaller than the default size — the PWA's 17px ramp — but
        // still larger for people who turn Text Size up.
        .dynamicTypeSize(.large...)
        .task {
          appDelegate.appModel = app
          await app.boot()
        }
        .onOpenURL { url in
          Task { await app.handleOpenURL(url) }
        }
    }
  }
}
