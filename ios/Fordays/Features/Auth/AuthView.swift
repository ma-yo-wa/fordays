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
            fieldLabel("Your name")
            field("Aline", text: $name)
          }

          fieldLabel("Email")
          field("you@example.com", text: $email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

          fieldLabel("Password")
          SecureField("••••••••", text: $password)
            .padding(14)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

          Button {
            Task {
              busy = true
              defer { busy = false }
              if mode == .signIn {
                await app.signIn(email: email, password: password)
              } else {
                await app.signUp(email: email, password: password, displayName: name)
              }
            }
          } label: {
            HStack {
              Spacer()
              if busy { ProgressView().tint(.white) }
              else {
                Text(
                  mode == .signUp
                    ? (app.pendingInvitePeek != nil ? Copy.Auth.joinInviter(app.pendingInvitePeek!.inviterName) : "Create account")
                    : (app.pendingInvitePeek != nil ? "Sign in & join" : "Sign in")
                )
                .font(.headline)
                .foregroundStyle(.white)
              }
              Spacer()
            }
            .padding(.vertical, 14)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .disabled(busy)
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

  private func fieldLabel(_ text: String) -> some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Theme.inkFaint)
      .padding(.top, 16)
      .padding(.bottom, 8)
  }

  private func field(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .padding(14)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
