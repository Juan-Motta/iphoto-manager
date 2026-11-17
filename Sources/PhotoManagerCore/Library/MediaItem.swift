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
