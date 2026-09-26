import SwiftUI

enum FDAvatarSize {
  case sm
  case md
  case lg

  var dimension: CGFloat {
    switch self {
    case .sm: return Theme.TouchTarget.avatarSm
    case .md: return Theme.TouchTarget.avatarMd
    case .lg: return Theme.TouchTarget.avatarLg
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


  var body: some View {
    ZStack {
      if let imageUrl, !imageUrl.isEmpty {
        RemoteOrDataImage(urlString: imageUrl, contentMode: .fill)
      } else {
        if let color {
          color
        } else {
          Theme.faceFill
        }
        Text(initial)
          .font(size.font)
          .foregroundStyle(color == nil ? Theme.faceInk : .white)
      }
    }
    .frame(width: size.dimension, height: size.dimension)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(Theme.paper, lineWidth: ring ? Theme.Spacing.xxs : Theme.Spacing.none)
    )
  }
}
