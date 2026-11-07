// Draws the App Store creative assets (docs/app-store/creative/):
//   header.png  3840 × 1646 (21:9), product page header: a card mid-swipe between Solo and the Crew
//   search.png  3840 × 2560 (3:2), search results: "Is or are? Swipe it fast." next to real game screenshots
// Opaque PNGs (no alpha), key content centered, per Apple's creative asset specifications.
//
//   swift scripts/make-creative-assets.swift      (run scripts/screenshots.sh first: it uses its screenshots)
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("docs/app-store/creative")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
let ink = hex(0x1B0F3B), ground = hex(0xEFE7FF), dot = hex(0xD9CBFA), white = NSColor.white
let one = hex(0xFF7A1F), oneText = hex(0xC2410C), many = hex(0x2457E8), manyLight = hex(0x5B8CFF), manyPale = hex(0x8FB0FF)
let manyTint = hex(0xEAF0FF), good = hex(0x3DDC97), track = hex(0xD3DCF8), pop = hex(0xFF4FA3), marker = hex(0xFFE14D)

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
    return base
}

/// A canvas with top-left origin, drawn with AppKit.
func render(width: Int, height: Int, to name: String, draw: (CGContext) -> Void) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    let url = outDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("can't write \(url.path)") }
    print("Wrote \(url.path)")
}

// MARK: drawing helpers

func dotGrid(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat, step: CGFloat = 64, r: CGFloat = 6) {
    ctx.setFillColor(ground.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setFillColor(dot.cgColor)
    var y = step / 2
    while y < h { var x = step / 2; while x < w { ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)); x += step }; y += step }
}

/// Fill + ink outline + hard offset shadow (the sticker look).
func sticker(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, fill: NSColor, line: CGFloat, shadow: CGFloat, shadowColor: NSColor = ink) {
    let shadowPath = CGPath(roundedRect: rect.offsetBy(dx: shadow, dy: shadow), cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(shadowPath); ctx.setFillColor(shadowColor.cgColor); ctx.fillPath()
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    let inset = CGPath(roundedRect: rect.insetBy(dx: line / 2, dy: line / 2), cornerWidth: radius - line / 2, cornerHeight: radius - line / 2, transform: nil)
    ctx.addPath(inset); ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(line); ctx.strokePath()
}

func blob(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ fill: NSColor, line: CGFloat, shadow: CGFloat) {
    ctx.setFillColor(ink.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - r + shadow, y: c.y - r + shadow, width: 2 * r, height: 2 * r))
    ctx.setFillColor(fill.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(line)
    ctx.strokeEllipse(in: CGRect(x: c.x - r + line / 2, y: c.y - r + line / 2, width: 2 * r - line, height: 2 * r - line))
}
func eyes(_ ctx: CGContext, _ pts: [CGPoint], _ r: CGFloat) {
    ctx.setFillColor(ink.cgColor)
    for p in pts { ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)) }
}
func smile(_ ctx: CGContext, from: CGPoint, to: CGPoint, control: CGPoint, width: CGFloat) {
    ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(width); ctx.setLineCap(.round)
    ctx.move(to: from); ctx.addQuadCurve(to: to, control: control); ctx.strokePath()
}

/// Solo, centered at c with body radius r.
func solo(_ ctx: CGContext, at c: CGPoint, r: CGFloat, cheer: Bool = false) {
    let k = r / 100
    if cheer {
        ctx.setStrokeColor(ink.cgColor); ctx.setLineWidth(14 * k); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x - 82 * k, y: c.y - 20 * k)); ctx.addLine(to: CGPoint(x: c.x - 135 * k, y: c.y - 110 * k))
        ctx.move(to: CGPoint(x: c.x + 82 * k, y: c.y - 20 * k)); ctx.addLine(to: CGPoint(x: c.x + 135 * k, y: c.y - 110 * k))
        ctx.strokePath()
    }
    blob(ctx, c, r, one, line: 14 * k, shadow: 13 * k)
    eyes(ctx, [CGPoint(x: c.x - 28 * k, y: c.y - 20 * k), CGPoint(x: c.x + 28 * k, y: c.y - 20 * k)], 14 * k)
    smile(ctx, from: CGPoint(x: c.x - 33 * k, y: c.y + 26 * k), to: CGPoint(x: c.x + 33 * k, y: c.y + 26 * k),
          control: CGPoint(x: c.x, y: c.y + 60 * k), width: 13 * k)
}

/// The Crew, centered at c, sized by the big blob's radius r.
func crew(_ ctx: CGContext, at c: CGPoint, r: CGFloat) {
    let k = r / 100
    let left = CGPoint(x: c.x - 72 * k, y: c.y + 66 * k), right = CGPoint(x: c.x + 72 * k, y: c.y + 66 * k)
    blob(ctx, left, 68 * k, manyPale, line: 12 * k, shadow: 11 * k)
    blob(ctx, right, 68 * k, manyPale, line: 12 * k, shadow: 11 * k)
    eyes(ctx, [CGPoint(x: left.x - 18 * k, y: left.y + 14 * k), CGPoint(x: left.x + 18 * k, y: left.y + 14 * k),
               CGPoint(x: right.x - 18 * k, y: right.y + 14 * k), CGPoint(x: right.x + 18 * k, y: right.y + 14 * k)], 9 * k)
    blob(ctx, c, r, manyLight, line: 14 * k, shadow: 13 * k)
    eyes(ctx, [CGPoint(x: c.x - 27 * k, y: c.y - 16 * k), CGPoint(x: c.x + 27 * k, y: c.y - 16 * k)], 13 * k)
    smile(ctx, from: CGPoint(x: c.x - 28 * k, y: c.y + 26 * k), to: CGPoint(x: c.x + 28 * k, y: c.y + 26 * k),
          control: CGPoint(x: c.x, y: c.y + 56 * k), width: 12 * k)
}

/// Text with an ink outline and a hard shadow, left-aligned at `at` (top-left). Returns its size.
@discardableResult
func stickerText(_ s: String, at: CGPoint, size: CGFloat, fill: NSColor, stroke: CGFloat, shadow: CGFloat, shadowColor: NSColor = ink) -> CGSize {
    let font = roundedFont(size, .black)
    let shadowAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: shadowColor, .strokeColor: shadowColor, .strokeWidth: -stroke]
    NSAttributedString(string: s, attributes: shadowAttrs).draw(at: CGPoint(x: at.x + shadow, y: at.y + shadow))
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fill, .strokeColor: ink, .strokeWidth: -stroke]
    let str = NSAttributedString(string: s, attributes: attrs)
    str.draw(at: at)
    return str.size()
}

func text(_ s: String, at: CGPoint, size: CGFloat, weight: NSFont.Weight = .semibold, color: NSColor = ink, kern: CGFloat = 0) -> CGSize {
    let str = NSAttributedString(string: s, attributes: [.font: roundedFont(size, weight), .foregroundColor: color, .kern: kern])
    str.draw(at: at)
    return str.size()
}

func textSize(_ s: String, size: CGFloat, weight: NSFont.Weight) -> CGSize {
    NSAttributedString(string: s, attributes: [.font: roundedFont(size, weight)]).size()
}

/// Answer button: side color, arrow, the word and ONE/MANY under it.
func answerButton(_ ctx: CGContext, _ rect: CGRect, word: String, label: String, fill: NSColor, textColor: NSColor, left: Bool, k: CGFloat) {
    sticker(ctx, rect, radius: 60 * k, fill: fill, line: 12 * k, shadow: 16 * k)
    let wordSize = textSize(word, size: 120 * k, weight: .black)
    let labelSize = textSize(label, size: 40 * k, weight: .heavy)
    let arrow = left ? "←" : "→"
    let arrowSize = textSize(arrow, size: 100 * k, weight: .black)
    let blockW = max(wordSize.width, labelSize.width + 6 * k * CGFloat(label.count))
    let total = arrowSize.width + 30 * k + blockW
    var x = rect.midX - total / 2
    let top = rect.midY - (wordSize.height + labelSize.height - 20 * k) / 2
    if left {
        _ = text(arrow, at: CGPoint(x: x, y: rect.midY - arrowSize.height / 2), size: 100 * k, weight: .black, color: textColor)
        x += arrowSize.width + 30 * k
        _ = text(word, at: CGPoint(x: x, y: top), size: 120 * k, weight: .black, color: textColor)
        _ = text(label, at: CGPoint(x: x + 4 * k, y: top + wordSize.height - 20 * k), size: 40 * k, weight: .heavy, color: textColor, kern: 6 * k)
    } else {
        _ = text(word, at: CGPoint(x: x + blockW - wordSize.width, y: top), size: 120 * k, weight: .black, color: textColor)
        _ = text(label, at: CGPoint(x: x + blockW - labelSize.width - 6 * k * CGFloat(label.count), y: top + wordSize.height - 20 * k),
                 size: 40 * k, weight: .heavy, color: textColor, kern: 6 * k)
        _ = text(arrow, at: CGPoint(x: x + blockW + 30 * k, y: rect.midY - arrowSize.height / 2), size: 100 * k, weight: .black, color: textColor)
    }
}

/// The game card mid-swipe toward MANY, drawn in its own coordinate system (rotated around its center).
func swipeCard(_ ctx: CGContext, center: CGPoint, size: CGSize, angle: CGFloat, k: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: angle * .pi / 180)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    // the card behind
    ctx.saveGState(); ctx.rotate(by: -7 * .pi / 180)
    sticker(ctx, rect.insetBy(dx: 30 * k, dy: 30 * k), radius: 90 * k, fill: white, line: 12 * k, shadow: 14 * k)
    ctx.restoreGState()
    sticker(ctx, rect, radius: 90 * k, fill: manyTint, line: 14 * k, shadow: 30 * k, shadowColor: many)
    // speed bar
    let bar = CGRect(x: rect.minX + 80 * k, y: rect.minY + 80 * k, width: rect.width - 280 * k, height: 32 * k)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 16 * k, cornerHeight: 16 * k, transform: nil)); ctx.setFillColor(track.cgColor); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * 0.78, height: bar.height), cornerWidth: 16 * k, cornerHeight: 16 * k, transform: nil))
    ctx.setFillColor(good.cgColor); ctx.fillPath()
    _ = text("+42", at: CGPoint(x: bar.maxX + 30 * k, y: bar.minY - 14 * k), size: 50 * k, weight: .heavy)
    // MANY stamp
    ctx.saveGState()
    ctx.translateBy(x: rect.minX + 260 * k, y: rect.minY + 250 * k); ctx.rotate(by: -14 * .pi / 180)
    let stampSize = textSize("MANY", size: 100 * k, weight: .black)
    let stamp = CGRect(x: -stampSize.width / 2 - 40 * k, y: -stampSize.height / 2 - 10 * k, width: stampSize.width + 80 * k, height: stampSize.height + 20 * k)
    ctx.addPath(CGPath(roundedRect: stamp, cornerWidth: 34 * k, cornerHeight: 34 * k, transform: nil)); ctx.setFillColor(white.cgColor); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: stamp.insetBy(dx: 8 * k, dy: 8 * k), cornerWidth: 28 * k, cornerHeight: 28 * k, transform: nil))
    ctx.setStrokeColor(many.cgColor); ctx.setLineWidth(16 * k); ctx.strokePath()
    _ = text("MANY", at: CGPoint(x: -stampSize.width / 2, y: -stampSize.height / 2), size: 100 * k, weight: .black, color: many)
    ctx.restoreGState()
    // sentence: "The cars [are] stopped at the light."
    let fs = 118 * k
    let line1a = "The cars ", word = "are", line2 = "stopped at the light."
    let a = textSize(line1a, size: fs, weight: .medium), w = textSize(word, size: fs, weight: .heavy)
    let blank = max(w.width + 40 * k, 260 * k)
    let l1 = a.width + blank
    let y1 = rect.midY - 40 * k
    let x1 = -l1 / 2
    _ = text(line1a, at: CGPoint(x: x1, y: y1), size: fs, weight: .medium)
    _ = text(word, at: CGPoint(x: x1 + a.width + (blank - w.width) / 2, y: y1), size: fs, weight: .heavy, color: many)
    ctx.setStrokeColor(many.cgColor); ctx.setLineWidth(12 * k); ctx.setLineDash(phase: 0, lengths: [30 * k, 18 * k])
    ctx.move(to: CGPoint(x: x1 + a.width, y: y1 + a.height - 2 * k)); ctx.addLine(to: CGPoint(x: x1 + a.width + blank, y: y1 + a.height - 2 * k)); ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    let l2 = textSize(line2, size: fs, weight: .medium)
    _ = text(line2, at: CGPoint(x: -l2.width / 2, y: y1 + a.height + 30 * k), size: fs, weight: .medium)
    ctx.restoreGState()
}

// MARK: Header (21:9)

render(width: 3840, height: 1646, to: "header.png") { ctx in
    let W: CGFloat = 3840, H: CGFloat = 1646
    dotGrid(ctx, W, H)
    let k: CGFloat = 1.0
    // Solo and "is" on the left, the Crew and "are" on the right, the card in the middle
    solo(ctx, at: CGPoint(x: 980, y: 560), r: 230)
    answerButton(ctx, CGRect(x: 690, y: 960, width: 580, height: 260), word: "is", label: "ONE", fill: one, textColor: ink, left: true, k: k)
    crew(ctx, at: CGPoint(x: 2860, y: 520), r: 190)
    answerButton(ctx, CGRect(x: 2570, y: 960, width: 580, height: 260), word: "are", label: "MANY", fill: many, textColor: white, left: false, k: k)
    swipeCard(ctx, center: CGPoint(x: 1960, y: 800), size: CGSize(width: 1180, height: 1180), angle: 6, k: 1)
}

// MARK: Search results (3:2)

func phone(_ ctx: CGContext, image: String, center: CGPoint, height: CGFloat, angle: CGFloat) {
    guard let img = NSImage(contentsOf: root.appendingPathComponent(image)) else { fatalError("missing \(image); run scripts/screenshots.sh") }
    let width = height * img.size.width / img.size.height
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: angle * .pi / 180)
    let screen = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
    let bezel = screen.insetBy(dx: -34, dy: -34)
    sticker(ctx, bezel, radius: 190, fill: ink, line: 0.1, shadow: 34, shadowColor: many)
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 150, cornerHeight: 150, transform: nil)); ctx.clip()
    img.draw(in: screen, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    ctx.restoreGState()
}

render(width: 3840, height: 2560, to: "search.png") { ctx in
    let W: CGFloat = 3840, H: CGFloat = 2560
    dotGrid(ctx, W, H, step: 72, r: 7)
    // Real screenshots on the right
    phone(ctx, image: "docs/app-store/iphone-6.3/03-streak.png", center: CGPoint(x: 3180, y: 1300), height: 2020, angle: 7)
    phone(ctx, image: "docs/app-store/iphone-6.3/01-card.png", center: CGPoint(x: 2470, y: 1290), height: 2160, angle: -5)
    // Headline on the left
    var x: CGFloat = 230
    let y: CGFloat = 470
    x += stickerText("Is", at: CGPoint(x: x, y: y), size: 330, fill: one, stroke: 5, shadow: 22).width + 40
    x += stickerText("or", at: CGPoint(x: x, y: y + 90), size: 200, fill: ink, stroke: 0, shadow: 0).width + 40
    stickerText("are?", at: CGPoint(x: x, y: y), size: 330, fill: manyLight, stroke: 5, shadow: 22)
    stickerText("Swipe it fast.", at: CGPoint(x: 230, y: y + 400), size: 210, fill: white, stroke: 5, shadow: 16)
    _ = text("Left for one, right for many.", at: CGPoint(x: 240, y: y + 700), size: 104, weight: .bold)
    // The two answers, and the mascots
    answerButton(ctx, CGRect(x: 240, y: 1500, width: 640, height: 290), word: "is", label: "ONE", fill: one, textColor: ink, left: true, k: 1.1)
    answerButton(ctx, CGRect(x: 960, y: 1500, width: 640, height: 290), word: "are", label: "MANY", fill: many, textColor: white, left: false, k: 1.1)
    solo(ctx, at: CGPoint(x: 560, y: 2140), r: 190, cheer: true)
    crew(ctx, at: CGPoint(x: 1300, y: 2090), r: 150)
}
