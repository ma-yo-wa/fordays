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
    case .md: return Theme.TouchTarget.buttonMd
    case .sm: return Theme.TouchTarget.control
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
    case .md: return Theme.Spacing.lg
    case .sm: return Theme.Spacing.row
    }
  }
}

struct FDScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? Theme.Motion.pressScale : 1.0)
      .opacity(configuration.isPressed ? Theme.Motion.spinner : 1.0)
      .animation(.easeOut(duration: Theme.Motion.pressDuration), value: configuration.isPressed)
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
      HStack(spacing: Theme.Spacing.sm) {
        if loading {
          ProgressView()
            .tint(foregroundColor)
            .scaleEffect(Theme.Motion.spinner)
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
    .opacity((disabled || loading) ? Theme.Motion.disabledOpacity : 1.0)
  }
}
