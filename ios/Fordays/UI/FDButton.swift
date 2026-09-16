import SwiftUI

enum FDButtonVariant {
  case primary
  case secondary
  case destructive
  case ghost
}

enum FDButtonSize {
  case md
  case sm

  var minHeight: CGFloat {
    switch self {
    case .md: return 50
    case .sm: return 36
    }
  }

  var font: Font {
    switch self {
    case .md: return .fdHeadline
    case .sm: return .fdSubhead.weight(.semibold)
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .md: return 20
    case .sm: return 14
    }
  }
}

struct FDScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.85 : 1.0)
      .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

struct FDButton: View {
  let title: String
  var variant: FDButtonVariant = .primary
  var size: FDButtonSize = .md
  var fullWidth: Bool = true
  var loading: Bool = false
  var disabled: Bool = false
  var action: () -> Void

  init(
    _ title: String,
    variant: FDButtonVariant = .primary,
    size: FDButtonSize = .md,
    fullWidth: Bool = true,
    loading: Bool = false,
    disabled: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.variant = variant
    self.size = size
    self.fullWidth = fullWidth
    self.loading = loading
    self.disabled = disabled
    self.action = action
  }

  init(
    _ title: String,
    variant: FDButtonVariant = .primary,
    size: FDButtonSize = .md,
    fullWidth: Bool = true,
    loading: Bool = false,
    disabled: Bool = false,
    asyncAction: @escaping () async -> Void
  ) {
    self.title = title
    self.variant = variant
    self.size = size
    self.fullWidth = fullWidth
    self.loading = loading
    self.disabled = disabled
    self.action = {
      Task { await asyncAction() }
    }
  }

  private var foregroundColor: Color {
    switch variant {
    case .primary: return Theme.paper
    case .secondary: return Theme.ink2
    case .destructive: return Theme.roseInk
    case .ghost: return Theme.inkSoft
    }
  }

  private var backgroundColor: Color {
    switch variant {
    case .primary: return Theme.ink
    case .secondary: return Theme.fillTertiary
    case .destructive: return Theme.roseWash
    case .ghost: return Color.clear
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if loading {
          ProgressView()
            .tint(foregroundColor)
            .scaleEffect(0.85)
        } else {
          Text(title)
            .font(size.font)
        }
      }
      .foregroundStyle(foregroundColor)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(minHeight: size.minHeight)
      .padding(.horizontal, size.horizontalPadding)
      .background(backgroundColor, in: Capsule())
    }
    .buttonStyle(FDScaleButtonStyle())
    .disabled(disabled || loading)
    .opacity((disabled || loading) ? 0.38 : 1.0)
  }
}
