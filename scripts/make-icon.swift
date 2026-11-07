// Draws the app icon (1024×1024, opaque, full bleed): Solo and the Crew on the lilac dot grid.
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

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downward, like the SwiftUI mascots.
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

ctx.setFillColor(ground); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.setFillColor(dot)
for y in stride(from: 32, to: size, by: 64) { for x in stride(from: 32, to: size, by: 64) {
    ctx.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
} }

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
blob(CGPoint(x: 590, y: 690), 120, manyPale, line: 24, shadow: 20)
blob(CGPoint(x: 850, y: 690), 120, manyPale, line: 24, shadow: 20)
eyes([CGPoint(x: 560, y: 720), CGPoint(x: 620, y: 720), CGPoint(x: 820, y: 720), CGPoint(x: 880, y: 720)], 15)
blob(CGPoint(x: 720, y: 480), 170, manyLight, line: 26, shadow: 22)
eyes([CGPoint(x: 675, y: 455), CGPoint(x: 765, y: 455)], 22)
smile(CGPoint(x: 675, y: 530), CGPoint(x: 765, y: 530), CGPoint(x: 720, y: 580), 20)

// Solo (left, in front)
blob(CGPoint(x: 300, y: 560), 215, one, line: 30, shadow: 28)
eyes([CGPoint(x: 240, y: 515), CGPoint(x: 360, y: 515)], 32)
smile(CGPoint(x: 230, y: 615), CGPoint(x: 370, y: 615), CGPoint(x: 300, y: 685), 28)

let url = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("OneOrMany/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("couldn't write \(url.path)") }
print("Wrote \(url.path)")
