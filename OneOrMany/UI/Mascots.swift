import SwiftUI

enum MascotMood {
    case happy, cheer, unsure, determined
}

/// Solo: one orange blob. Always means ONE and lives on the left (STYLE §6).
struct SoloView: View {
    var mood: MascotMood = .happy
    var outline: Color = Palette.ink

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 64
            ctx.translateBy(x: (size.width - 64 * s) / 2, y: (size.height - 64 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            let ink = GraphicsContext.Shading.color(Palette.ink)
            let line = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)

            if mood == .cheer {
                var arms = Path()
                arms.move(to: CGPoint(x: 10, y: 34)); arms.addLine(to: CGPoint(x: 2, y: 14))
                arms.move(to: CGPoint(x: 54, y: 34)); arms.addLine(to: CGPoint(x: 62, y: 14))
                ctx.stroke(arms, with: .color(outline), style: line)
            }
            let body = Path(ellipseIn: CGRect(x: 5, y: 5, width: 54, height: 55))
            ctx.fill(body, with: .color(Palette.one))
            ctx.stroke(body, with: .color(outline), style: line)

            switch mood {
            case .cheer:
                var eyes = Path()
                eyes.move(to: CGPoint(x: 19, y: 30)); eyes.addQuadCurve(to: CGPoint(x: 29, y: 30), control: CGPoint(x: 24, y: 23))
                eyes.move(to: CGPoint(x: 35, y: 30)); eyes.addQuadCurve(to: CGPoint(x: 45, y: 30), control: CGPoint(x: 40, y: 23))
                ctx.stroke(eyes, with: ink, style: line)
                var mouth = Path()
                mouth.move(to: CGPoint(x: 22, y: 38)); mouth.addLine(to: CGPoint(x: 42, y: 38))
                mouth.addQuadCurve(to: CGPoint(x: 22, y: 38), control: CGPoint(x: 32, y: 56))
                ctx.fill(mouth, with: ink)
            default:
                ctx.fill(Path(ellipseIn: CGRect(x: 19.5, y: 24.5, width: 9, height: 9)), with: ink)
                ctx.fill(Path(ellipseIn: CGRect(x: 35.5, y: 24.5, width: 9, height: 9)), with: ink)
                var mouth = Path()
                switch mood {
                case .unsure, .determined:
                    mouth.move(to: CGPoint(x: 24, y: 42)); mouth.addLine(to: CGPoint(x: 40, y: 42))
                default:
                    mouth.move(to: CGPoint(x: 23, y: 40)); mouth.addQuadCurve(to: CGPoint(x: 41, y: 40), control: CGPoint(x: 32, y: 49))
                }
                ctx.stroke(mouth, with: ink, style: line)
                if mood == .determined {
                    var brows = Path()
                    brows.move(to: CGPoint(x: 17, y: 20)); brows.addLine(to: CGPoint(x: 28, y: 24))
                    brows.move(to: CGPoint(x: 47, y: 20)); brows.addLine(to: CGPoint(x: 36, y: 24))
                    ctx.stroke(brows, with: ink, style: line)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The Crew: three blue blobs. Always means MANY and lives on the right.
struct CrewView: View {
    var mood: MascotMood = .happy
    var outline: Color = Palette.ink

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 96, size.height / 70)
            ctx.translateBy(x: (size.width - 96 * s) / 2, y: (size.height - 70 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            let ink = GraphicsContext.Shading.color(Palette.ink)
            let line = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)

            let blobs: [(CGPoint, CGFloat, Color)] = [
                (CGPoint(x: 20, y: 44), 17, Palette.manyPale),
                (CGPoint(x: 76, y: 44), 17, Palette.manyPale),
                (CGPoint(x: 48, y: 34), 22, Palette.manyLight),
            ]
            for (c, r, color) in blobs {
                let p = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(p, with: .color(color))
                ctx.stroke(p, with: .color(outline), style: line)
            }
            let eyes: [(CGFloat, CGFloat, CGFloat)] = [(15, 42, 3), (25, 42, 3), (71, 42, 3), (81, 42, 3), (41, 31, 3.6), (55, 31, 3.6)]
            if mood == .cheer {
                var arcs = Path()
                for (x, y, _) in eyes {
                    arcs.move(to: CGPoint(x: x - 3, y: y + 1)); arcs.addQuadCurve(to: CGPoint(x: x + 3, y: y + 1), control: CGPoint(x: x, y: y - 4))
                }
                ctx.stroke(arcs, with: ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            } else {
                for (x, y, r) in eyes { ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: ink) }
            }
            var mouth = Path()
            switch mood {
            case .cheer:
                mouth.addEllipse(in: CGRect(x: 42, y: 38, width: 12, height: 10))
                ctx.fill(mouth, with: ink)
            case .unsure, .determined:
                mouth.move(to: CGPoint(x: 41, y: 43)); mouth.addLine(to: CGPoint(x: 55, y: 43))
                ctx.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            case .happy:
                mouth.move(to: CGPoint(x: 41, y: 41)); mouth.addQuadCurve(to: CGPoint(x: 55, y: 41), control: CGPoint(x: 48, y: 47))
                ctx.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
            if mood == .determined {
                var brows = Path()
                brows.move(to: CGPoint(x: 37, y: 23)); brows.addLine(to: CGPoint(x: 45, y: 26))
                brows.move(to: CGPoint(x: 59, y: 23)); brows.addLine(to: CGPoint(x: 51, y: 26))
                ctx.stroke(brows, with: ink, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            }
        }
        .aspectRatio(96.0 / 70.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Mascot for a side, so the "Solo left / Crew right" rule lives in one place.
struct SideMascot: View {
    let side: Side
    var mood: MascotMood = .happy
    var outline: Color = Palette.ink

    var body: some View {
        if side == .one { SoloView(mood: mood, outline: outline) } else { CrewView(mood: mood, outline: outline) }
    }
}
