import SwiftUI

/// Sheet to join an Orb by entering an 8-character invite code or pasting an invite link.
/// Parity with PWA `InviteAccept`.
struct JoinOrbView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var input = ""
  @State private var peek: InvitePeek?
  @State private var isLookingUp = false
  @State private var errorText: String?
  @State private var isBusy = false
  @State private var lookupTask: Task<Void, Never>?

  private var cleanedCode: String {
    app.extractInviteCode(from: input)
  }

  private var canJoin: Bool {
    !isBusy && !isLookingUp && peek != nil && (peek?.isOpen == true) && cleanedCode.count >= 4
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(peek != nil ? "\(peek!.inviterName) invited you" : Copy.Invite.joinTitle)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, 8)

        Text(peek != nil ? "You’ll share this Orb with \(peek!.inviterName)." : Copy.Invite.joinSubtitle)
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.bottom, 16)

        Text(Copy.Invite.codeOrLink)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.inkFaint)
          .padding(.bottom, 8)

        HStack(spacing: 8) {
          TextField(Copy.Invite.codePlaceholder, text: $input)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .font(.system(.body, design: .monospaced))
            .padding(12)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: input) { _, next in
              triggerLookup(for: next)
            }

          Button {
            if let paste = UIPasteboard.general.string, !paste.isEmpty {
              input = paste
            }
          } label: {
            Text(Copy.Invite.paste)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Theme.ink)
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .background(Theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
        }

        if isLookingUp {
          Text(Copy.Invite.lookingUp)
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 10)
        }

        if let peek, peek.isOpen {
          VStack(alignment: .leading, spacing: 4) {
            Text("\(peek.inviterName) invited you to \(peek.spaceName.map { "“\($0)”" } ?? "their Orb")")
              .font(.headline)
              .foregroundStyle(Theme.ink)

            Text("You’ll be added to this Orb and keep your existing Orbs.")
              .font(.footnote)
              .foregroundStyle(Theme.inkSoft)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(Theme.sageWash)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(Theme.faceSage.opacity(0.3), lineWidth: 1)
          )
          .padding(.top, 14)
        }

        if let errorText {
          Text(errorText)
            .font(.footnote)
            .foregroundStyle(Theme.roseInk)
            .padding(.top, 10)
        }

        HStack(spacing: 10) {
          Button(Copy.Invite.notNow) { dismiss() }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

          Button {
            Task { await join() }
          } label: {
            Text(isBusy ? Copy.Invite.joining : Copy.Invite.joinAction)
              .font(.body.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(canJoin ? Theme.rose : Theme.ink.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .disabled(!canJoin)
        }
        .padding(.top, 24)
      }
      .padding(20)
    }
    .background(Theme.paper.ignoresSafeArea())
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func triggerLookup(for string: String) {
    lookupTask?.cancel()
    let code = app.extractInviteCode(from: string)
    guard code.count >= 4 else {
      peek = nil
      errorText = nil
      isLookingUp = false
      return
    }

    isLookingUp = true
    errorText = nil

    lookupTask = Task {
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }

      do {
        let result = try await app.peekInvite(code)
        guard !Task.isCancelled else { return }
        isLookingUp = false
        if let result {
          peek = result
          if !result.isOpen {
            errorText = "This Orb is no longer accepting new members."
          }
        } else {
          peek = nil
          errorText = Copy.Invite.invalidCode
        }
      } catch {
        guard !Task.isCancelled else { return }
        isLookingUp = false
        peek = nil
        errorText = Copy.Invite.invalidCode
      }
    }
  }

  private func join() async {
    guard canJoin else { return }
    isBusy = true
    errorText = nil
    do {
      try await app.joinInvite(cleanedCode)
      dismiss()
    } catch {
      isBusy = false
      errorText = error.localizedDescription
    }
  }
}
