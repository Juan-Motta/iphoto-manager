import Foundation

/// A photo or video stored on the connected iPhone.
public struct MediaItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case photo, video, screenshot
    }

    public let id: String
    public let fileName: String
    public let byteSize: Int64
    public let createdAt: Date?
    /// Length in seconds for videos.
    public let duration: TimeInterval?

    public init(id: String, fileName: String, byteSize: Int64, createdAt: Date? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.fileName = fileName
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.duration = duration
    }

    /// iPhone screenshots are saved as PNG; camera photos are HEIC/JPEG.
    public var kind: Kind {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi": .video
        case "png": .screenshot
        default: .photo
        }
    }
}

extension Array where Element == MediaItem {
    /// The item `step` positions away from `id` (1 = next, -1 = previous), or nil past either end.
    public func neighbor(of id: MediaItem.ID, step: Int) -> MediaItem? {
        guard let index = firstIndex(where: { $0.id == id }) else { return nil }
        let target = index + step
        return indices.contains(target) ? self[target] : nil
    }
}
