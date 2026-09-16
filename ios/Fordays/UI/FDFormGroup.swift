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
  var action: (() -> Void)? = nil
  @ViewBuilder var rightContent: () -> RightContent

  init(
    label: String,
    note: String? = nil,
    action: (() -> Void)? = nil,
    @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() }
  ) {
    self.label = label
    self.note = note
    self.action = action
    self.rightContent = rightContent
  }

  var body: some View {
    let rowContent = HStack(spacing: Theme.Spacing.row) {
      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        Text(label)
          .font(.fdBody)
          .foregroundStyle(Theme.ink)
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
