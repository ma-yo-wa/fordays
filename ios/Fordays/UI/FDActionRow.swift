import SwiftUI

struct FDActionRow: View {
  let title: String
  var systemImage: String? = nil
  var destructive: Bool = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.fdBody.weight(.semibold))
            .frame(width: 22)
        }
        Text(title)
          .font(.fdBody.weight(.medium))
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
