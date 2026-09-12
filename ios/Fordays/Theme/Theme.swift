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
