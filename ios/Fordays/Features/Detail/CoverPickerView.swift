import SwiftUI
import PhotosUI
import ImageIO

enum CoverTab: String, CaseIterable, Identifiable {
  case gifs = "GIFs"
  case stills = "Stills"
  case photos = "Photos"

  var id: String { rawValue }
}

struct CoverItem: Identifiable, Hashable {
  let id: String
  let title: String
  let previewUrl: String
  let fullUrl: String
}

/// Renders either a base64 `data:image/...` URI or a remote `https://` URL.
struct RemoteOrDataImage: View {
  let urlString: String
  var contentMode: ContentMode = .fill

  var body: some View {
    if urlString.hasPrefix("data:image"),
       let base64Index = urlString.range(of: "base64,")?.upperBound,
       let data = Data(base64Encoded: String(urlString[base64Index...])),
       let uiImage = downsampledImage(from: data) {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: contentMode)
    } else if let url = URL(string: urlString) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let img):
          img.resizable().aspectRatio(contentMode: contentMode)
        default:
          LinearGradient(
            colors: [Theme.rose.opacity(0.3), Theme.sage.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
      }
    } else {
      Color.clear
    }
  }
}

private func downsampledImage(from data: Data, maxPixel: CGFloat = 720) -> UIImage? {
  let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
  guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions as CFDictionary) else {
    return UIImage(data: data)
  }
  let scale = UIScreen.main.scale
  let downsample: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceShouldCacheImmediately: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixel * scale,
  ]
  guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downsample as CFDictionary) else {
    return UIImage(data: data)
  }
  return UIImage(cgImage: cg)
}

/// Visual cover picker matching PWA CoverPicker (GIFs, Stills, and Photos).
struct CoverPickerView: View {
  @Binding var cover: String
  var titleHint: () -> String = { "" }

  @State private var tab: CoverTab = .gifs
  @State private var query = ""
  @State private var selectedPhotoItem: PhotosPickerItem? = nil
  @State private var isProcessingPhoto = false
  @State private var showCustomUrl = false

  private let gridColumns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !cover.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        previewSection
      }

      tabSelector

      switch tab {
      case .gifs:
        searchableGrid(placeholder: "Search GIFs…", items: filteredGifs)
      case .stills:
        searchableGrid(placeholder: "Search Stills…", items: filteredStills)
      case .photos:
        photosSection
      }

      customUrlSection
    }
    .onAppear {
      if query.isEmpty {
        query = titleHint().trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
  }

  // MARK: - Preview

  private var previewSection: some View {
    ZStack(alignment: .topTrailing) {
      RemoteOrDataImage(urlString: cover, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

      Button {
        withAnimation(.spring(response: 0.3)) {
          cover = ""
        }
      } label: {
        Text("Remove")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.black.opacity(0.65), in: Capsule())
          .padding(8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Tabs

  private var tabSelector: some View {
    HStack(spacing: 4) {
      ForEach(CoverTab.allCases) { t in
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            tab = t
          }
        } label: {
          Text(t.rawValue)
            .font(.footnote.weight(tab == t ? .semibold : .regular))
            .foregroundStyle(tab == t ? Theme.ink : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background {
              if tab == t {
                Capsule().fill(Theme.paperWarm)
                  .shadow(color: Theme.ink.opacity(0.08), radius: 4, y: 1)
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(3)
    .background(Theme.ink.opacity(0.06), in: Capsule())
  }

  // MARK: - Search & Grid

  private func searchableGrid(placeholder: String, items: [CoverItem]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)

        TextField(placeholder, text: $query)
          .font(.subheadline)
          .foregroundStyle(Theme.ink)

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.footnote)
              .foregroundStyle(Theme.inkFaint)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      if items.isEmpty {
        Text("No pictures found for “\(query)”. Try another word.")
          .font(.footnote)
          .foregroundStyle(Theme.inkFaint)
          .padding(.vertical, 12)
      } else {
        LazyVGrid(columns: gridColumns, spacing: 8) {
          ForEach(items) { item in
            Button {
              withAnimation(.spring(response: 0.3)) {
                cover = item.fullUrl
              }
            } label: {
              RemoteOrDataImage(urlString: item.previewUrl, contentMode: .fill)
                .frame(height: 74)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                  if cover == item.fullUrl {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                      .stroke(Theme.roseInk, lineWidth: 2.5)
                  }
                }
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  // MARK: - Photos Section

  private var photosSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        HStack(spacing: 8) {
          if isProcessingPhoto {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Image(systemName: "photo.on.rectangle")
              .font(.subheadline)
          }
          Text(isProcessingPhoto ? "Processing photo…" : "Choose from photo library")
            .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(isProcessingPhoto)
      .onChange(of: selectedPhotoItem) { _, newItem in
        guard let newItem else { return }
        Task {
          await processPickedPhoto(newItem)
        }
      }

      Text("Pick any photo from your camera roll. It syncs directly to your shared Orb.")
        .font(.caption)
        .foregroundStyle(Theme.inkFaint)
    }
    .padding(.top, 4)
  }

  private func processPickedPhoto(_ item: PhotosPickerItem) async {
    isProcessingPhoto = true
    defer { isProcessingPhoto = false }
    do {
      if let data = try await item.loadTransferable(type: Data.self) {
        if let compressedDataUrl = compressPhoto(data: data) {
          await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
              cover = compressedDataUrl
            }
          }
        }
      }
    } catch {
      // Photo loading error - ignore silently
    }
  }

  private func compressPhoto(data: Data, maxDimension: CGFloat = 1200, compressionQuality: CGFloat = 0.72) -> String? {
    guard let image = UIImage(data: data) else { return nil }
    let size = image.size
    let ratio = min(maxDimension / max(size.width, size.height), 1.0)
    let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)

    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    guard let compressedData = resized.jpegData(compressionQuality: compressionQuality) else { return nil }
    return "data:image/jpeg;base64," + compressedData.base64EncodedString()
  }

  // MARK: - Custom URL

  private var customUrlSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          showCustomUrl.toggle()
        }
      } label: {
        HStack(spacing: 4) {
          Text(showCustomUrl ? "Hide link input" : "Or paste image link")
          Image(systemName: showCustomUrl ? "chevron.up" : "chevron.down")
            .font(.caption2)
        }
        .font(.caption)
        .foregroundStyle(Theme.inkSoft)
      }
      .buttonStyle(.plain)

      if showCustomUrl {
        TextField("https://…", text: $cover)
          .font(.subheadline)
          .textFieldStyle(.plain)
          .padding(10)
          .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
      }
    }
    .padding(.top, 4)
  }

  // MARK: - Preset Catalogues

  private var filteredGifs: [CoverItem] {
    let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if clean.isEmpty { return Self.presetGifs }
    return Self.presetGifs.filter { $0.title.lowercased().contains(clean) || clean.contains($0.title.lowercased()) }
  }

  private var filteredStills: [CoverItem] {
    let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if clean.isEmpty { return Self.presetStills }
    return Self.presetStills.filter { $0.title.lowercased().contains(clean) || clean.contains($0.title.lowercased()) }
  }

  // Curated, fast-loading visual presets that match the Fordays romantic/life ethos
  private static let presetGifs: [CoverItem] = [
    CoverItem(
      id: "g1",
      title: "Dinner food drink restaurant toast celebration",
      previewUrl: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g2",
      title: "Coffee cafe brunch morning pastry",
      previewUrl: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g3",
      title: "Beach ocean sunset sea summer vacation trip",
      previewUrl: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g4",
      title: "Camp campfire outdoors tent mountain stars",
      previewUrl: "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g5",
      title: "Road trip car drive travel highway",
      previewUrl: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g6",
      title: "Cinema movie film tickets popcorn",
      previewUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g7",
      title: "Kayak river boat water lake paddle",
      previewUrl: "https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g8",
      title: "Museum art gallery walk culture",
      previewUrl: "https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "g9",
      title: "Cocktail drinks bar night party lounge",
      previewUrl: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=1200&q=80"
    )
  ]

  private static let presetStills: [CoverItem] = [
    CoverItem(
      id: "s1",
      title: "Sunset sky clouds pink orange evening dusk",
      previewUrl: "https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "s2",
      title: "Cozy home book tea reading rainy window",
      previewUrl: "https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "s3",
      title: "Flower bouquet garden bloom flora roses",
      previewUrl: "https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "s4",
      title: "Architecture city street travel europe paris",
      previewUrl: "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "s5",
      title: "Baking bread bakery kitchen cooking pasta",
      previewUrl: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1200&q=80"
    ),
    CoverItem(
      id: "s6",
      title: "Snow winter cabin cozy mountains pine trees",
      previewUrl: "https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?auto=format&fit=crop&w=300&q=80",
      fullUrl: "https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?auto=format&fit=crop&w=1200&q=80"
    )
  ]
}
