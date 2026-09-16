import SwiftUI

enum Theme {
  static let paper = Color(hex: 0xF9F6F2)
  static let paperWarm = Color(hex: 0xFFFDFB)
  static let ink = Color(hex: 0x17140F)
  static let inkSoft = Color(hex: 0x7C7365)
  static let inkFaint = Color(hex: 0xA79E90)
  static let rose = Color(hex: 0xF2648B)
  static let roseInk = Color(hex: 0xC4285A)
  static let roseWash = Color(hex: 0xFFEAEE)
  static let sage = Color(hex: 0xA8CE85)
  static let sageWash = Color(hex: 0xEDF6E3)
  /// Avatar seats — one partner at each end of the orb (matches web).
  static let faceSage = Color(hex: 0x4F7735)
  static let faceRose = Color(hex: 0xC4285A)
  static let cardRadius: CGFloat = 20
  static let capsuleRadius: CGFloat = 999
  static let brandName = "Fordays"

  /// Same orb washes as the web board. Title families pick a hue;
  /// no match falls back to the id so a card still keeps a colour.
  static func orbColors(for id: String, title: String? = nil) -> [Color] {
    let palette: [[Color]] = [
      [Color(hex: 0xE0416F), Color(hex: 0x7A1F3D)],
      [Color(hex: 0xDE5A3E), Color(hex: 0x7E2A28)],
      [Color(hex: 0xD0842F), Color(hex: 0x6E3F22)],
      [Color(hex: 0xA8901F), Color(hex: 0x55491F)],
      [Color(hex: 0x6C9330), Color(hex: 0x35491F)],
      [Color(hex: 0x34925A), Color(hex: 0x1B4A2E)],
    ]
    if let title, let hue = Art.hue(for: title) {
      return palette[hue]
    }
    var h = 0
    for u in id.utf16 {
      h = (h &* 31 &+ Int(u))
    }
    h ^= h &>> 16
    h = h &* 0x45d9f3b
    h ^= h &>> 16
    return palette[abs(h) % palette.count]
  }
}

extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
  }
}

/// The ambient orb background unwrapped across the viewport, matching PWA global.css:
/// rose bloom behind the masthead, greens at the edges, peach pooling at the bottom.
struct OrbBackground: View {
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let maxDim = max(w, h)

      ZStack {
        Theme.paper

        // Rose bloom behind masthead
        RadialGradient(
          stops: [
            .init(color: Color(red: 253/255, green: 122/255, blue: 154/255).opacity(0.40), location: 0),
            .init(color: Color(red: 253/255, green: 164/255, blue: 146/255).opacity(0.20), location: 0.44),
            .init(color: .clear, location: 0.74),
          ],
          center: UnitPoint(x: 0.5, y: -0.10),
          startRadius: 0,
          endRadius: maxDim * 0.52
        )

        // Soft sage at top-right
        RadialGradient(
          stops: [
            .init(color: Color(red: 205/255, green: 231/255, blue: 179/255).opacity(0.52), location: 0),
            .init(color: .clear, location: 0.62),
          ],
          center: UnitPoint(x: 1.04, y: 0.16),
          startRadius: 0,
          endRadius: maxDim * 0.42
        )

        // Soft sage at mid-left
        RadialGradient(
          stops: [
            .init(color: Color(red: 214/255, green: 222/255, blue: 170/255).opacity(0.44), location: 0),
            .init(color: .clear, location: 0.64),
          ],
          center: UnitPoint(x: -0.06, y: 0.30),
          startRadius: 0,
          endRadius: maxDim * 0.42
        )

        // Peach pooling at bottom
        RadialGradient(
          stops: [
            .init(color: Color(red: 240/255, green: 194/255, blue: 150/255).opacity(0.34), location: 0),
            .init(color: .clear, location: 0.66),
          ],
          center: UnitPoint(x: 0.50, y: 1.14),
          startRadius: 0,
          endRadius: maxDim * 0.58
        )
      }
      .ignoresSafeArea()
    }
    .ignoresSafeArea()
  }
}

