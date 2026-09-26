import SwiftUI

struct FDFormGroup<Content: View>: View {
  var header: String? = nil
  var footer: String? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
      if let header {
        Text(header)
          .font(.fdFootnote.weight(.semibold))
          .foregroundStyle(Theme.inkSoft)
          .padding(.horizontal, Theme.Spacing.xs)
      }
      VStack(spacing: Theme.Spacing.none) {
        content()
      }
      .background(Theme.fillQuaternary)
      .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
      if let footer {
        Text(footer)
          .font(.fdFootnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.horizontal, Theme.Spacing.xs)
      }
    }
  }
}

struct FDFormRow<RightContent: View>: View {
  let label: String
  var note: String? = nil
  var glyph: FormGlyph? = nil
  var systemImage: String? = nil
  var destructive: Bool = false
  var action: (() -> Void)? = nil
  @ViewBuilder var rightContent: () -> RightContent

  init(
    label: String,
    note: String? = nil,
    glyph: FormGlyph? = nil,
    systemImage: String? = nil,
    destructive: Bool = false,
    @ViewBuilder rightContent: @escaping () -> RightContent
  ) {
    self.label = label
    self.note = note
    self.glyph = glyph
    self.systemImage = systemImage
    self.destructive = destructive
    self.action = nil
    self.rightContent = rightContent
  }

  init(
    label: String,
    note: String? = nil,
    glyph: FormGlyph? = nil,
    systemImage: String? = nil,
    destructive: Bool = false,
    action: (() -> Void)? = nil,
    @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() }
  ) {
    self.label = label
    self.note = note
    self.glyph = glyph
    self.systemImage = systemImage
    self.destructive = destructive
    self.action = action
    self.rightContent = rightContent
  }

  var body: some View {
    let rowContent = HStack(spacing: Theme.Spacing.md) {
      if let glyph {
        FormGlyphIcon(glyph: glyph, destructive: destructive)
      } else if let systemImage {
        Image(systemName: systemImage)
          .font(.fdBody)
          .foregroundStyle(destructive ? Theme.roseInk : Theme.inkSoft)
          .frame(width: Theme.Spacing.lg)
      }
      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        Text(label)
          .font(.fdBody)
          .foregroundStyle(destructive ? Theme.roseInk : Theme.ink)
        if let note {
          Text(note)
            .font(.fdFootnote)
            .foregroundStyle(Theme.inkFaint)
        }
      }
      Spacer()
      rightContent()
    }
    .padding(.horizontal, Theme.Spacing.row)
    .padding(.vertical, Theme.Spacing.s10)
    .frame(minHeight: Theme.TouchTarget.formRow)
    .contentShape(Rectangle())

    if let action {
      Button(action: action) {
        rowContent
      }
      .buttonStyle(FDScaleButtonStyle())
    } else {
      rowContent
    }
  }
}
