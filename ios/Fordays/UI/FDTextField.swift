import SwiftUI

struct FDTextField: View {
  var label: String? = nil
  var hint: String? = nil
  var error: String? = nil
  let placeholder: String
  @Binding var text: String
  var axis: Axis = .horizontal
  var lineLimit: ClosedRange<Int>? = nil
  var clearable: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if label != nil || hint != nil {
        HStack(spacing: 6) {
          if let label {
            Text(label)
              .font(.fdFootnote.weight(.semibold))
              .foregroundStyle(Theme.inkSoft)
          }
          if let hint {
            Text(hint)
              .font(.fdFootnote)
              .foregroundStyle(Theme.inkFaint)
          }
        }
      }

      HStack(spacing: 8) {
        if axis == .vertical {
          TextField(placeholder, text: $text, axis: .vertical)
            .font(.fdBody)
            .foregroundStyle(Theme.ink)
            .lineLimit(lineLimit ?? 3...6)
        } else {
          TextField(placeholder, text: $text)
            .font(.fdBody)
            .foregroundStyle(Theme.ink)
        }

        if clearable && !text.isEmpty {
          Button {
            text = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.fdSubhead)
              .foregroundStyle(Theme.inkFaint)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(Theme.fillQuaternary)
      .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
          .stroke(error != nil ? Theme.roseInk : Color.clear, lineWidth: 1.5)
      )

      if let error, !error.isEmpty {
        Text(error)
          .font(.fdFootnote)
          .foregroundStyle(Theme.roseInk)
      }
    }
  }
}
