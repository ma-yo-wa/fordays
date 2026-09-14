import SwiftUI

struct OrbSetupView: View {
  @EnvironmentObject private var app: AppModel
  @State private var withPeople = false
  @State private var name = ""
  @State private var busy = false

  private var placeholder: String {
    withPeople ? Copy.Orbs.crewPlaceholder : Copy.Orbs.personalPlaceholder
  }

  var body: some View {
    ZStack {
      Theme.paper.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(Copy.Orbs.setupTitle)
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.top, 48)
            .padding(.bottom, 8)

          Text(Copy.Orbs.setupLead)
            .font(.title3.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.bottom, 20)

          HStack(spacing: 8) {
            kindTab(Copy.Orbs.justYou, selected: !withPeople) {
              withPeople = false
            }
            kindTab(Copy.Orbs.withPeople, selected: withPeople) {
              withPeople = true
            }
          }

          Text(Copy.Orbs.orbName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 20)
            .padding(.bottom, 8)

          TextField(placeholder, text: $name)
            .padding(14)
            .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

          Button {
            Task {
              busy = true
              defer { busy = false }
              await app.completeFirstOrb(name: name, withPeople: withPeople)
            }
          } label: {
            HStack {
              Spacer()
              if busy { ProgressView().tint(.white) }
              else {
                Text(Copy.Orbs.continueAction)
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
        }
        .padding(24)
      }
    }
  }

  private func kindTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(selected ? .semibold : .medium))
        .foregroundStyle(selected ? Theme.ink : Theme.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Theme.paper : Theme.ink.opacity(0.08))
            .shadow(color: selected ? Theme.ink.opacity(0.14) : .clear, radius: selected ? 2 : 0, y: 1)
        }
    }
    .buttonStyle(.plain)
  }
}
