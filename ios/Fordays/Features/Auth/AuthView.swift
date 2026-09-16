import SwiftUI

struct AuthView: View {
  @EnvironmentObject private var app: AppModel
  @State private var mode: Mode = .signIn
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var busy = false

  enum Mode { case signIn, signUp }

  var body: some View {
    ZStack {
      Theme.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(Theme.brandName)
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.top, 48)
            .padding(.bottom, 8)

          if let peek = app.pendingInvitePeek {
            if mode == .signUp {
              if let spaceName = peek.spaceName, !spaceName.isEmpty {
                Text(Copy.Auth.invitedToNamedOrb(inviter: peek.inviterName, orb: spaceName))
                  .font(.title3.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.bottom, 20)
              } else {
                Text(Copy.Auth.invitedToOrb(peek.inviterName))
                  .font(.title3.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.bottom, 20)
              }
            } else {
              if let spaceName = peek.spaceName, !spaceName.isEmpty {
                Text("\(peek.inviterName) invited you to “\(spaceName)” — sign in to join")
                  .font(.title3.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.bottom, 20)
              } else {
                Text("\(peek.inviterName) invited you — sign in to join")
                  .font(.title3.weight(.medium))
                  .foregroundStyle(Theme.inkSoft)
                  .padding(.bottom, 20)
              }
            }
          } else {
            Text("Plans, Bucket lists and Memories")
              .font(.title3.weight(.medium))
              .foregroundStyle(Theme.inkSoft)
              .padding(.bottom, 20)
          }

          if mode == .signUp {
            FDTextField(label: "Your name", placeholder: "Aline", text: $name)
              .padding(.bottom, 12)
          }

          FDTextField(label: "Email", placeholder: "you@example.com", text: $email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .padding(.bottom, 12)

          FDTextField(label: "Password", placeholder: "••••••••", text: $password, isSecure: true)

          FDButton(
            mode == .signUp
              ? (app.pendingInvitePeek != nil ? Copy.Auth.joinInviter(app.pendingInvitePeek!.inviterName) : "Create account")
              : (app.pendingInvitePeek != nil ? "Sign in & join" : "Sign in"),
            variant: .primary,
            loading: busy,
            disabled: busy
          ) {
            busy = true
            defer { busy = false }
            if mode == .signIn {
              await app.signIn(email: email, password: password)
            } else {
              await app.signUp(email: email, password: password, displayName: name)
            }
          }
          .padding(.top, 20)

          Button {
            mode = mode == .signIn ? .signUp : .signIn
            app.errorMessage = nil
          } label: {
            Text(mode == .signIn ? "Don’t have an account? " : "Already have an account? ")
              .foregroundStyle(Theme.inkFaint)
              + Text(mode == .signIn ? "Sign up" : "Sign in")
              .foregroundStyle(Theme.roseInk)
              .fontWeight(.semibold)
          }
          .buttonStyle(.plain)
          .font(.footnote)
          .padding(.top, 18)

          if let err = app.errorMessage {
            Text(err)
              .font(.footnote)
              .foregroundStyle(Theme.roseInk)
              .padding(.top, 8)
          }
        }
        .padding(24)
      }
    }
  }
}
