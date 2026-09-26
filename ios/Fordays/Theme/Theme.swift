import SwiftUI

enum Theme {
  static let paper = Color(hex: 0xF9F6F2)
  static let paperWarm = Color(hex: 0xFFFDFB)
  static let paperSunk = Color(hex: 0xEFEAE3)
  static let ink = Color(hex: 0x17140F)
  static let ink2 = Color(hex: 0x3B352C)
  static let inkSoft = Color(hex: 0x7C7365)
  static let inkFaint = Color(hex: 0xA79E90)
  static let rule = Color(hex: 0xE4DCD0)
  static let separator = Color(hex: 0x17140F).opacity(0.09)
  static let hairline = Color(hex: 0x17140F).opacity(0.12)

  static let fillQuaternary = Color(hex: 0x17140F).opacity(0.045)
  static let fillTertiary = Color(hex: 0x17140F).opacity(0.07)
  static let fillSecondary = Color(hex: 0x17140F).opacity(0.11)

  static let veil = Color(hex: 0x17140F).opacity(0.42)
  static let paperTranslucent = Color(hex: 0xFFFDFB).opacity(0.74)
  static let shadowCard = Color(hex: 0x17140F).opacity(0.18)
  static let roseGlow = Color(hex: 0xF2648B).opacity(0.45)
  static let scrim = Color(hex: 0x17140F).opacity(0.32)

  static let rose = Color(hex: 0xF2648B)

  /// A person's face: flat warm peach with a soft brown letter (7.4:1).
  /// Calm enough to repeat; white letters on these hues fall near 2:1.
  static let faceFill = Color(hex: 0xF0C296)
  static let faceInk = ink2
  static let roseInk = Color(hex: 0xC4285A)
  static let roseWash = Color(hex: 0xFFEAEE)
  static let sage = Color(hex: 0xA8CE85)
  static let sageInk = Color(hex: 0x4F7735)
  static let sageWash = Color(hex: 0xEDF6E3)

  static let ext = Color(hex: 0x98917F)
  static let extWash = Color(hex: 0xECE7DA)

  // Concentric corner radii
  static let radiusXs: CGFloat = 4
  static let radiusSm: CGFloat = 8
  static let controlRadius: CGFloat = 12
  static let radiusMd: CGFloat = 14
  static let cardRadius: CGFloat = 20
  static let sheetRadius: CGFloat = 38
  static let capsuleRadius: CGFloat = 999

  // Spacing scale — matches tokens.css. Prefer named aliases.
  enum Spacing {
    static let none: CGFloat = 0
    static let px: CGFloat = 1
    static let xxs: CGFloat = 2
    static let s3: CGFloat = 3
    static let xs: CGFloat = 4
    static let s5: CGFloat = 5
    static let s6: CGFloat = 6
    static let s7: CGFloat = 7
    static let sm: CGFloat = 8
    static let s9: CGFloat = 9
    static let s10: CGFloat = 10
    static let s11: CGFloat = 11
    static let md: CGFloat = 12
    static let s13: CGFloat = 13
    static let row: CGFloat = 14
    static let s15: CGFloat = 15
    static let base: CGFloat = 16
    static let s17: CGFloat = 17
    static let s18: CGFloat = 18
    static let s19: CGFloat = 19
    static let lg: CGFloat = 20
    static let s22: CGFloat = 22
    static let xl: CGFloat = 24
    static let s26: CGFloat = 26
    static let s28: CGFloat = 28
    static let s30: CGFloat = 30
    static let xxl: CGFloat = 32
    static let s34: CGFloat = 34
    static let s36: CGFloat = 36
    static let s38: CGFloat = 38
    static let xxxl: CGFloat = 40
    static let s42: CGFloat = 42
    static let s48: CGFloat = 48
    static let huge: CGFloat = 56
    static let toastClearance: CGFloat = 100
    /// Clears the + button's top edge (~143pt above the safe area) with a gap.
    static let scrollBottomClearance: CGFloat = 156
    static let overlapSm: CGFloat = -6
    static let overlapMd: CGFloat = -8
    static let opticalNudge: CGFloat = -0.5
    static let removeBadgeX: CGFloat = 10
    static let removeBadgeY: CGFloat = -2
  }

  // Touch targets & component dimensions
  enum TouchTarget {
    static let min: CGFloat = 44
    static let formRow: CGFloat = 46
    static let buttonMd: CGFloat = 50
    static let control: CGFloat = 36
    static let navBar: CGFloat = 56
    static let tabItemWidth: CGFloat = 84
    static let pill: CGFloat = 28
    static let tabBar: CGFloat = 64
    static let dayCellHeight: CGFloat = 52
    static let avatarXs: CGFloat = 18
    static let avatarSm: CGFloat = 24
    static let avatarChip: CGFloat = 22
    static let avatarFace: CGFloat = 26
    static let avatarMd: CGFloat = 32
    static let avatarLg: CGFloat = 40
    static let thumb: CGFloat = 42
    static let agendaTime: CGFloat = 72
    static let dayNumber: CGFloat = 30
    static let coverPreview: CGFloat = 140
    static let coverHero: CGFloat = 200
    static let coverTile: CGFloat = 74
    static let orbTile: CGFloat = 64
    static let orbFace: CGFloat = 72
    static let sheetDetentCompact: CGFloat = 280
    static let hairlineWidth: CGFloat = 0.5
    static let borderWidth: CGFloat = 1.0
    static let ringWidth: CGFloat = 1.5
    static let strokeThick: CGFloat = 2
    static let strokeFocus: CGFloat = 2.5
  }

  enum Motion {
    static let pressScale: CGFloat = 0.97
    static let pressSoft: CGFloat = 0.96
    static let pressOpacity: Double = 0.9
    static let spinner: CGFloat = 0.85
    static let photoSpinner: CGFloat = 0.8
    static let pressDuration: Double = 0.14
    static let fade: Double = 0.18
    static let shelf: Double = 0.2
    static let spring: Double = 0.3
    static let snappy: Double = 0.25
    static let snappyDamping: Double = 0.8
    static let tabSpring: Double = 0.35
    static let tabDamping: Double = 0.85
    static let sheetHandoff: Double = 0.15
    static let sheetHandoffLong: Double = 0.25
    static let disabledOpacity: Double = 0.38
  }

  enum Shadow {
    static let cardRadius: CGFloat = 10
    static let cardY: CGFloat = 4
    static let badgeRadius: CGFloat = 2
    static let badgeY: CGFloat = 1
  }

  static let brandName = "Fordays"

  private static let orbPalette: [[Color]] = [
    [Color(hex: 0xE0416F), Color(hex: 0x7A1F3D)],
    [Color(hex: 0xDE5A3E), Color(hex: 0x7E2A28)],
    [Color(hex: 0xD0842F), Color(hex: 0x6E3F22)],
    [Color(hex: 0xA8901F), Color(hex: 0x55491F)],
    [Color(hex: 0x6C9330), Color(hex: 0x35491F)],
    [Color(hex: 0x34925A), Color(hex: 0x1B4A2E)],
  ]

  /// Same orb washes as the web board. Title families pick a hue;
  /// no match falls back to the id so a card still keeps a colour.
  static func orbColors(for id: String, title: String? = nil) -> [Color] {
    orbPalette[orbHue(for: id, title: title)]
  }

  /// A board of cards, nudged so no card shares a colour with the one to its
  /// left or the one above it in the two-column grid — the PWA's `tintsFor`.
  static func orbColors(forBoard items: [(id: String, title: String?)]) -> [[Color]] {
    var chosen: [Int] = []
    for (i, item) in items.enumerated() {
      var idx = orbHue(for: item.id, title: item.title)
      var step = 0
      while step < orbPalette.count
        && ((i >= 1 && idx == chosen[i - 1]) || (i >= 2 && idx == chosen[i - 2])) {
        idx = (idx + 1) % orbPalette.count
        step += 1
      }
      chosen.append(idx)
    }
    return chosen.map { orbPalette[$0] }
  }

  /// 32-bit, exactly like the PWA's `bucket()` (Math.imul, >>>), so a card
  /// is the same colour on the phone as in the browser.
  private static func orbHue(for id: String, title: String?) -> Int {
    if let title, let hue = Art.hue(for: title) { return hue }
    var h: Int32 = 0
    for u in id.utf16 {
      h = h &* 31 &+ Int32(u)
    }
    var x = UInt32(bitPattern: h)
    x ^= x >> 16
    x = x &* 0x45d9f3b
    x ^= x >> 16
    return abs(Int(Int32(bitPattern: x))) % orbPalette.count
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct ScrollOffsetTracker: View {
  var coordinateSpace: String = "homeScroll"

  var body: some View {
    GeometryReader { proxy in
      Color.clear.preference(
        key: ScrollOffsetPreferenceKey.self,
        value: proxy.frame(in: .named(coordinateSpace)).minY
      )
    }
    .frame(height: Theme.Spacing.none)
  }
}

// MARK: - Typography Ramp (matches PWA tokens.css)

extension Font {
  static let fdMicro = Font.system(size: 9, weight: .bold, design: .default)
  static let fdTiny = Font.system(size: 10, weight: .semibold, design: .default)
  static let fdLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
  static let fdTitle1 = Font.system(size: 28, weight: .bold, design: .default)
  static let fdTitle2 = Font.system(size: 22, weight: .bold, design: .default)
  static let fdTitle3 = Font.system(size: 20, weight: .semibold, design: .default)
  static let fdHeadline = Font.system(size: 17, weight: .semibold, design: .default)
  static let fdBody = Font.system(size: 17, weight: .regular, design: .default)
  static let fdCallout = Font.system(size: 16, weight: .regular, design: .default)
  static let fdSubhead = Font.system(size: 15, weight: .regular, design: .default)
  static let fdFootnote = Font.system(size: 13, weight: .regular, design: .default)
  static let fdCaption = Font.system(size: 12, weight: .regular, design: .default)
  static let fdCaption1 = fdCaption
  static let fdCaption2 = Font.system(size: 11, weight: .medium, design: .default)
  static let fdGlyph = Font.system(size: 36, weight: .regular, design: .default)
}


