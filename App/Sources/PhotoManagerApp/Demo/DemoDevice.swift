import CoreGraphics
import Foundation
import ImageIO
import PhotoManagerCore
import UniformTypeIdentifiers

/// A fake iPhone with generated pictures. Used only for README screenshots
/// (`PHOTO_MANAGER_DEMO=<scene>`), so no real photos ever appear in the docs.
@MainActor
final class DemoDeviceMonitor: DeviceMonitor {
    private let connects: Bool

    init(connects: Bool) {
        self.connects = connects
    }

    func events() -> AsyncStream<DeviceEvent> {
        let connects = connects
        return AsyncStream { continuation in
            if connects { continuation.yield(.connected(DemoDeviceSession())) }
            // Keep the stream open, like a real monitor waiting for more devices.
        }
    }
}

actor DemoDeviceSession: DeviceSession {
    private var items: [MediaItem] = DemoLibrary.make()

    var info: DeviceInfo {
        DeviceInfo(
            id: "demo-iphone",
            name: "Alex’s iPhone",
            model: "iPhone 16 Pro",
            connection: "USB",
            batteryLevel: 82,
            iCloudPhotosEnabled: false,
            access: .ready
        )
    }

    func loadLibrary() async throws -> [MediaItem] { items }

    func thumbnail(for item: MediaItem, maxPixelSize: Int) async -> Data? {
        DemoArt.image(for: item, longestSide: maxPixelSize)
    }

    func download(_ item: MediaItem, into folder: URL) async throws -> URL {
        // Paced so the progress screen has something to show.
        try await Task.sleep(for: .milliseconds(450))
        let url = folder.appending(path: item.fileName)
        try (DemoArt.image(for: item, longestSide: 2400) ?? Data()).write(to: url)
        return url
    }

    func delete(_ toDelete: [MediaItem]) async -> Set<MediaItem.ID> {
        let ids = Set(toDelete.map(\.id))
        items.removeAll { ids.contains($0.id) }
        return ids
    }

    func eject() async {}
}

/// Deterministic sample library: five days of photos, videos and screenshots, newest first.
enum DemoLibrary {
    static func make() -> [MediaItem] {
        var random = SeededRandom(seed: 7)
        let now = Date()
        let perDay = [14, 11, 9, 12, 8]
        var items: [MediaItem] = []
        var number = 4210
        for (day, count) in perDay.enumerated() {
            for index in 0..<count {
                number -= 1
                let date = now.addingTimeInterval(-Double(day) * 86_400 - Double(index) * 1_700)
                let roll = random.next() % 100
                let item: MediaItem
                if roll < 14 {
                    item = MediaItem(id: "demo-\(number)", fileName: "IMG_\(number).MOV",
                                     byteSize: Int64(18 + random.next() % 160) * 1_000_000,
                                     createdAt: date, duration: Double(6 + random.next() % 140))
                } else if roll < 26 {
                    item = MediaItem(id: "demo-\(number)", fileName: "IMG_\(number).PNG",
                                     byteSize: Int64(350 + random.next() % 900) * 1_000, createdAt: date)
                } else {
                    item = MediaItem(id: "demo-\(number)", fileName: "IMG_\(number).JPG",
                                     byteSize: Int64(1_800 + random.next() % 2_800) * 1_000, createdAt: date)
                }
                items.append(item)
            }
        }
        return items
    }
}

/// Draws simple landscapes (and phone-like screens for screenshots) as JPEG data.
enum DemoArt {
    private struct Palette {
        let skyTop: UInt32, skyBottom: UInt32, sun: UInt32
        let layers: [UInt32]
    }

    private static let palettes: [Palette] = [
        Palette(skyTop: 0x2B1B4D, skyBottom: 0xF28C5A, sun: 0xFFD58A, layers: [0x7A3E6B, 0x5A2C55, 0x3A1D3F]),
        Palette(skyTop: 0x4FA3E0, skyBottom: 0xBFE3F7, sun: 0xFFF6D5, layers: [0x6FB7C9, 0x3C8DB0, 0x22668A]),
        Palette(skyTop: 0xA7D3C9, skyBottom: 0xF2EBD3, sun: 0xFFF3C4, layers: [0x7FA67A, 0x4E7D57, 0x2E5640]),
        Palette(skyTop: 0x0B1530, skyBottom: 0x2D3A6B, sun: 0xE8ECF7, layers: [0x26315A, 0x1B2445, 0x111833]),
        Palette(skyTop: 0xF6C28B, skyBottom: 0xFBE7C6, sun: 0xFFF1D6, layers: [0xD9925B, 0xB8693E, 0x8A4A2C]),
        Palette(skyTop: 0x9EC5E8, skyBottom: 0xEAF3FB, sun: 0xFFFFFF, layers: [0xC9D8E8, 0x9FB4CC, 0x6F86A3]),
    ]

    static func image(for item: MediaItem, longestSide: Int) -> Data? {
        let seed = UInt64(abs(item.fileName.hashValue_stable))
        let portrait = item.kind == .screenshot || seed % 3 == 0
        let long = max(longestSide, 64)
        let size = portrait ? CGSize(width: long * 3 / 4, height: long) : CGSize(width: long, height: long * 3 / 4)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        var random = SeededRandom(seed: seed)
        if item.kind == .screenshot {
            drawScreen(in: context, size: size, random: &random)
        } else {
            drawLandscape(in: context, size: size, random: &random)
        }
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func drawLandscape(in context: CGContext, size: CGSize, random: inout SeededRandom) {
        let palette = palettes[Int(random.next() % UInt64(palettes.count))]
        let sky = CGGradient(colorsSpace: nil, colors: [color(palette.skyTop), color(palette.skyBottom)] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(sky, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height * 0.3), options: [.drawsAfterEndLocation])

        let radius = size.width * (0.07 + random.unit * 0.06)
        let sun = CGPoint(x: size.width * (0.2 + random.unit * 0.6), y: size.height * (0.55 + random.unit * 0.25))
        context.setFillColor(color(palette.sun, alpha: 0.35))
        context.fillEllipse(in: CGRect(x: sun.x - radius * 1.6, y: sun.y - radius * 1.6, width: radius * 3.2, height: radius * 3.2))
        context.setFillColor(color(palette.sun))
        context.fillEllipse(in: CGRect(x: sun.x - radius, y: sun.y - radius, width: radius * 2, height: radius * 2))

        for (index, layer) in palette.layers.enumerated() {
            let base = size.height * (0.52 - CGFloat(index) * 0.15)
            let amplitude = size.height * (0.16 - CGFloat(index) * 0.03)
            let steps = 5 + Int(random.next() % 3)
            let path = CGMutablePath()
            path.move(to: .zero)
            var previous = CGPoint(x: 0, y: base + (random.unit - 0.5) * amplitude)
            path.addLine(to: previous)
            for step in 1...steps {
                let point = CGPoint(x: size.width * CGFloat(step) / CGFloat(steps), y: base + (random.unit - 0.5) * amplitude * 2)
                path.addQuadCurve(to: point, control: CGPoint(x: (previous.x + point.x) / 2, y: max(previous.y, point.y) + amplitude * 0.4))
                previous = point
            }
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color(layer))
            context.fillPath()
        }
    }

    private static func drawScreen(in context: CGContext, size: CGSize, random: inout SeededRandom) {
        let accents: [UInt32] = [0x0A84FF, 0x30D158, 0xFF9F0A, 0xBF5AF2, 0xFF375F]
        let accent = accents[Int(random.next() % UInt64(accents.count))]
        context.setFillColor(color(0xF2F2F7))
        context.fill(CGRect(origin: .zero, size: size))
        let unit = size.width / 20
        // Header block.
        context.setFillColor(color(accent))
        context.addPath(CGPath(roundedRect: CGRect(x: unit, y: size.height - unit * 9, width: size.width - unit * 2, height: unit * 6),
                               cornerWidth: unit, cornerHeight: unit, transform: nil))
        context.fillPath()
        // Rows of "content".
        var y = size.height - unit * 12
        while y > unit * 2 {
            context.setFillColor(color(0xFFFFFF))
            context.addPath(CGPath(roundedRect: CGRect(x: unit, y: y - unit * 3, width: size.width - unit * 2, height: unit * 3),
                                   cornerWidth: unit * 0.8, cornerHeight: unit * 0.8, transform: nil))
            context.fillPath()
            context.setFillColor(color(accent, alpha: 0.85))
            context.fillEllipse(in: CGRect(x: unit * 1.8, y: y - unit * 2.4, width: unit * 1.8, height: unit * 1.8))
            context.setFillColor(color(0xC7C7CC))
            let width = size.width * (0.35 + random.unit * 0.3)
            context.fill(CGRect(x: unit * 4.6, y: y - unit * 1.75, width: width, height: unit * 0.5))
            y -= unit * 4
        }
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// SplitMix64: same pictures on every run, so screenshots are reproducible.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<1.
    var unit: CGFloat {
        mutating get { CGFloat(next() % 10_000) / 10_000 }
    }
}

private extension String {
    /// `hashValue` changes between launches; this does not.
    var hashValue_stable: Int64 {
        Int64(bitPattern: utf8.reduce(UInt64(1_469_598_103_934_665_603)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 } >> 1)
    }
}
