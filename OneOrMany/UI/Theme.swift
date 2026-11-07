import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Color tokens from docs/STYLE.md §2.
enum Palette {
    static let ground = Color(hex: 0xEFE7FF)
    static let groundDot = Color(hex: 0xD9CBFA)
    static let ink = Color(hex: 0x1B0F3B)
    static let inkMuted = Color(hex: 0x5A4C80)
    static let surface = Color.white
    static let one = Color(hex: 0xFF7A1F)
    static let oneText = Color(hex: 0xC2410C)
    static let oneTint = Color(hex: 0xFFF1E6)
    static let many = Color(hex: 0x2457E8)
    static let manyLight = Color(hex: 0x5B8CFF)
    static let manyPale = Color(hex: 0x8FB0FF)
    static let manyTint = Color(hex: 0xEAF0FF)
    static let manyTrack = Color(hex: 0xD3DCF8)
    static let marker = Color(hex: 0xFFE14D)
    static let pop = Color(hex: 0xFF4FA3)
    static let good = Color(hex: 0x3DDC97)
    static let goodText = Color(hex: 0x1B7A4F)
    static let bad = Color(hex: 0xFF5A4E)
    static let lockedFill = Color(hex: 0xDCD0F7)
    static let lockedLine = Color(hex: 0x8A7DB5)

    static let nightGround = Color(hex: 0x1B0F3B)
    static let nightDot = Color(hex: 0x33235F)
    static let nightSurface = Color(hex: 0x2E1F5A)
    static let nightText = Color.white
    static let nightMuted = Color(hex: 0xC9BEF0)
    static let nightDim = Color(hex: 0x6E5FA0)

    static let streakGround = Color(hex: 0xFFE9F4)
    static let streakDot = Color(hex: 0xFFC4E1)
    static let streakMuted = Color(hex: 0x6B3557)

    static func side(_ side: Side) -> Color { side == .one ? one : many }
    static func sideText(_ side: Side) -> Color { side == .one ? oneText : many }
    static func sideTint(_ side: Side) -> Color { side == .one ? oneTint : manyTint }
}

/// The colors a screen is drawn in: day, night (timed modes) or streak (×2 and up).
struct ScreenColors {
    var ground: Color
    var dot: Color
    var text: Color
    var muted: Color
    var controlFill: Color
    var controlLine: Color
    var buttonShadow: Color

    static let day = ScreenColors(ground: Palette.ground, dot: Palette.groundDot, text: Palette.ink, muted: Palette.inkMuted,
                                  controlFill: Palette.surface, controlLine: Palette.ink, buttonShadow: Palette.ink)
    static let night = ScreenColors(ground: Palette.nightGround, dot: Palette.nightDot, text: Palette.nightText, muted: Palette.nightMuted,
                                    controlFill: Palette.nightGround, controlLine: Palette.nightText, buttonShadow: Palette.nightText)
    static let streak = ScreenColors(ground: Palette.streakGround, dot: Palette.streakDot, text: Palette.ink, muted: Palette.streakMuted,
                                     controlFill: Palette.surface, controlLine: Palette.ink, buttonShadow: Palette.ink)
}

/// Fonts from docs/STYLE.md §3. Falls back to SF Rounded if the bundled fonts are missing.
enum Theme {
    static let displayFontName = "BagelFatOne-Regular"
    static let bodyFamily = "Lexend"

    static var hasDisplayFont: Bool { UIFont(name: displayFontName, size: 12) != nil }
    static var hasBodyFont: Bool { UIFont.familyNames.contains(bodyFamily) }

    static func display(_ size: CGFloat) -> Font {
        hasDisplayFont ? .custom(displayFontName, fixedSize: size) : .system(size: size, weight: .black, design: .rounded)
    }

    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        hasBodyFont ? .custom(bodyFamily, fixedSize: size).weight(weight) : .system(size: size, weight: weight, design: .rounded)
    }

    /// Small uppercase labels (SCORE, CARD, ONE, MANY).
    static func label(_ size: CGFloat = 11) -> Font { body(size, .heavy) }
}

// MARK: - Sticker look

/// Fill + ink outline + hard (unblurred) offset shadow.
struct StickerBackground<S: InsettableShape>: ViewModifier {
    var shape: S
    var fill: Color
    var stroke: CGFloat = 3
    var shadow: CGFloat = 4
    var shadowColor: Color = Palette.ink
    var strokeColor: Color = Palette.ink
    var dashed = false

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if shadow > 0 { shape.fill(shadowColor).offset(x: shadow, y: shadow) }
                    shape.fill(fill)
                }
            }
            .overlay {
                shape.strokeBorder(strokeColor, style: StrokeStyle(lineWidth: stroke, dash: dashed ? [6, 5] : []))
            }
    }
}

extension View {
    func sticker(_ fill: Color, radius: CGFloat = 20, stroke: CGFloat = 3, shadow: CGFloat = 4,
                 shadowColor: Color = Palette.ink, strokeColor: Color = Palette.ink, dashed: Bool = false) -> some View {
        modifier(StickerBackground(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), fill: fill, stroke: stroke,
                                   shadow: shadow, shadowColor: shadowColor, strokeColor: strokeColor, dashed: dashed))
    }

    func stickerCapsule(_ fill: Color, stroke: CGFloat = 3, shadow: CGFloat = 3, shadowColor: Color = Palette.ink,
                        strokeColor: Color = Palette.ink, dashed: Bool = false) -> some View {
        modifier(StickerBackground(shape: Capsule(), fill: fill, stroke: stroke, shadow: shadow, shadowColor: shadowColor,
                                   strokeColor: strokeColor, dashed: dashed))
    }

    func stickerCircle(_ fill: Color, stroke: CGFloat = 3, shadow: CGFloat = 3, shadowColor: Color = Palette.ink,
                       strokeColor: Color = Palette.ink) -> some View {
        modifier(StickerBackground(shape: Circle(), fill: fill, stroke: stroke, shadow: shadow, shadowColor: shadowColor,
                                   strokeColor: strokeColor))
    }
}

/// A sticker button that "presses into the page": it moves by the shadow offset and the shadow disappears.
struct StickerButtonStyle: ButtonStyle {
    var fill: Color
    var radius: CGFloat = 18
    var shadow: CGFloat = 4
    var shadowColor: Color = Palette.ink
    var strokeColor: Color = Palette.ink
    var circle = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        Group {
            if circle {
                configuration.label
                    .stickerCircle(fill, shadow: pressed ? 0 : shadow, shadowColor: shadowColor, strokeColor: strokeColor)
            } else {
                configuration.label
                    .sticker(fill, radius: radius, shadow: pressed ? 0 : shadow, shadowColor: shadowColor, strokeColor: strokeColor)
            }
        }
        .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
        .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Hero text: fill + ink outline + hard shadow (STYLE §3).
struct StickerText: View {
    let text: String
    var size: CGFloat
    var fill: Color
    var stroke: CGFloat = 2.5
    var shadow: CGFloat = 3
    var shadowColor: Color = Palette.ink

    var body: some View {
        let base = Text(text).font(Theme.display(size)).multilineTextAlignment(.center)
        ZStack {
            base.foregroundStyle(shadowColor).offset(x: shadow + stroke * 0.5, y: shadow + stroke * 0.5)
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                base.foregroundStyle(Palette.ink).offset(x: cos(a) * stroke, y: sin(a) * stroke)
            }
            base.foregroundStyle(fill)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Background dot grid (1.5 pt dots every 22 pt).
struct DotGrid: View {
    var ground: Color
    var dot: Color

    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 22
            var y: CGFloat = 11
            while y < size.height {
                var x: CGFloat = 11
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(dot))
                    x += step
                }
                y += step
            }
        }
        .background(ground)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = Palette.inkMuted
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(12))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}
