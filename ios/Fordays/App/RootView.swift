import SwiftUI

struct RootView: View {
  @EnvironmentObject private var app: AppModel

  var body: some View {
    Group {
      switch app.authPhase {
      case .loading:
        ZStack {
          Theme.paper.ignoresSafeArea()
          ProgressView()
            .tint(Theme.roseInk)
        }
      case .signedOut:
        AuthView()
      case .signedIn:
        MainShellView()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: app.authPhase)
  }
}
