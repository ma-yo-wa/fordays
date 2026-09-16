import SwiftUI

struct RootView: View {
  @EnvironmentObject private var app: AppModel

  var body: some View {
    Group {
      switch app.authPhase {
      case .loading:
        ZStack {
          OrbBackground().ignoresSafeArea()
          ProgressView()
            .tint(Theme.roseInk)
        }
      case .signedOut:
        AuthView()
      case .signedIn:
        if app.needsFirstOrbSetup {
          OrbSetupView()
        } else {
          MainShellView()
        }
      }
    }
    .animation(.easeInOut(duration: Theme.Motion.shelf), value: app.authPhase)
  }
}
