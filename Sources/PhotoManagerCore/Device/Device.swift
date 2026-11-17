import Foundation

/// Data about the connected iPhone. Limited to what ImageCaptureCore exposes:
/// there is no iOS version or storage capacity.
public struct DeviceInfo: Identifiable, Sendable, Equatable {
    public enum Access: Sendable, Equatable {
        case ready
        /// The iPhone is locked; media cannot be read until it is unlocked.
        case locked
        /// The user has not tapped "Trust" on the iPhone yet.
        case needsTrust
    }

    public let id: String
    public let name: String
    public let model: String
    public let connection: String
    /// Percent from 0 to 100, when the device reports it.
    public let batteryLevel: Int?
    public let iCloudPhotosEnabled: Bool
    public let access: Access

    public init(
        id: String,
        name: String,
        model: String,
        connection: String,
        batteryLevel: Int?,
        iCloudPhotosEnabled: Bool,
        access: Access
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.connection = connection
        self.batteryLevel = batteryLevel
        self.iCloudPhotosEnabled = iCloudPhotosEnabled
        self.access = access
    }
}

/// An open connection to one iPhone.
public protocol DeviceSession: MediaTransferring {
    var info: DeviceInfo { get async }
    /// Every photo and video on the device, newest first.
    func loadLibrary() async throws -> [MediaItem]
    /// Small preview image data (JPEG/HEIC) for the grid.
    func thumbnail(for item: MediaItem) async -> Data?
    func eject() async
}

public enum DeviceEvent: Sendable {
    case connected(any DeviceSession)
    case changed(DeviceInfo)
    case disconnected(id: String)
}

/// Watches for iPhones being plugged in and out.
@MainActor
public protocol DeviceMonitor: AnyObject {
    func events() -> AsyncStream<DeviceEvent>
}
