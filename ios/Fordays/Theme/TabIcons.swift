import SwiftUI

/// Tab glyphs matching the PWA `TabBar` SVGs — outline when idle, filled when selected.
enum TabGlyph {
  case bucket
  case calendar
  case memories
}

struct TabIcon: View {
  let glyph: TabGlyph
  let on: Bool

  var body: some View {
    Group {
      switch glyph {
      case .bucket:
        BucketGlyph(on: on)
      case .calendar:
        CalendarGlyph(on: on)
      case .memories:
        MemoriesGlyph(on: on)
      }
    }
    .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)
  }
}

private struct BucketGlyph: View {
  let on: Bool

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 24
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

      if on {
        var bucket = Path()
        bucket.move(to: p(4.6, 4))
        bucket.addLine(to: p(19.4, 4))
        bucket.addLine(to: p(17.4, 16.3))
        bucket.addQuadCurve(to: p(14.4, 20), control: p(17.2, 19.2))
        bucket.addLine(to: p(9.6, 20))
        bucket.addQuadCurve(to: p(6.6, 16.3), control: p(6.8, 19.2))
        bucket.closeSubpath()
        ctx.fill(bucket, with: .foreground)

        var check = Path()
        check.move(to: p(8.2, 11.2))
        check.addLine(to: p(10.6, 13.6))
        check.addLine(to: p(15.4, 8.6))
        ctx.stroke(
          check,
          with: .color(Theme.paperWarm),
          style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, lineJoin: .round)
        )
      } else {
        var bucket = Path()
        bucket.move(to: p(4.6, 5))
        bucket.addLine(to: p(19.4, 5))
        bucket.addLine(to: p(17.4, 17.3))
        bucket.addQuadCurve(to: p(14.4, 20), control: p(17.1, 19.5))
        bucket.addLine(to: p(9.6, 20))
        bucket.addQuadCurve(to: p(6.6, 17.3), control: p(6.9, 19.5))
        bucket.closeSubpath()
        ctx.stroke(
          bucket,
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s, lineJoin: .round)
        )

        var check = Path()
        check.move(to: p(8.6, 10.6))
        check.addLine(to: p(11.0, 13.0))
        check.addLine(to: p(15.4, 8.6))
        ctx.stroke(
          check,
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round, lineJoin: .round)
        )
      }
    }
  }
}

private struct CalendarGlyph: View {
  let on: Bool

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 24
      func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rx: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: rx * s)
      }
      func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x1 * s, y: y1 * s))
        p.addLine(to: CGPoint(x: x2 * s, y: y2 * s))
        return p
      }

      if on {
        ctx.fill(r(3, 5, 18, 16, 4), with: .foreground)
        ctx.stroke(
          line(8, 2.5, 8, 5.5),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round)
        )
        ctx.stroke(
          line(16, 2.5, 16, 5.5),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round)
        )
        ctx.stroke(
          line(4, 10, 20, 10),
          with: .color(Theme.paperWarm),
          style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round)
        )
      } else {
        ctx.stroke(
          r(3, 5, 18, 16, 4),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s)
        )
        ctx.stroke(
          line(3, 10, 21, 10),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round)
        )
        ctx.stroke(
          line(8, 3, 8, 6),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round)
        )
        ctx.stroke(
          line(16, 3, 16, 6),
          with: .foreground,
          style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round)
        )
      }
    }
  }
}

private struct MemoriesGlyph: View {
  let on: Bool

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 24
      let stroke = StrokeStyle(lineWidth: 1.7 * s, lineCap: .round, lineJoin: .round)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

      if on {
        // Viewfinder hump
        var hump = Path()
        hump.move(to: p(7.2, 5.2))
        hump.addLine(to: p(10.3, 5.2))
        hump.addLine(to: p(11.2, 6.7))
        hump.addLine(to: p(8.1, 6.7))
        hump.closeSubpath()
        ctx.fill(hump, with: .foreground)

        ctx.fill(
          Path(roundedRect: CGRect(x: 2 * s, y: 7.2 * s, width: 20 * s, height: 12.4 * s), cornerRadius: 2.2 * s),
          with: .foreground
        )
        ctx.fill(
          Path(ellipseIn: CGRect(x: 8.45 * s, y: 9.75 * s, width: 7.1 * s, height: 7.1 * s)),
          with: .color(Theme.paperWarm.opacity(0.95))
        )
        ctx.fill(
          Path(ellipseIn: CGRect(x: 10.45 * s, y: 11.75 * s, width: 3.1 * s, height: 3.1 * s)),
          with: .foreground
        )
        ctx.fill(
          Path(roundedRect: CGRect(x: 17.2 * s, y: 9.1 * s, width: 2.4 * s, height: 1.7 * s), cornerRadius: 0.45 * s),
          with: .color(Theme.paperWarm.opacity(0.9))
        )
      } else {
        var body = Path()
        body.move(to: p(8.1, 6.8))
        body.addLine(to: p(10.5, 6.8))
        body.addLine(to: p(11.3, 8.0))
        body.addLine(to: p(19.6, 8.0))
        body.addQuadCurve(to: p(21.6, 10.0), control: p(21.6, 8.0))
        body.addLine(to: p(21.6, 17.2))
        body.addQuadCurve(to: p(19.6, 19.2), control: p(21.6, 19.2))
        body.addLine(to: p(4.4, 19.2))
        body.addQuadCurve(to: p(2.4, 17.2), control: p(2.4, 19.2))
        body.addLine(to: p(2.4, 10.0))
        body.addQuadCurve(to: p(4.4, 8.0), control: p(2.4, 8.0))
        body.addLine(to: p(8.1, 8.0))
        body.closeSubpath()
        ctx.stroke(body, with: .foreground, style: stroke)

        ctx.stroke(
          Path(ellipseIn: CGRect(x: 8.8 * s, y: 10.2 * s, width: 6.4 * s, height: 6.4 * s)),
          with: .foreground,
          style: stroke
        )
        ctx.stroke(
          Path(ellipseIn: CGRect(x: 10.75 * s, y: 12.15 * s, width: 2.5 * s, height: 2.5 * s)),
          with: .foreground,
          style: stroke
        )

        var flash = Path()
        flash.move(to: p(17.4, 9.4))
        flash.addLine(to: p(19.5, 9.4))
        ctx.stroke(flash, with: .foreground, style: stroke)
      }
    }
  }
}

/// Fine outline glyphs for forms and navigation, matching PWA SVGs with 1.8pt stroke.
enum FormGlyph {
  case orb
  case account
  case calendar
  case bell
  case history
  case signOut
}

struct FormGlyphIcon: View {
  let glyph: FormGlyph
  var destructive: Bool = false

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 24
      let stroke = StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, lineJoin: .round)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
      func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rx: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: rx * s)
      }
      func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(x1, y1))
        path.addLine(to: p(x2, y2))
        return path
      }

      switch glyph {
      case .orb:
        let circle = Path(ellipseIn: CGRect(x: 4 * s, y: 4 * s, width: 16 * s, height: 16 * s))
        ctx.stroke(circle, with: .foreground, style: stroke)

      case .account:
        let head = Path(ellipseIn: CGRect(x: 8 * s, y: 4 * s, width: 8 * s, height: 8 * s))
        ctx.stroke(head, with: .foreground, style: stroke)
        var shoulders = Path()
        shoulders.move(to: p(4, 20))
        shoulders.addCurve(to: p(12, 13), control1: p(4, 16), control2: p(8, 13))
        shoulders.addCurve(to: p(20, 20), control1: p(16, 13), control2: p(20, 16))
        ctx.stroke(shoulders, with: .foreground, style: stroke)

      case .calendar:
        ctx.stroke(r(3, 4, 18, 18, 2), with: .foreground, style: stroke)
        ctx.stroke(line(16, 2, 16, 6), with: .foreground, style: stroke)
        ctx.stroke(line(8, 2, 8, 6), with: .foreground, style: stroke)
        ctx.stroke(line(3, 10, 21, 10), with: .foreground, style: stroke)

      case .bell:
        var bell = Path()
        bell.move(to: p(18, 8))
        bell.addCurve(to: p(6, 8), control1: p(18, 4.69), control2: p(12.63, 2))
        bell.addCurve(to: p(3, 17), control1: p(6, 15), control2: p(3, 17))
        bell.addLine(to: p(21, 17))
        bell.addCurve(to: p(18, 8), control1: p(21, 17), control2: p(18, 15))
        ctx.stroke(bell, with: .foreground, style: stroke)
        var clapper = Path()
        clapper.move(to: p(13.73, 21))
        clapper.addQuadCurve(to: p(10.27, 21), control: p(12, 23))
        ctx.stroke(clapper, with: .foreground, style: stroke)

      case .history:
        let clock = Path(ellipseIn: CGRect(x: 2 * s, y: 2 * s, width: 20 * s, height: 20 * s))
        ctx.stroke(clock, with: .foreground, style: stroke)
        var hands = Path()
        hands.move(to: p(12, 6))
        hands.addLine(to: p(12, 12))
        hands.addLine(to: p(16, 14))
        ctx.stroke(hands, with: .foreground, style: stroke)

      case .signOut:
        var door = Path()
        door.move(to: p(9, 21))
        door.addLine(to: p(5, 21))
        door.addQuadCurve(to: p(3, 19), control: p(3, 21))
        door.addLine(to: p(3, 5))
        door.addQuadCurve(to: p(5, 3), control: p(3, 3))
        door.addLine(to: p(9, 3))
        ctx.stroke(door, with: .foreground, style: stroke)
        var arrow = Path()
        arrow.move(to: p(16, 17))
        arrow.addLine(to: p(21, 12))
        arrow.addLine(to: p(16, 7))
        ctx.stroke(arrow, with: .foreground, style: stroke)
        ctx.stroke(line(21, 12, 9, 12), with: .foreground, style: stroke)
      }
    }
    .foregroundStyle(destructive ? Theme.roseInk : Theme.inkSoft)
    .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)
  }
}

/// Detail-sheet marks. Calendar is the home-tab outline (no plus, no dot).
enum ActionGlyph {
  case calendar
  case suggest
  case trash
  case people
  case bucket
  case again
}

struct ActionGlyphIcon: View {
  let glyph: ActionGlyph

  var body: some View {
    Canvas { ctx, size in
      let s = min(size.width, size.height) / 24
      let width: CGFloat = glyph == .calendar ? 1.7 : 1.8
      let stroke = StrokeStyle(lineWidth: width * s, lineCap: .round, lineJoin: .round)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
      func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(x1, y1))
        path.addLine(to: p(x2, y2))
        return path
      }
      func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rx: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: rx * s)
      }

      switch glyph {
      case .calendar:
        ctx.stroke(box(3, 5, 18, 16, 4), with: .foreground, style: stroke)
        ctx.stroke(line(3, 10, 21, 10), with: .foreground, style: stroke)
        ctx.stroke(line(8, 3, 8, 6), with: .foreground, style: stroke)
        ctx.stroke(line(16, 3, 16, 6), with: .foreground, style: stroke)

      case .suggest:
        var bubble = Path()
        bubble.move(to: p(7.5, 4))
        bubble.addLine(to: p(16.5, 4))
        bubble.addQuadCurve(to: p(19, 6.5), control: p(19, 4))
        bubble.addLine(to: p(19, 13.5))
        bubble.addQuadCurve(to: p(16.5, 16), control: p(19, 16))
        bubble.addLine(to: p(12, 16))
        bubble.addLine(to: p(8, 19))
        bubble.addLine(to: p(8, 16))
        bubble.addLine(to: p(7.5, 16))
        bubble.addQuadCurve(to: p(5, 13.5), control: p(5, 16))
        bubble.addLine(to: p(5, 6.5))
        bubble.addQuadCurve(to: p(7.5, 4), control: p(5, 4))
        bubble.closeSubpath()
        ctx.stroke(bubble, with: .foreground, style: stroke)
        ctx.stroke(line(9, 9, 15, 9), with: .foreground, style: stroke)
        ctx.stroke(line(9, 12, 12.5, 12), with: .foreground, style: stroke)

      case .trash:
        ctx.stroke(line(4, 7, 20, 7), with: .foreground, style: stroke)
        var lid = Path()
        lid.move(to: p(9, 7))
        lid.addLine(to: p(9, 5))
        lid.addQuadCurve(to: p(10, 4), control: p(9, 4))
        lid.addLine(to: p(14, 4))
        lid.addQuadCurve(to: p(15, 5), control: p(15, 4))
        lid.addLine(to: p(15, 7))
        ctx.stroke(lid, with: .foreground, style: stroke)
        var bin = Path()
        bin.move(to: p(6, 7))
        bin.addLine(to: p(7, 19))
        bin.addQuadCurve(to: p(9, 21), control: p(7, 21))
        bin.addLine(to: p(15, 21))
        bin.addQuadCurve(to: p(17, 19), control: p(17, 21))
        bin.addLine(to: p(18, 7))
        ctx.stroke(bin, with: .foreground, style: stroke)

      case .people:
        ctx.stroke(
          Path(ellipseIn: CGRect(x: 5 * s, y: 3 * s, width: 8 * s, height: 8 * s)),
          with: .foreground,
          style: stroke
        )
        var shoulders = Path()
        shoulders.move(to: p(16, 21))
        shoulders.addLine(to: p(16, 19))
        shoulders.addQuadCurve(to: p(12, 15), control: p(16, 15))
        shoulders.addLine(to: p(6, 15))
        shoulders.addQuadCurve(to: p(2, 19), control: p(2, 15))
        shoulders.addLine(to: p(2, 21))
        ctx.stroke(shoulders, with: .foreground, style: stroke)
        var head = Path()
        head.addArc(
          center: p(16, 7),
          radius: 4 * s,
          startAngle: .degrees(-80),
          endAngle: .degrees(80),
          clockwise: false
        )
        ctx.stroke(head, with: .foreground, style: stroke)
        var beside = Path()
        beside.move(to: p(22, 21))
        beside.addLine(to: p(22, 19))
        beside.addQuadCurve(to: p(19, 15.13), control: p(22, 15.13))
        ctx.stroke(beside, with: .foreground, style: stroke)

      case .bucket:
        var bucket = Path()
        bucket.move(to: p(4.6, 5))
        bucket.addLine(to: p(19.4, 5))
        bucket.addLine(to: p(17.4, 17.3))
        bucket.addQuadCurve(to: p(14.4, 20), control: p(17.2, 20))
        bucket.addLine(to: p(9.6, 20))
        bucket.addQuadCurve(to: p(6.6, 17.3), control: p(6.8, 20))
        bucket.closeSubpath()
        ctx.stroke(bucket, with: .foreground, style: stroke)
        var check = Path()
        check.move(to: p(8.6, 10.6))
        check.addLine(to: p(11, 13))
        check.addLine(to: p(15.4, 8.6))
        ctx.stroke(check, with: .foreground, style: stroke)

      case .again:
        var topArrow = Path()
        topArrow.move(to: p(17, 2))
        topArrow.addLine(to: p(21, 6))
        topArrow.addLine(to: p(17, 10))
        ctx.stroke(topArrow, with: .foreground, style: stroke)
        var top = Path()
        top.move(to: p(3, 11))
        top.addLine(to: p(3, 10))
        top.addQuadCurve(to: p(7, 6), control: p(3, 6))
        top.addLine(to: p(21, 6))
        ctx.stroke(top, with: .foreground, style: stroke)
        var bottomArrow = Path()
        bottomArrow.move(to: p(7, 22))
        bottomArrow.addLine(to: p(3, 18))
        bottomArrow.addLine(to: p(7, 14))
        ctx.stroke(bottomArrow, with: .foreground, style: stroke)
        var bottom = Path()
        bottom.move(to: p(21, 13))
        bottom.addLine(to: p(21, 14))
        bottom.addQuadCurve(to: p(17, 18), control: p(21, 18))
        bottom.addLine(to: p(3, 18))
        ctx.stroke(bottom, with: .foreground, style: stroke)
      }
    }
    .frame(width: Theme.Spacing.s22, height: Theme.Spacing.s22)
  }
}

