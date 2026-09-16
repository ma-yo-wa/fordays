import SwiftUI

enum FDPillVariant {
  case neutral
  case rose
  case sage
  case solid
  case rule
}

enum FDPillSize {
  case sm
  case md

  var minHeight: CGFloat {
    switch self {
    case .sm: return Theme.Spacing.xl
    case .md: return Theme.TouchTarget.avatarMd
    }
  }

  var font: Font {
    switch self {
    case .sm: return .fdFootnote
    case .md: return .fdSubhead.weight(.medium)
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .sm: return Theme.Spacing.s9
    case .md: return Theme.Spacing.s13
    }
  }
}

struct FDPill: View {
  let title: String
  var variant: FDPillVariant = .neutral
  var size: FDPillSize = .md
  var systemImage: String? = nil
  var action: (() -> Void)? = nil

  private var foregroundColor: Color {
    switch variant {
    case .neutral: return Theme.ink2
    case .rose: return Theme.roseInk
    case .sage: return Theme.sageInk
    case .solid: return Theme.paper
    case .rule: return Theme.inkSoft
    }
  }

  private var backgroundColor: Color {
    switch variant {
    case .neutral: return Theme.fillTertiary
    case .rose: return Theme.roseWash
    case .sage: return Theme.sageWash
    case .solid: return Theme.ink
    case .rule: return Color.clear
    }
  }

  var body: some View {
    let content = HStack(spacing: Theme.Spacing.s5) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(size.font)
      }
      Text(title)
        .font(size.font)
    }
    .foregroundStyle(foregroundColor)
    .padding(.horizontal, size.horizontalPadding)
    .frame(minHeight: size.minHeight)
    .background(backgroundColor, in: Capsule())
    .overlay(
      Capsule()
        .stroke(variant == .rule ? Theme.rule : Color.clear, lineWidth: Theme.TouchTarget.borderWidth)
    )

    if let action {
      Button(action: action) {
        content
      }
      .buttonStyle(FDScaleButtonStyle())
    } else {
      content
    }
  }
}
