import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var app: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showInvite = false
  @State private var leaveAsk = false
  @State private var removeId: String?

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(app.space?.myName ?? "—")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.ink)
        } header: {
          Text("You")
        }

        Section {
          ForEach(app.spaces.isEmpty ? Array(app.space.map { [$0] } ?? []) : app.spaces, id: \.id) { sp in
            Button {
              Task { await app.switchToSpace(sp.id) }
            } label: {
              HStack {
                Text(sp.peopleLabel)
                  .foregroundStyle(Theme.ink)
                Spacer()
                if sp.id == app.space?.id {
                  Text("✓").foregroundStyle(Theme.inkFaint)
                } else {
                  Text("›").foregroundStyle(Theme.inkFaint)
                }
              }
            }
            .disabled(sp.id == app.space?.id)
          }
          Button {
            Task { await app.addSpace() }
          } label: {
            HStack {
              Text("New orb").foregroundStyle(Theme.ink)
              Spacer()
              Text("›").foregroundStyle(Theme.inkFaint)
            }
          }
          if let space = app.space, !space.frozen {
            Button {
              showInvite = true
            } label: {
              HStack {
                Text("Invite to this orb").foregroundStyle(Theme.ink)
                Spacer()
                Text("›").foregroundStyle(Theme.inkFaint)
              }
            }
          }
        } header: {
          Text("Orbs")
        } footer: {
          Text("An orb is your planning group — solo, two, or a few")
        }

        if let space = app.space {
          Section {
            if space.frozen {
              Text("This is a copy from when you left — you can look, not change")
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)
            }
            ForEach(space.members, id: \.id) { member in
              Text(member.id == space.myId ? "\(member.name) (you)" : member.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            }
            if !space.frozen, space.myRole == "admin", space.members.count >= 3 {
              ForEach(space.members.filter { $0.id != space.myId }, id: \.id) { member in
                if removeId == member.id {
                  Text("Remove \(member.name)? They get a copy of what’s already here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkFaint)
                  Button("Keep them") { removeId = nil }
                  Button("Remove \(member.name)", role: .destructive) {
                    Task {
                      await app.removeMember(userId: member.id)
                      removeId = nil
                    }
                  }
                } else {
                  Button("Remove \(member.name)", role: .destructive) {
                    removeId = member.id
                  }
                }
              }
            }
            if !space.frozen {
              if leaveAsk {
                Text(
                  space.members.count <= 1
                    ? "You’re the last person — this deletes the orb."
                    : "They keep the live orb. You get a frozen copy of what’s already here."
                )
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)
                Button("Stay") { leaveAsk = false }
                Button("Leave this orb", role: .destructive) {
                  Task {
                    await app.leaveCurrentSpace()
                    leaveAsk = false
                  }
                }
              } else {
                Button("Leave this orb", role: .destructive) {
                  leaveAsk = true
                }
              }
            }
          } header: {
            Text("This orb")
          }
        }

        Section {
          Text("Connect Google Calendar on the web for now.")
            .foregroundStyle(Theme.inkSoft)
          Link("Open web", destination: URL(string: "https://fordays.app/")!)
        } header: {
          Text("Calendars")
        }

        Section {
          Button("Sign out", role: .destructive) {
            Task {
              await app.signOut()
              dismiss()
            }
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .sheet(isPresented: $showInvite) {
      InviteShareView()
        .environmentObject(app)
    }
  }
}
