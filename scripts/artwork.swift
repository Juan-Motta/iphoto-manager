// Draws the app icon and the DMG background as PNG files.
//
//   swift scripts/artwork.swift icon <out.png>            1024×1024 app icon
//   swift scripts/artwork.swift dmg-background <out.png> <scale>   660×400 pt installer window
//
// Used by scripts/make-icon.sh and scripts/build-dmg.sh.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(width: Int, height: Int, scale: CGFloat = 1, to path: String, draw: (CGContext) -> Void) {
    let context = CGContext(data: nil, width: Int(CGFloat(width) * scale), height: Int(CGFloat(height) * scale),
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: scale, y: scale)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(context)
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    rep.size = NSSize(width: width, height: height)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func linear(_ context: CGContext, _ colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// A rounded photo card rotated around its center.
func card(_ context: CGContext, center: CGPoint, size: CGSize, angle: CGFloat, drawContent: (CGContext, CGRect) -> Void) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: angle * .pi / 180)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    drawContent(context, rect)
    context.restoreGState()
}

// MARK: Icon

func drawIcon(_ context: CGContext) {
    // macOS icon grid: 824 pt rounded square centered in the 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.28))
    context.addPath(shape)
    context.setFillColor(color(0x3D6BFF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    linear(context, [color(0x4A8BFF), color(0x5B3FE6)], from: CGPoint(x: 0, y: 924), to: CGPoint(x: 0, y: 100))
    // Soft light from the top, as on glass.
    linear(context, [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)], from: CGPoint(x: 0, y: 924), to: CGPoint(x: 0, y: 560))

    // Back card.
    card(context, center: CGPoint(x: 488, y: 548), size: CGSize(width: 470, height: 380), angle: 11) { context, rect in
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 46, cornerHeight: 46, transform: nil))
        context.setFillColor(color(0xFFFFFF, 0.42))
        context.fillPath()
    }

    // Front photo.
    card(context, center: CGPoint(x: 508, y: 506), size: CGSize(width: 510, height: 410), angle: -5) { context, rect in
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x1B0E5C, 0.40))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 50, cornerHeight: 50, transform: nil))
        context.setFillColor(color(0xFFFFFF))
        context.fillPath()
        context.restoreGState()

        let photo = rect.insetBy(dx: 24, dy: 24)
        context.saveGState()
        context.addPath(CGPath(roundedRect: photo, cornerWidth: 30, cornerHeight: 30, transform: nil))
        context.clip()
        linear(context, [color(0xFF7A9C), color(0xFFC27A)], from: CGPoint(x: 0, y: photo.maxY), to: CGPoint(x: 0, y: photo.minY + photo.height * 0.3))
        context.setFillColor(color(0xFFF4CF))
        context.fillEllipse(in: CGRect(x: photo.minX + photo.width * 0.6, y: photo.minY + photo.height * 0.52, width: 92, height: 92))

        let far = CGMutablePath()
        far.move(to: CGPoint(x: photo.minX, y: photo.minY))
        far.addLine(to: CGPoint(x: photo.minX, y: photo.minY + photo.height * 0.42))
        far.addLine(to: CGPoint(x: photo.minX + photo.width * 0.32, y: photo.minY + photo.height * 0.66))
        far.addLine(to: CGPoint(x: photo.minX + photo.width * 0.58, y: photo.minY + photo.height * 0.36))
        far.addLine(to: CGPoint(x: photo.maxX, y: photo.minY + photo.height * 0.5))
        far.addLine(to: CGPoint(x: photo.maxX, y: photo.minY))
        far.closeSubpath()
        context.addPath(far)
        context.setFillColor(color(0x8C5BB8))
        context.fillPath()

        let near = CGMutablePath()
        near.move(to: CGPoint(x: photo.minX, y: photo.minY))
        near.addLine(to: CGPoint(x: photo.minX, y: photo.minY + photo.height * 0.22))
        near.addLine(to: CGPoint(x: photo.minX + photo.width * 0.55, y: photo.minY + photo.height * 0.4))
        near.addLine(to: CGPoint(x: photo.maxX, y: photo.minY + photo.height * 0.18))
        near.addLine(to: CGPoint(x: photo.maxX, y: photo.minY))
        near.closeSubpath()
        context.addPath(near)
        context.setFillColor(color(0x4B2C83))
        context.fillPath()
        context.restoreGState()
    }

    // Save badge: a white arrow into a tray on a green circle.
    let badge = CGRect(x: 600, y: 196, width: 236, height: 236)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: color(0x0B3D1F, 0.35))
    context.setFillColor(color(0xFFFFFF))
    context.fillEllipse(in: badge)
    context.restoreGState()
    let inner = badge.insetBy(dx: 14, dy: 14)
    context.saveGState()
    context.addEllipse(in: inner)
    context.clip()
    linear(context, [color(0x4CD97B), color(0x1FA851)], from: CGPoint(x: 0, y: inner.maxY), to: CGPoint(x: 0, y: inner.minY))
    context.restoreGState()

    context.setStrokeColor(color(0xFFFFFF))
    context.setLineWidth(24)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    let cx = badge.midX
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: cx, y: badge.minY + 168))
    arrow.addLine(to: CGPoint(x: cx, y: badge.minY + 92))
    arrow.move(to: CGPoint(x: cx - 38, y: badge.minY + 128))
    arrow.addLine(to: CGPoint(x: cx, y: badge.minY + 90))
    arrow.addLine(to: CGPoint(x: cx + 38, y: badge.minY + 128))
    arrow.move(to: CGPoint(x: cx - 62, y: badge.minY + 96))
    arrow.addLine(to: CGPoint(x: cx - 62, y: badge.minY + 62))
    arrow.addLine(to: CGPoint(x: cx + 62, y: badge.minY + 62))
    arrow.addLine(to: CGPoint(x: cx + 62, y: badge.minY + 96))
    context.addPath(arrow)
    context.strokePath()

    context.restoreGState()
}

// MARK: DMG background

/// Window content is 660×400 pt. Finder icon centers: app at (170, 190), Applications at (490, 190), from the top-left.
func drawDMGBackground(_ context: CGContext) {
    let width: CGFloat = 660, height: CGFloat = 400
    linear(context, [color(0xF7F8FC), color(0xE6EBF7)], from: CGPoint(x: 0, y: height), to: CGPoint(x: 0, y: 0))

    // Arrow between the two icons.
    let y = height - 190
    context.setStrokeColor(color(0x5B6BFF, 0.55))
    context.setLineWidth(6)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineDash(phase: 0, lengths: [2, 14])
    context.move(to: CGPoint(x: 262, y: y))
    context.addLine(to: CGPoint(x: 384, y: y))
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])
    context.move(to: CGPoint(x: 376, y: y + 18))
    context.addLine(to: CGPoint(x: 396, y: y))
    context.addLine(to: CGPoint(x: 376, y: y - 18))
    context.strokePath()

    let title = NSAttributedString(string: "Drag Photo Manager to Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.27, alpha: 1),
    ])
    let subtitle = NSAttributedString(string: "Then open it from your Applications folder.", attributes: [
        .font: NSFont.systemFont(ofSize: 13),
        .foregroundColor: NSColor(srgbRed: 0.42, green: 0.45, blue: 0.55, alpha: 1),
    ])
    title.draw(at: CGPoint(x: (width - title.size().width) / 2, y: 74))
    subtitle.draw(at: CGPoint(x: (width - subtitle.size().width) / 2, y: 50))
}

// MARK: Main

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: artwork.swift icon|dmg-background <out.png> [scale]\n".utf8))
    exit(2)
}
switch arguments[1] {
case "icon":
    render(width: 1024, height: 1024, to: arguments[2], draw: drawIcon)
case "dmg-background":
    let scale = arguments.count > 3 ? CGFloat(Double(arguments[3]) ?? 1) : 1
    render(width: 660, height: 400, scale: scale, to: arguments[2], draw: drawDMGBackground)
default:
    exit(2)
}
