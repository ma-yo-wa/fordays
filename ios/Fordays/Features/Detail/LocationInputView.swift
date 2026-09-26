import SwiftUI
import MapKit

final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
  @Published var results: [MKLocalSearchCompletion] = []
  private let completer = MKLocalSearchCompleter()

  override init() {
    super.init()
    completer.delegate = self
    completer.resultTypes = [.address, .pointOfInterest]
  }

  func search(query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else {
      results = []
      return
    }
    completer.queryFragment = trimmed
  }

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    DispatchQueue.main.async {
      self.results = Array(completer.results.prefix(5))
    }
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    DispatchQueue.main.async {
      self.results = []
    }
  }
}

struct LocationInputView: View {
  @Binding var text: String
  var placeholder: String = "Where is this?"

  @StateObject private var searcher = LocationSearchCompleter()
  @FocusState private var isFocused: Bool
  @State private var showSuggestions = false

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
      HStack(spacing: Theme.Spacing.sm) {
        PinGlyph()
          .foregroundStyle(Theme.inkFaint)
          .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)

        TextField(placeholder, text: $text)
          .accessibilityLabel("Location")
          .focused($isFocused)
          .onChange(of: text) { _, next in
            if isFocused {
              searcher.search(query: next)
              showSuggestions = true
            }
          }
          .onSubmit {
            showSuggestions = false
          }

        if !text.isEmpty {
          Button {
            text = ""
            searcher.results = []
            showSuggestions = false
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, Theme.Spacing.row)
      .padding(.vertical, Theme.Spacing.md)
      .background(Theme.fillQuaternary)
      .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))

      if showSuggestions && isFocused && !searcher.results.isEmpty {
        FDCard(variant: .warm, padding: .sm) {
          VStack(alignment: .leading, spacing: Theme.Spacing.none) {
            ForEach(searcher.results, id: \.self) { item in
              Button {
                let full = item.subtitle.isEmpty ? item.title : "\(item.title), \(item.subtitle)"
                text = full
                showSuggestions = false
                isFocused = false
              } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                  Text(item.title)
                    .font(.fdSubhead.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                  if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                      .font(.fdCaption)
                      .foregroundStyle(Theme.inkFaint)
                      .lineLimit(1)
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.s10)
              }
              .buttonStyle(.plain)

              if item != searcher.results.last {
                Divider()
                  .padding(.horizontal, Theme.Spacing.sm)
              }
            }
          }
        }
      }
    }
  }
}
