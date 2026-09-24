import SwiftUI

struct AuthView: View {
  @EnvironmentObject private var app: AppModel
  @State private var mode: Mode = .signIn
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var busy = false

  enum Mode { case signIn, signUp, forgot, sent }

  var body: some View {
    ZStack {
      Theme.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.none) {
          Text(Theme.brandName)
            .font(.fdBrand)
            .foregroundStyle(Theme.ink)
            .padding(.top, Theme.Spacing.s48)
            .padding(.bottom, Theme.Spacing.sm)

          switch mode {
          case .sent:
            sentBody
          case .forgot:
            forgotBody
          case .signIn, .signUp:
            credentialsBody
          }

          if let err = app.errorMessage {
            Text(err)
              .font(.footnote)
              .foregroundStyle(Theme.roseInk)
              .padding(.top, Theme.Spacing.sm)
          }
        }
        .padding(Theme.Spacing.xl)
      }
    }
  }

  private var credentialsBody: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      lead(leadCopy)

      if mode == .signUp {
        FDTextField(label: "Your name", placeholder: "Aline", text: $name)
          .textContentType(.name)
          .textInputAutocapitalization(.words)
          .submitLabel(.next)
          .padding(.bottom, Theme.Spacing.md)
      }

      emailField
        .submitLabel(.next)
        .padding(.bottom, Theme.Spacing.md)

      FDTextField(label: "Password", placeholder: "••••••••", text: $password, isSecure: true)
        .textContentType(mode == .signUp ? .newPassword : .password)
        .submitLabel(.go)
        .onSubmit { Task { await submit() } }

      FDButton(
        submitTitle,
        variant: .primary,
        loading: busy,
        disabled: busy
      ) {
        await submit()
      }
      .padding(.top, Theme.Spacing.lg)

      if mode == .signIn {
        textLink("Forgot password?") { switchMode(.forgot) }
          .padding(.top, Theme.Spacing.md)
      }

      Button {
        switchMode(mode == .signIn ? .signUp : .signIn)
      } label: {
        Text(mode == .signIn ? "Don’t have an account? " : "Already have an account? ")
          .foregroundStyle(Theme.inkFaint)
          + Text(mode == .signIn ? "Sign up" : "Sign in")
          .foregroundStyle(Theme.roseInk)
          .fontWeight(.semibold)
      }
      .buttonStyle(.plain)
      .font(.footnote)
      .padding(.top, Theme.Spacing.s18)
    }
  }

  private var forgotBody: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      lead("We’ll email a link to reset your password")

      emailField
        .submitLabel(.send)
        .onSubmit { Task { await sendReset() } }

      FDButton("Send reset link", variant: .primary, loading: busy, disabled: busy) {
        await sendReset()
      }
      .padding(.top, Theme.Spacing.lg)

      textLink("Back to sign in") { switchMode(.signIn) }
        .padding(.top, Theme.Spacing.s18)
    }
  }

  private var sentBody: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.none) {
      lead("Check your email for a reset link — open it on this phone")
      FDButton("Back to sign in", variant: .secondary) { switchMode(.signIn) }
    }
  }

  private var emailField: some View {
    FDTextField(label: "Email", placeholder: "you@example.com", text: $email)
      .textContentType(.emailAddress)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .keyboardType(.emailAddress)
  }

  private func lead(_ text: String) -> some View {
    Text(text)
      .font(.title3.weight(.medium))
      .foregroundStyle(Theme.inkSoft)
      .padding(.bottom, Theme.Spacing.lg)
  }

  private func textLink(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.inkSoft)
    }
    .buttonStyle(.plain)
  }

  private var leadCopy: String {
    guard let peek = app.pendingInvitePeek else { return "Plans, Bucket lists and Memories" }
    let named = peek.spaceName.flatMap { $0.isEmpty ? nil : $0 }
    if mode == .signUp {
      if let named { return Copy.Auth.invitedToNamedOrb(inviter: peek.inviterName, orb: named) }
      return Copy.Auth.invitedToOrb(peek.inviterName)
    }
    if let named { return "\(peek.inviterName) invited you to “\(named)” — sign in to join" }
    return "\(peek.inviterName) invited you — sign in to join"
  }

  private var submitTitle: String {
    if let peek = app.pendingInvitePeek {
      return mode == .signUp ? Copy.Auth.joinInviter(peek.inviterName) : "Sign in & join"
    }
    return mode == .signUp ? "Create account" : "Sign in"
  }

  private func switchMode(_ next: Mode) {
    mode = next
    app.errorMessage = nil
  }

  /// Same checks as the PWA, before anything goes to the server.
  private func submit() async {
    guard !busy else { return }
    let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty || !clean.contains("@") {
      app.errorMessage = "That doesn’t look like an email"
      return
    }
    if mode == .signUp && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      app.errorMessage = "Add your name — it shows on your avatar"
      return
    }
    if password.count < 6 {
      app.errorMessage = "Password needs at least 6 characters"
      return
    }
    busy = true
    defer { busy = false }
    if mode == .signIn {
      await app.signIn(email: clean, password: password)
    } else {
      await app.signUp(email: clean, password: password, displayName: name)
    }
  }

  private func sendReset() async {
    guard !busy else { return }
    let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty || !clean.contains("@") {
      app.errorMessage = "That doesn’t look like an email"
      return
    }
    busy = true
    defer { busy = false }
    if await app.requestPasswordReset(email: clean) {
      mode = .sent
    }
  }
}
