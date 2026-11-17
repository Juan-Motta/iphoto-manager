// Builds the app icon and draws the DMG background as PNG files.
//
//   swift scripts/artwork.swift icon <source.png> <out.png>   1024×1024 app icon from the artwork
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

/// The tile inside App/Resources/AppIcon-source.png (the original artwork, on a grey backdrop),
/// in pixels from the top-left, inset a few pixels so no backdrop shows at the edges.
let sourceTile = CGRect(x: 153, y: 133, width: 539, height: 547)

/// Places the artwork's tile on the macOS icon grid: an 824 pt rounded square in a 1024 canvas.
func drawIcon(from sourcePath: String) -> (CGContext) -> Void {
    let source = NSImage(contentsOfFile: sourcePath)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let tile = source.cropping(to: sourceTile)!
    return { context in
        let frame = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = CGPath(roundedRect: frame, cornerWidth: 185, cornerHeight: 185, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.18))
        context.addPath(shape)
        context.setFillColor(color(0xFFFFFF))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(shape)
        context.clip()
        context.interpolationQuality = .high
        context.draw(tile, in: frame)
        context.restoreGState()
    }
}

// MARK: DMG background

/// Window content is 660×400 pt. Finder icon centers: app at (170, 190), Applications at (490, 190), from the top-left.
func drawDMGBackground(_ context: CGContext) {
    let width: CGFloat = 660, height: CGFloat = 400
    linear(context, [color(0xF7F8FC), color(0xE6EBF7)], from: CGPoint(x: 0, y: height), to: CGPoint(x: 0, y: 0))

    // Arrow between the two icons.
    let y = height - 190
    context.setStrokeColor(color(0x13B8D6, 0.6))
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
    FileHandle.standardError.write(Data("usage: artwork.swift icon <source.png> <out.png> | dmg-background <out.png> [scale]\n".utf8))
    exit(2)
}
switch arguments[1] {
case "icon" where arguments.count >= 4:
    render(width: 1024, height: 1024, to: arguments[3], draw: drawIcon(from: arguments[2]))
case "dmg-background":
    let scale = arguments.count > 3 ? CGFloat(Double(arguments[3]) ?? 1) : 1
    render(width: 660, height: 400, scale: scale, to: arguments[2], draw: drawDMGBackground)
default:
    exit(2)
}
