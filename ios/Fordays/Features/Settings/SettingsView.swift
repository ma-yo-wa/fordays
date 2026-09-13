import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showInvite = false
  @State private var leaveAsk = false
  @State private var removeId: String?
  @State private var spaceBusy = false

  private var orbs: [SpaceInfo] {
    if !app.spaces.isEmpty { return app.spaces }
    if let one = app.space { return [one] }
    return []
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          if let space = app.space {
            profileSection(space: space)
            orbsSection
            peopleSection(space: space)
            orbActionsSection(space: space)
          }

          calendarsSection

          if app.authPhase == .signedIn {
            signOutSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
      }
      .background(Theme.paper.ignoresSafeArea())
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .onChange(of: app.space?.id) { _, _ in
        leaveAsk = false
        removeId = nil
      }
    }
    .sheet(isPresented: $showInvite) {
      InviteShareView()
        .environmentObject(app)
    }
  }

  private func profileSection(space: SpaceInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Your profile")
      HStack(spacing: 12) {
        face(space.myName, mine: true, size: 34)
        Text(space.myName)
          .font(.body)
          .foregroundStyle(Theme.ink)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  private var orbsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Your Orbs")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(orbs, id: \.id) { orb in
            orbCard(orb)
          }
          createOrbCard
        }
        .padding(.horizontal, 1)
        .padding(.vertical, 2)
      }
    }
  }

  private func orbCard(_ orb: SpaceInfo) -> some View {
    let active = orb.id == app.space?.id
    return Button {
      switchOrb(orb.id)
    } label: {
      VStack(alignment: .leading, spacing: 7) {
        Text(orb.peopleLabel)
          .font(.headline)
          .foregroundStyle(Theme.ink)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        Text(orbSizeLabel(orb))
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
      }
      .frame(width: 168, height: 116, alignment: .topLeading)
      .padding(12)
      .background {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Theme.ink.opacity(0.05))
          .overlay {
            if active {
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                  LinearGradient(
                    colors: [Theme.rose.opacity(0.18), Theme.sage.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            }
          }
      }
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy || active)
  }

  private var createOrbCard: some View {
    Button {
      createOrb()
    } label: {
      VStack(spacing: 7) {
        Text("+")
          .font(.title3.weight(.semibold))
          .frame(width: 34, height: 34)
          .background(Theme.ink.opacity(0.08), in: Circle())
          .foregroundStyle(Theme.ink)

        Text("Create Orb")
          .font(.headline)
          .foregroundStyle(Theme.ink)

        Text("Start solo, or invite")
          .font(.footnote)
          .foregroundStyle(Theme.inkSoft)
      }
      .frame(width: 168, height: 116)
      .padding(12)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func peopleSection(space: SpaceInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("People in this Orb")
      VStack(alignment: .leading, spacing: 8) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(space.members, id: \.id) { member in
              VStack(spacing: 4) {
                face(member.name, mine: member.id == space.myId, size: 44)
                Text(member.name)
                  .font(.caption)
                  .foregroundStyle(Theme.ink)
                  .lineLimit(1)
                  .frame(width: 72)
                Text(member.id == space.myId ? "You" : " ")
                  .font(.caption2)
                  .foregroundStyle(Theme.inkFaint)
                  .frame(height: 13)
              }
              .frame(width: 72)
            }

            if !space.frozen {
              Button {
                showInvite = true
              } label: {
                VStack(spacing: 4) {
                  Text("+")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Theme.ink.opacity(0.08), in: Circle())
                    .foregroundStyle(Theme.ink)
                  Text("Invite")
                    .font(.caption)
                    .foregroundStyle(Theme.ink)
                  Text("More")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .frame(height: 13)
                }
                .frame(width: 72)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 2)
          .padding(.bottom, 4)
        }
      }
      .padding(10)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      Text("An Orb is your personal or shared capsule to plan, dream, and look back.")
        .font(.footnote)
        .foregroundStyle(Theme.inkFaint)
        .padding(.horizontal, 4)

      if space.frozen {
        Text("This is a copy from when you left — you can look, not change")
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, 4)
      }
    }
  }

  @ViewBuilder
  private func orbActionsSection(space: SpaceInfo) -> some View {
    let soloOrb = space.members.count <= 1
    let leaveLabel = soloOrb ? "Delete this Orb" : "Leave this Orb"
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Orb actions")

      if !space.frozen, space.myRole == "admin", space.members.count >= 3 {
        ForEach(space.members.filter { $0.id != space.myId }, id: \.id) { member in
          if removeId == member.id {
            VStack(alignment: .leading, spacing: 10) {
              Text("Remove \(member.name)? They get a copy of what was already here. This Orb stays live for everyone else.")
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)

              HStack(spacing: 10) {
                quietButton("Keep them") {
                  removeId = nil
                }
                dangerButton("Remove \(member.name)") {
                  removeMember(member.id)
                }
              }
            }
            .padding(12)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          } else {
            Button("Remove \(member.name)") {
              removeId = member.id
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseInk)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .disabled(spaceBusy)
          }
        }
      }

      if !space.frozen {
        if leaveAsk {
          VStack(alignment: .leading, spacing: 10) {
            Text(
              soloOrb
                ? "Delete this Orb? You’ll keep a frozen copy so nothing here is lost."
                : "They keep the live Orb. You get a frozen copy of what’s already here."
            )
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 10) {
              quietButton("Stay") {
                leaveAsk = false
              }
              dangerButton(leaveLabel) {
                leaveOrb()
              }
            }
          }
          .padding(12)
          .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
          Button(leaveLabel) {
            leaveAsk = true
          }
          .buttonStyle(.plain)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
          .padding(.horizontal, 4)
          .padding(.top, 4)
          .disabled(spaceBusy)
        }
      }
    }
  }

  private var calendarsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("External calendars")
      VStack(alignment: .leading, spacing: 10) {
        Text("Connect Google Calendar on the web for now.")
          .font(.subheadline)
          .foregroundStyle(Theme.inkSoft)
        Link("Open web", destination: URL(string: "https://fordays.app/")!)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
      }
      .padding(12)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  private var signOutSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Session")
      dangerButton("Sign out") {
        Task {
          await app.signOut()
          dismiss()
        }
      }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(Theme.inkFaint)
  }

  private func quietButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func dangerButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.roseInk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(spaceBusy)
  }

  private func face(_ name: String, mine: Bool, size: CGFloat) -> some View {
    Text(initial(name))
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(mine ? Theme.faceSage : Theme.faceRose, in: Circle())
  }

  private func switchOrb(_ id: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.switchToSpace(id)
      spaceBusy = false
    }
  }

  private func createOrb() {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.addSpace()
      spaceBusy = false
    }
  }

  private func removeMember(_ userId: String) {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.removeMember(userId: userId)
      removeId = nil
      spaceBusy = false
    }
  }

  private func leaveOrb() {
    guard !spaceBusy else { return }
    spaceBusy = true
    Task {
      await app.leaveCurrentSpace()
      leaveAsk = false
      spaceBusy = false
    }
  }

  private func initial(_ name: String) -> String {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(clean.prefix(1)).uppercased()
  }

  private func orbSizeLabel(_ orb: SpaceInfo) -> String {
    let n = orb.members.isEmpty ? (orb.partner2Id == nil ? 1 : 2) : orb.members.count
    return n <= 1 ? "1 person" : "\(n) people"
  }
}
