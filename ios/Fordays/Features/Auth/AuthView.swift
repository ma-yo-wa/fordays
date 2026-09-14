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

          Text("Someday, plans, and memories")
            .font(.title3.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.bottom, 20)

          HStack(spacing: 2) {
            modeTab("Sign in", selected: mode == .signIn) {
              mode = .signIn
              app.errorMessage = nil
            }
            modeTab("Create account", selected: mode == .signUp) {
              mode = .signUp
              app.errorMessage = nil
            }
          }
          .padding(2)
          .background(Theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          .padding(.bottom, 20)

          if mode == .signUp {
            fieldLabel("Your name")
            field("Mayowa", text: $name)
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
                Text(mode == .signUp ? "Create account" : "Sign in")
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

          Text(
            mode == .signUp
              ? "Your name shows on the shared calendar."
              : "Private Orb for two — sign in on each phone."
          )
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.top, 12)

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

  private func modeTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(selected ? .semibold : .medium))
        .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
          if selected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(Theme.paper)
          }
        }
    }
    .buttonStyle(.plain)
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
