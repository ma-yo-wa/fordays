import SwiftUI

struct FDFormGroup<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      content()
    }
    .background(Theme.fillQuaternary)
    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
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
    let rowContent = HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
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
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .frame(minHeight: 46)
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
