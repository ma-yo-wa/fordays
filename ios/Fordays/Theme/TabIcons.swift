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
