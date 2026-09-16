import SwiftUI

enum FDAvatarSize {
  case sm
  case md
  case lg

  var dimension: CGFloat {
    switch self {
    case .sm: return 24
    case .md: return 32
    case .lg: return 42
    }
  }

  var font: Font {
    switch self {
    case .sm: return .fdCaption2.weight(.bold)
    case .md: return .fdFootnote.weight(.bold)
    case .lg: return .fdHeadline
    }
  }
}

struct FDAvatar: View {
  var name: String? = nil
  var seat: Int = 0
  var color: Color? = nil
  var imageUrl: String? = nil
  var size: FDAvatarSize = .md
  var ring: Bool = false

  private var initial: String {
    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
      return ""
    }
    return String(name.prefix(1)).uppercased()
  }

  private var backgroundColor: Color {
    if let color { return color }
    return seat == 0 ? Theme.faceSage : Theme.faceRose
  }

  var body: some View {
    ZStack {
      if let imageUrl, !imageUrl.isEmpty {
        RemoteOrDataImage(urlString: imageUrl, contentMode: .fill)
      } else {
        backgroundColor
        Text(initial)
          .font(size.font)
          .foregroundStyle(.white)
      }
    }
    .frame(width: size.dimension, height: size.dimension)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(Theme.paper, lineWidth: ring ? 2 : 0)
    )
  }
}
