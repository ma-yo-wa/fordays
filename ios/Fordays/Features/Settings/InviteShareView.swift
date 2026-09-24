import SwiftUI

/// Same invite sheet as the PWA `InviteShare`.
struct InviteShareView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var first = ""
  @State private var busy = false

  private var code: String { app.space?.inviteCode ?? "" }
  private var link: String { "\(AppConfig.webOrigin)/?invite=\(code)" }

  private var isPersonalOrb: Bool {
    guard let space = app.space else { return false }
    let soloOrb = space.members.count <= 1
    let soloOrbs = app.spaces.filter { !$0.frozen && $0.members.count <= 1 }
    return soloOrb && (space.isHomeSoloName() || soloOrbs.count <= 1)
  }

  var body: some View {
    if isPersonalOrb {
      Color.clear
        .onAppear { dismiss() }
    } else {
      ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.none) {
        Text(Copy.Invite.title)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, Theme.Spacing.sm)

        Text(Copy.Invite.subtitle)
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.bottom, Theme.Spacing.base)

        if !code.isEmpty {
          HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
              Text(Copy.Invite.orbCodeLabel)
                .font(.fdCaption2.weight(.medium))
                .foregroundStyle(Theme.inkFaint)
              Text(code)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(Theme.ink)
            }
            Spacer()
            FDPill(title: Copy.Invite.copyCode, variant: .neutral, size: .sm) {
              UIPasteboard.general.string = code
              app.toast = Copy.Invite.codeCopied
            }
          }
          .padding(Theme.Spacing.md)
          .background(Theme.fillQuaternary)
          .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
              .stroke(Theme.separator, lineWidth: Theme.TouchTarget.borderWidth)
          )
          .padding(.bottom, Theme.Spacing.base)
        }

        FDTextField(
          label: Copy.Invite.ideaLabel,
          hint: Copy.Invite.ideaHint,
          placeholder: "Kayak the Grand River",
          text: $first
        )

        HStack(spacing: Theme.Spacing.s10) {
          FDButton(Copy.Invite.notNow, variant: .secondary) { dismiss() }
          FDButton(
            Copy.Invite.shareInvite,
            variant: .primary,
            loading: busy,
            disabled: busy
          ) {
            await share()
          }
        }
        .padding(.top, Theme.Spacing.lg)
      }
      .padding(Theme.Spacing.lg)
    }
      .background(Theme.paper.ignoresSafeArea())
      .presentationBackground(Theme.paper)
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
  }

  private func share() async {
    busy = true
    let idea = first.trimmingCharacters(in: .whitespacesAndNewlines)
    if !idea.isEmpty {
      await app.createActivity(title: idea)
    }
    busy = false

    let text = idea.isEmpty
      ? "\(Copy.Invite.shareSolo(link: link)) (or code: \(code))"
      : "\(Copy.Invite.shareWithIdea(idea: idea, link: link)) (code: \(code))"
    UIPasteboard.general.string = text

    presentShare(text: text)
  }

  @MainActor
  private func presentShare(text: String) {
    guard let windowScene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
      let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      app.toast = "Invite link copied"
      dismiss()
      return
    }

    var top = root
    while let next = top.presentedViewController, !next.isBeingDismissed {
      top = next
    }

    let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    if let popover = vc.popoverPresentationController {
      popover.sourceView = top.view
      popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }

    vc.completionWithItemsHandler = { _, completed, _, _ in
      if completed {
        app.toast = "Invite shared"
      }
      dismiss()
    }

    top.present(vc, animated: true)
  }
}
