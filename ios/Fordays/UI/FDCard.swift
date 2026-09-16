import SwiftUI

enum FDCardVariant {
  case warm
  case paper
  case sunk
  case roseWash
  case sageWash
}

enum FDCardPadding {
  case none
  case sm
  case md
  case lg

  var insets: CGFloat {
    switch self {
    case .none: return 0
    case .sm: return 12
    case .md: return 16
    case .lg: return 20
    }
  }
}

struct FDCard<Content: View>: View {
  var variant: FDCardVariant = .warm
  var padding: FDCardPadding = .md
  @ViewBuilder var content: () -> Content

  private var backgroundColor: Color {
    switch variant {
    case .warm: return Theme.paperWarm
    case .paper: return Theme.paper
    case .sunk: return Theme.fillQuaternary
    case .roseWash: return Theme.roseWash
    case .sageWash: return Theme.sageWash
    }
  }

  var body: some View {
    content()
      .padding(padding.insets)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
          .stroke(variant == .paper ? Theme.rule : Color.clear, lineWidth: 1)
      )
      .shadow(
        color: variant == .warm ? Color.black.opacity(0.04) : Color.clear,
        radius: 10,
        x: 0,
        y: 4
      )
  }
}
