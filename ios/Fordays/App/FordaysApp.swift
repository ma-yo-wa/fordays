import SwiftUI

@main
struct FordaysApp: App {
  @StateObject private var app = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(app)
        .preferredColorScheme(.light)
        .task { await app.boot() }
        .onOpenURL { url in
          Task { await app.handleOpenURL(url) }
        }
    }
  }
}
