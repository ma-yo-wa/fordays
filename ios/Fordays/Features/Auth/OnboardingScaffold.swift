import SwiftUI

/// The frame every onboarding screen sits in, matching the PWA's Auth.module.css
/// (.wrap, .brand, .lead): the orb background, a large title, a soft lead, and
/// the whole block centred in the screen with 28pt sides.
struct OnboardingScaffold<Content: View>: View {
  let title: String
  let lead: String
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      OrbBackground().ignoresSafeArea()
      GeometryReader { geo in
        ScrollView {
          VStack(alignment: .leading, spacing: Theme.Spacing.none) {
            Text(title)
              .font(.fdLargeTitle)
              .foregroundStyle(Theme.ink)
              .padding(.bottom, Theme.Spacing.sm)

            Text(lead)
              .font(.fdBody)
              .foregroundStyle(Theme.inkSoft)
              .padding(.bottom, Theme.Spacing.s28)

            content
          }
          .padding(.horizontal, Theme.Spacing.s28)
          .padding(.vertical, Theme.Spacing.xxxl)
          .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
      }
    }
  }
}
