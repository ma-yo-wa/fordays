import SwiftUI
import UIKit

/// CompactTimePicker: Native iOS compact time picker enforcing 5-minute intervals.
/// Uses `UIDatePicker` with `.preferredDatePickerStyle = .compact` and `minuteInterval = 5`.
/// Allows tapping to roll in 5-minute steps (:00, :05, :10...) or tapping to type any minute directly.
struct CompactTimePicker: UIViewRepresentable {
  @Binding var selection: Date
  var minuteInterval: Int = 5

  func makeUIView(context: Context) -> UIDatePicker {
    let picker = UIDatePicker()
    picker.datePickerMode = .time
    picker.preferredDatePickerStyle = .compact
    picker.minuteInterval = minuteInterval
    picker.tintColor = UIColor(Theme.rose)
    picker.setContentHuggingPriority(.required, for: .horizontal)
    picker.setContentCompressionResistancePriority(.required, for: .horizontal)
    picker.setContentHuggingPriority(.required, for: .vertical)
    picker.setContentCompressionResistancePriority(.required, for: .vertical)
    picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
    return picker
  }

  func updateUIView(_ uiView: UIDatePicker, context: Context) {
    if abs(uiView.date.timeIntervalSince(selection)) >= 1 {
      uiView.date = selection
    }
    uiView.minuteInterval = minuteInterval
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIDatePicker, context: Context) -> CGSize? {
    let fitted = uiView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    if fitted.width > 0, fitted.height > 0 { return fitted }
    let intrinsic = uiView.intrinsicContentSize
    guard intrinsic.width > 0, intrinsic.height > 0 else { return nil }
    return intrinsic
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  final class Coordinator: NSObject {
    var parent: CompactTimePicker
    init(_ parent: CompactTimePicker) { self.parent = parent }

    @objc func changed(_ sender: UIDatePicker) {
      parent.selection = sender.date
    }
  }
}
