import SwiftUI

struct FDActionRow: View {
  let title: String
  var note: String? = nil
  var systemImage: String? = nil
  var glyph: String? = nil
  var icon: ActionGlyph? = nil
  var destructive: Bool = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Theme.Spacing.md) {
        if let icon {
          // Warm grey icon beside ink text, like the tab bar.
          ActionGlyphIcon(glyph: icon)
            .foregroundStyle(destructive ? Theme.roseInk : Theme.inkSoft)
        } else if let systemImage {
          Image(systemName: systemImage)
            .font(.fdBody)
            .frame(width: Theme.Spacing.s22)
        } else if let glyph {
          Text(glyph)
            .font(.fdTitle3.weight(.medium))
            .frame(width: Theme.Spacing.s22)
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
          Text(title)
            .font(.fdBody.weight(.medium))
          if let note {
            Text(note)
              .font(.fdFootnote)
              .foregroundStyle(Theme.inkFaint)
          }
        }
        Spacer()
      }
      .foregroundStyle(destructive ? Theme.roseInk : Theme.ink)
      .padding(.vertical, Theme.Spacing.row)
      .padding(.horizontal, Theme.Spacing.row)
      .contentShape(Rectangle())
    }
    .buttonStyle(FDScaleButtonStyle())
  }
}
