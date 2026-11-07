import SwiftUI

/// Five-point star used for round stars (STYLE §5.7).
struct StarShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let pts: [(CGFloat, CGFloat)] = [(50, 4), (61, 38), (97, 38), (68, 59), (79, 93), (50, 72), (21, 93), (32, 59), (3, 38), (39, 38)]
        var p = Path()
        for (i, (x, y)) in pts.enumerated() {
            let pt = CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 100 * r.height)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> StarShape { StarShape(inset: inset + amount) }
}

struct StarView: View {
    var filled: Bool
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            StarShape().fill(filled ? Palette.marker : Palette.surface)
            StarShape().stroke(filled ? Palette.ink : Palette.lockedLine,
                               style: StrokeStyle(lineWidth: size * 0.06, lineJoin: .round, dash: filled ? [] : [size * 0.08, size * 0.06]))
        }
        .frame(width: size, height: size)
    }
}

struct StarsRow: View {
    var count: Int
    var size: CGFloat = 18
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { StarView(filled: $0 < count, size: size) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

/// Multiplier chip in the HUD (STYLE §5.1).
struct StreakChip: View {
    var streak: Int
    var colors: ScreenColors

    var body: some View {
        let m = Scoring.multiplier(streak: streak)
        let label = "×" + (m == 1.5 ? "1.5" : String(Int(m)))
        HStack(spacing: 5) {
            if m > 1 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(m >= 2 ? Palette.pop : Palette.marker)
            }
            Text(label).font(Theme.body(15, .heavy))
            Text("· \(streak)").font(Theme.body(13, .semibold))
        }
        .foregroundStyle(m == 1 ? (streak == 0 ? colors.muted : Palette.ink) : Palette.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .modifier(chipBackground(m: m))
        .scaleEffect(m >= 3 ? 1.2 : (m >= 2 ? 1.12 : 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: m)
        .accessibilityLabel("Streak \(streak), points times \(label.dropFirst())")
    }

    private func chipBackground(m: Double) -> StickerBackground<Capsule> {
        switch m {
        case 3...: return StickerBackground(shape: Capsule(), fill: Palette.marker, stroke: 3, shadow: 3, shadowColor: Palette.pop)
        case 2...: return StickerBackground(shape: Capsule(), fill: Palette.marker, stroke: 3, shadow: 3)
        case 1.5...: return StickerBackground(shape: Capsule(), fill: Palette.pop, stroke: 3, shadow: 3)
        default:
            return StickerBackground(shape: Capsule(), fill: colors.controlFill == Palette.nightGround ? Palette.surface : Palette.surface,
                                     stroke: 3, shadow: streak == 0 ? 0 : 3, strokeColor: streak == 0 ? Palette.inkMuted : Palette.ink,
                                     dashed: streak == 0)
        }
    }
}

struct RoundProgressBar: View {
    var fraction: Double
    var fill: Color = Palette.one
    var track: Color = Palette.surface
    var line: Color = Palette.ink

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Rectangle().fill(fill)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .overlay(alignment: .trailing) { Rectangle().fill(line).frame(width: fraction > 0 && fraction < 1 ? 2.5 : 0) }
            }
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(line, lineWidth: 2.5) }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

/// White stat tile used on summary and stats screens.
struct StatTile: View {
    let label: String
    let value: String
    var note: String? = nil
    var noteColor: Color = Palette.inkMuted

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: label).font(Theme.label(10))
            Text(value).font(Theme.display(26)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let note { Text(note).font(Theme.body(12, .semibold)).foregroundStyle(noteColor) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .sticker(Palette.surface, radius: 18, shadow: 3)
        .accessibilityElement(children: .combine)
    }
}

enum MainTab: Hashable { case play, stats, scores }

/// The bottom tab bar (STYLE §5.6).
struct MainTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 8) {
            tab(.play, "Play", "play.fill")
            tab(.stats, "Stats", "chart.bar.fill")
            tab(.scores, "Scores", "trophy.fill")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            Palette.surface
                .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 3) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ t: MainTab, _ title: String, _ icon: String) -> some View {
        let on = selection == t
        return Button {
            selection = t
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(title).font(Theme.body(14, on ? .heavy : .bold))
            }
            .foregroundStyle(on ? Palette.ink : Palette.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.one)
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Small round icon button with ink outline (pause, back, settings).
struct CircleIconButton: View {
    let systemName: String
    let label: String
    var fill: Color = Palette.surface
    var tint: Color = Palette.ink
    var line: Color = Palette.ink
    var size: CGFloat = 42
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(StickerButtonStyle(fill: fill, shadow: 0, strokeColor: line, circle: true))
        .accessibilityLabel(label)
    }
}
