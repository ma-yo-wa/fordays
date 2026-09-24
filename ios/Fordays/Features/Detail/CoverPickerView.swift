import SwiftUI
import UIKit
import PhotosUI
import ImageIO

enum CoverTab: String, CaseIterable, Identifiable {
  case gifs = "GIFs"
  case stills = "Stills"
  case photos = "Photos"

  var id: String { rawValue }
}

struct CoverItem: Identifiable, Hashable, Decodable {
  let id: String
  let title: String
  let previewUrl: String
  let fullUrl: String
  /// Unsplash's download_location — pinged when a still is picked.
  var download: String = ""

  enum CodingKeys: String, CodingKey {
    case id, title, preview, full, download
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = (try? c.decode(String.self, forKey: .title)) ?? ""
    previewUrl = try c.decode(String.self, forKey: .preview)
    fullUrl = try c.decode(String.self, forKey: .full)
    download = (try? c.decode(String.self, forKey: .download)) ?? ""
  }
}

/// Live GIFs and stills through the `giphy` / `unsplash` Edge Functions,
/// so no API key ships in the app (PRODUCT.md → Covers).
enum CoverSearch {
  enum Failure: Error { case rate, notConfigured, http, network }

  private static let limit = 15

  static func gifs(_ query: String) async throws -> [CoverItem] {
    try await fetch("giphy", action: query.isEmpty ? "trending" : "search", query: query)
  }

  static func stills(_ query: String) async throws -> [CoverItem] {
    try await fetch("unsplash", action: query.isEmpty ? "list" : "search", query: query)
  }

  /// Unsplash asks for this ping when a photo is actually chosen.
  static func trackDownload(_ download: String) {
    guard !download.isEmpty, var url = functionURL("unsplash") else { return }
    url.append(queryItems: [
      URLQueryItem(name: "action", value: "track"),
      URLQueryItem(name: "url", value: download),
    ])
    Task { _ = try? await URLSession.shared.data(for: request(url)) }
  }

  private static func fetch(_ function: String, action: String, query: String) async throws -> [CoverItem] {
    guard var url = functionURL(function) else { throw Failure.notConfigured }
    var items = [
      URLQueryItem(name: "action", value: action),
      URLQueryItem(name: "limit", value: String(limit)),
    ]
    if !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
    url.append(queryItems: items)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request(url))
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError where error.code == .cancelled {
      throw CancellationError()
    } catch {
      throw Failure.network
    }
    switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
    case 200: break
    case 429: throw Failure.rate
    case 404, 501: throw Failure.notConfigured
    default: throw Failure.http
    }
    struct Body: Decodable { let items: [CoverItem]? }
    return (try? JSONDecoder().decode(Body.self, from: data).items) ?? []
  }

  private static func functionURL(_ name: String) -> URL? {
    URL(string: "\(AppConfig.supabaseURL.absoluteString)/functions/v1/\(name)")
  }

  private static func request(_ url: URL) -> URLRequest {
    var req = URLRequest(url: url, timeoutInterval: 10)
    req.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
    return req
  }
}

/// Renders a Giphy/Unsplash `https` URL or a gallery `data:image/...` JPEG.
struct RemoteOrDataImage: View {
  let urlString: String
  var contentMode: ContentMode = .fill
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        LinearGradient(
          colors: [Theme.roseWash, Theme.sageWash],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
    .task(id: urlString) {
      image = await CoverImageStore.shared.load(urlString)
    }
  }
}

final class CoverImageStore {
  static let shared = CoverImageStore()
  /// One screen of the board — same as `FIRST_BOARD_COVERS`.
  private static let maxCovers = 6
  private let memory = NSCache<NSString, UIImage>()
  private let folder: URL

  private init() {
    memory.countLimit = Self.maxCovers
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    folder = base.appendingPathComponent("fordays-covers", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  func prefetch(_ urls: [String]) {
    for raw in urls {
      Task { _ = await load(raw) }
    }
  }

  func load(_ raw: String) async -> UIImage? {
    if raw.hasPrefix("emoji:") { return nil }
    let key = cacheKey(raw)
    if let hit = memory.object(forKey: key) { return hit }
    if raw.hasPrefix("data:image") {
      guard let range = raw.range(of: "base64,"),
            let data = Data(base64Encoded: String(raw[range.upperBound...])),
            let img = downsampledImage(from: data)
      else { return nil }
      memory.setObject(img, forKey: key)
      return img
    }
    guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true else { return nil }
    return await image(for: url)
  }

  func image(for url: URL) async -> UIImage? {
    let key = url.absoluteString as NSString
    if let hit = memory.object(forKey: key) { return hit }
    let file = fileURL(for: url)
    if let data = try? Data(contentsOf: file), let img = downsampledImage(from: data) {
      try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
      memory.setObject(img, forKey: key)
      return img
    }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      try? data.write(to: file, options: .atomic)
      trimDisk()
      let img = downsampledImage(from: data)
      if let img { memory.setObject(img, forKey: key) }
      return img
    } catch {
      return nil
    }
  }

  private func trimDisk() {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
      at: folder,
      includingPropertiesForKeys: [.contentModificationDateKey]
    ), files.count > Self.maxCovers
    else { return }
    let ordered = files.sorted {
      let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return a < b
    }
    for stale in ordered.prefix(files.count - Self.maxCovers) {
      try? fm.removeItem(at: stale)
    }
  }

  private func cacheKey(_ raw: String) -> NSString {
    if raw.hasPrefix("data:image") {
      return "data:\(raw.hashValue)" as NSString
    }
    return raw as NSString
  }

  private func fileURL(for url: URL) -> URL {
    let name = String(url.absoluteString.hashValue)
    return folder.appendingPathComponent(name)
  }
}

struct CachedRemoteImage: View {
  let url: URL
  var contentMode: ContentMode = .fill

  var body: some View {
    RemoteOrDataImage(urlString: url.absoluteString, contentMode: contentMode)
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
  @State private var gifs: [CoverItem] = []
  @State private var stills: [CoverItem] = []
  @State private var loading = false
  @State private var message: String?
  @State private var loadTask: Task<Void, Never>?
  @FocusState private var searchFocused: Bool
  @State private var selectedPhotoItem: PhotosPickerItem? = nil
  @State private var isProcessingPhoto = false
  @State private var photoError: String?

  private let gridColumns = [
    GridItem(.flexible(), spacing: Theme.Spacing.s10),
    GridItem(.flexible(), spacing: Theme.Spacing.s10),
    GridItem(.flexible(), spacing: Theme.Spacing.s10)
  ]

  private var hits: [CoverItem] {
    switch tab {
    case .gifs: return gifs
    case .stills: return stills
    case .photos: return []
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      if !cover.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        previewSection
      }

      tabSelector

      switch tab {
      case .gifs, .stills:
        searchSection
      case .photos:
        photosSection
      }
    }
    .onAppear {
      // Trending GIFs on open, like the PWA.
      query = ""
      load(.gifs, "")
    }
    .onDisappear { loadTask?.cancel() }
  }

  // MARK: - Preview

  private var previewSection: some View {
    ZStack(alignment: .topTrailing) {
      RemoteOrDataImage(urlString: cover, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.TouchTarget.coverPreview)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

      Button {
        withAnimation(.spring(response: Theme.Motion.spring)) {
          cover = ""
        }
      } label: {
        Text("Remove")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, Theme.Spacing.s10)
          .padding(.vertical, Theme.Spacing.s5)
          .background(Theme.ink, in: Capsule())
          .padding(Theme.Spacing.sm)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Tabs

  private var tabSelector: some View {
    HStack(spacing: Theme.Spacing.xs) {
      ForEach(CoverTab.allCases) { t in
        Button {
          withAnimation(.spring(response: Theme.Motion.snappy, dampingFraction: Theme.Motion.snappyDamping)) {
            tab = t
          }
          if t == .photos {
            message = nil
          } else {
            load(t, query.trimmingCharacters(in: .whitespacesAndNewlines))
          }
        } label: {
          Text(t.rawValue)
            .font(.footnote.weight(tab == t ? .semibold : .regular))
            .foregroundStyle(tab == t ? Theme.ink : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.TouchTarget.avatarMd)
            .background {
              if tab == t {
                Capsule().fill(Theme.paperWarm)
                  .shadow(color: Theme.fillSecondary, radius: Theme.Spacing.xs, y: Theme.TouchTarget.borderWidth)
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(Theme.Spacing.s3)
    .background(Theme.fillTertiary, in: Capsule())
  }

  // MARK: - Search & Grid

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.s10) {
      HStack(spacing: Theme.Spacing.sm) {
        if loading {
          ProgressView()
            .scaleEffect(Theme.Motion.photoSpinner)
        } else {
          Image(systemName: "magnifyingglass")
            .font(.footnote)
            .foregroundStyle(Theme.inkFaint)
        }

        TextField(tab == .gifs ? "Search Giphy…" : "Search Unsplash…", text: $query)
          .font(.subheadline)
          .foregroundStyle(Theme.ink)
          .focused($searchFocused)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.search)
          .onChange(of: query) { _, next in
            load(tab, next.trimmingCharacters(in: .whitespacesAndNewlines), debounce: true)
          }
          .onChange(of: searchFocused) { _, focused in
            // Nothing to show yet: start from the plan's title, like the PWA.
            guard focused, query.trimmingCharacters(in: .whitespaces).isEmpty, hits.isEmpty else { return }
            let t = titleHint().trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { load(tab, "") } else { query = t }
          }

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
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.sm)
      .background(Theme.fillQuaternary)
      .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))

      if !hits.isEmpty {
        LazyVGrid(columns: gridColumns, spacing: Theme.Spacing.sm) {
          ForEach(hits) { item in
            Button {
              if tab == .stills { CoverSearch.trackDownload(item.download) }
              withAnimation(.spring(response: Theme.Motion.spring)) {
                cover = item.fullUrl
              }
              message = nil
            } label: {
              // AsyncImage, not the six-cover store: picker tiles shouldn't
              // push the board's warmed covers out of it.
              AsyncImage(url: URL(string: item.previewUrl)) { phase in
                if let image = phase.image {
                  image.resizable().aspectRatio(contentMode: .fill)
                } else {
                  Theme.fillTertiary
                }
              }
              .frame(height: Theme.TouchTarget.coverTile)
              .frame(maxWidth: .infinity)
              .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
              .overlay {
                if cover == item.fullUrl {
                  RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .stroke(Theme.roseInk, lineWidth: Theme.TouchTarget.strokeFocus)
                }
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title.isEmpty ? "Cover" : String(item.title.prefix(60)))
          }
        }

        if tab == .stills, let credit = URL(string: "https://unsplash.com/?utm_source=fordays&utm_medium=referral") {
          Link("Photos via Unsplash", destination: credit)
            .font(.caption)
            .foregroundStyle(Theme.inkFaint)
        }
      }

      if let message {
        HStack(spacing: Theme.Spacing.sm) {
          Text(message)
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)
          Spacer(minLength: 0)
          Button("Retry") {
            load(tab, query.trimmingCharacters(in: .whitespacesAndNewlines))
          }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Theme.roseInk)
        }
      }
    }
  }

  /// Same flow and messages as the PWA's `load`.
  private func load(_ source: CoverTab, _ q: String, debounce: Bool = false) {
    guard source != .photos else { return }
    loadTask?.cancel()
    loadTask = Task {
      if debounce {
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
      }
      loading = true
      message = nil
      do {
        let next = source == .gifs ? try await CoverSearch.gifs(q) : try await CoverSearch.stills(q)
        if Task.isCancelled { return }
        if source == .gifs { gifs = next } else { stills = next }
        if next.isEmpty {
          message = q.isEmpty
            ? (source == .gifs ? "No GIFs came back." : "No stills came back.")
            : "Nothing for “\(q)”. Try another word."
        }
      } catch is CancellationError {
        return
      } catch {
        if Task.isCancelled { return }
        if source == .gifs { gifs = [] } else { stills = [] }
        let failure = error as? CoverSearch.Failure
        let name = source == .gifs ? "Giphy" : "Unsplash"
        switch failure {
        case .rate: message = "\(name)'s rate limit is hit. Give it a minute."
        case .notConfigured: message = source == .gifs ? "GIFs aren’t available right now." : "Stills aren’t available right now."
        case .http: message = "\(name) returned an error."
        default: message = "Couldn't reach \(name)."
        }
      }
      loading = false
    }
  }

  // MARK: - Photos Section

  private var photosSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.s10) {
      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        HStack(spacing: Theme.Spacing.sm) {
          if isProcessingPhoto {
            ProgressView()
              .scaleEffect(Theme.Motion.photoSpinner)
          } else {
            Image(systemName: "photo.on.rectangle")
              .font(.subheadline)
          }
          Text(isProcessingPhoto ? "Processing photo…" : "Choose from library")
            .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.row)
        .background(Theme.fillQuaternary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(isProcessingPhoto)
      .onChange(of: selectedPhotoItem) { _, newItem in
        guard let newItem else { return }
        Task {
          await processPickedPhoto(newItem)
        }
      }

      Text("Picks a photo from this phone. It’s saved with this.")
        .font(.caption)
        .foregroundStyle(Theme.inkFaint)

      if let photoError {
        Text(photoError)
          .font(.caption)
          .foregroundStyle(Theme.roseInk)
      }
    }
    .padding(.top, Theme.Spacing.xs)
  }

  private func processPickedPhoto(_ item: PhotosPickerItem) async {
    isProcessingPhoto = true
    photoError = nil
    defer { isProcessingPhoto = false }
    guard let data = try? await item.loadTransferable(type: Data.self),
          let compressedDataUrl = compressPhoto(data: data)
    else {
      photoError = "Couldn’t use that photo"
      return
    }
    withAnimation(.spring(response: Theme.Motion.spring)) {
      cover = compressedDataUrl
    }
  }

  /// Same size and quality as the PWA's `fileToCoverDataUrl` — 960px long side, JPEG 0.82.
  private func compressPhoto(data: Data, maxDimension: CGFloat = 960, compressionQuality: CGFloat = 0.82) -> String? {
    guard let image = UIImage(data: data) else { return nil }
    let size = image.size
    let ratio = min(maxDimension / max(size.width, size.height), 1.0)
    let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)

    // Scale 1: target size is pixels. The default is the screen scale, which
    // would make a "960" photo 2880px on a 3× phone.
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    guard let compressedData = resized.jpegData(compressionQuality: compressionQuality) else { return nil }
    return "data:image/jpeg;base64," + compressedData.base64EncodedString()
  }
}
