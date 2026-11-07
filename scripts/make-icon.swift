// Draws the app icon (1024×1024, opaque, full bleed): the square split like a swipe card, Solo on the orange
// "one" side and the Crew on the blue "many" side.
//
//   swift scripts/make-icon.swift
//
// Writes OneOrMany/Assets.xcassets/AppIcon.appiconset/AppIcon.png. Paths only, no fonts.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                            CGFloat(hex & 0xFF) / 255, 1])!
}
let ink = color(0x1B0F3B), ground = color(0xEFE7FF), dot = color(0xD9CBFA)
let one = color(0xFF7A1F), manyLight = color(0x5B8CFF), manyPale = color(0x8FB0FF)
let oneSide = color(0xFFE0C2), manySide = color(0xD6E2FF)

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downward, like the SwiftUI mascots.
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

// Two sides, split by a slightly tilted line, like a card mid-swipe
let top = CGPoint(x: 572, y: 0), bottom = CGPoint(x: 452, y: 1024)
ctx.setFillColor(oneSide)
ctx.addLines(between: [CGPoint(x: 0, y: 0), top, bottom, CGPoint(x: 0, y: 1024)]); ctx.fillPath()
ctx.setFillColor(manySide)
ctx.addLines(between: [top, CGPoint(x: 1024, y: 0), CGPoint(x: 1024, y: 1024), bottom]); ctx.fillPath()
_ = (ground, dot)
ctx.setStrokeColor(ink); ctx.setLineWidth(16)
ctx.move(to: top); ctx.addLine(to: bottom); ctx.strokePath()

func blob(_ c: CGPoint, _ r: CGFloat, _ fill: CGColor, line: CGFloat, shadow: CGFloat) {
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: c.x - r + shadow, y: c.y - r + shadow, width: 2 * r, height: 2 * r))
    ctx.setFillColor(fill)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ctx.setStrokeColor(ink); ctx.setLineWidth(line)
    ctx.strokeEllipse(in: CGRect(x: c.x - r + line / 2, y: c.y - r + line / 2, width: 2 * r - line, height: 2 * r - line))
}
func eyes(_ pts: [CGPoint], _ r: CGFloat) {
    ctx.setFillColor(ink)
    for p in pts { ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)) }
}
func smile(_ from: CGPoint, _ to: CGPoint, _ control: CGPoint, _ width: CGFloat) {
    ctx.setStrokeColor(ink); ctx.setLineWidth(width); ctx.setLineCap(.round)
    ctx.move(to: from); ctx.addQuadCurve(to: to, control: control); ctx.strokePath()
}

// The Crew (right): two side blobs below, the big one on top
blob(CGPoint(x: 650, y: 700), 108, manyPale, line: 24, shadow: 20)
blob(CGPoint(x: 880, y: 700), 108, manyPale, line: 24, shadow: 20)
eyes([CGPoint(x: 622, y: 724), CGPoint(x: 678, y: 724), CGPoint(x: 852, y: 724), CGPoint(x: 908, y: 724)], 14)
blob(CGPoint(x: 765, y: 470), 160, manyLight, line: 26, shadow: 22)
eyes([CGPoint(x: 722, y: 445), CGPoint(x: 808, y: 445)], 22)
smile(CGPoint(x: 720, y: 520), CGPoint(x: 810, y: 520), CGPoint(x: 765, y: 568), 20)

// Solo (left)
blob(CGPoint(x: 268, y: 530), 200, one, line: 30, shadow: 28)
eyes([CGPoint(x: 212, y: 488), CGPoint(x: 324, y: 488)], 30)
smile(CGPoint(x: 204, y: 580), CGPoint(x: 332, y: 580), CGPoint(x: 268, y: 648), 28)

let url = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("OneOrMany/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("couldn't write \(url.path)") }
print("Wrote \(url.path)")
