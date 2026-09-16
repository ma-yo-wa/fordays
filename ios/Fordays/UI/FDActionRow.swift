import SwiftUI

struct FDActionRow: View {
  let title: String
  var note: String? = nil
  var systemImage: String? = nil
  var glyph: String? = nil
  var destructive: Bool = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.fdBody.weight(.semibold))
            .frame(width: 22)
        } else if let glyph {
          Text(glyph)
            .font(.fdTitle3.weight(.medium))
            .frame(width: 22)
        }
        VStack(alignment: .leading, spacing: 2) {
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
      .padding(.vertical, 14)
      .padding(.horizontal, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(FDScaleButtonStyle())
  }
}
