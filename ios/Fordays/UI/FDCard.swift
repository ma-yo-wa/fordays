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
    case .none: return Theme.Spacing.none
    case .sm: return Theme.Spacing.md
    case .md: return Theme.Spacing.base
    case .lg: return Theme.Spacing.lg
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
          .stroke(variant == .paper ? Theme.rule : Color.clear, lineWidth: Theme.TouchTarget.borderWidth)
      )
      .shadow(
        color: variant == .warm ? Theme.fillQuaternary : Color.clear,
        radius: Theme.Shadow.cardRadius,
        x: Theme.Spacing.none,
        y: Theme.Shadow.cardY
      )
  }
}
