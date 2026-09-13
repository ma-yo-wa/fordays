import SwiftUI

/// Same invite sheet as the PWA `InviteShare`.
struct InviteShareView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var first = ""
  @State private var busy = false

  private var code: String { app.space?.inviteCode ?? "" }
  private var link: String { "https://fordays.app/?invite=\(code)" }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("Invite someone")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Theme.ink)
          .padding(.bottom, 8)

        Text("They get their own login, then land in this Orb with you. Send them the invite link.")
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.bottom, 16)

        HStack(spacing: 4) {
          Text("One thing you want to do")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.inkFaint)
          Text("— optional, but nicer than an empty Orb")
            .font(.caption)
            .foregroundStyle(Theme.inkFaint)
        }
        .padding(.bottom, 8)

        TextField("Kayak the Grand River", text: $first)
          .padding(12)
          .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        HStack(spacing: 10) {
          Button("Later") { dismiss() }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

          Button {
            Task { await share() }
          } label: {
            Text(busy ? "…" : "Share invite")
              .font(.body.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Theme.rose, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .disabled(busy)
        }
        .padding(.top, 20)
      }
      .padding(20)
    }
    .background(Theme.paper.ignoresSafeArea())
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }

  private func share() async {
    busy = true
    let idea = first.trimmingCharacters(in: .whitespacesAndNewlines)
    if !idea.isEmpty {
      await app.createActivity(title: idea)
    }
    busy = false

    let text = idea.isEmpty
      ? "Join my Orb on Fordays: \(link)"
      : "I added “\(idea)” to an Orb for us — join here: \(link)"
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
