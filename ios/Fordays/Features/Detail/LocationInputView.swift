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
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text("📍")
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)

        TextField(placeholder, text: $text)
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
      .padding(12)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      if showSuggestions && isFocused && !searcher.results.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(searcher.results, id: \.self) { item in
            Button {
              let full = item.subtitle.isEmpty ? item.title : "\(item.title), \(item.subtitle)"
              text = full
              showSuggestions = false
              isFocused = false
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                  .font(.subheadline.weight(.medium))
                  .foregroundStyle(Theme.ink)
                  .lineLimit(1)

                if !item.subtitle.isEmpty {
                  Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
              .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            if item != searcher.results.last {
              Divider()
                .padding(.horizontal, 8)
            }
          }
        }
        .padding(4)
        .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
      }
    }
  }
}
