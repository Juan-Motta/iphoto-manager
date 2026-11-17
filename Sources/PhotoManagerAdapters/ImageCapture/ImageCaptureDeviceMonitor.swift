import Foundation
import ImageCaptureCore
import PhotoManagerCore

/// Detects iPhones (and other cameras) connected over USB using `ICDeviceBrowser`.
@MainActor
public final class ImageCaptureDeviceMonitor: NSObject, DeviceMonitor {
    private let browser = ICDeviceBrowser()
    private var sessions: [String: ImageCaptureDeviceSession] = [:]
    private var continuation: AsyncStream<DeviceEvent>.Continuation?

    public override init() {
        super.init()
        browser.delegate = self
        let mask = ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: mask) ?? .camera
    }

    public func events() -> AsyncStream<DeviceEvent> {
        let (stream, continuation) = AsyncStream<DeviceEvent>.makeStream()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.browser.stop() }
        }
        browser.start()
        return stream
    }

    fileprivate func add(_ device: ICDevice) {
        guard let camera = device as? ICCameraDevice else { return }
        let session = ImageCaptureDeviceSession(camera: camera) { [weak self] info in
            self?.continuation?.yield(.changed(info))
        }
        sessions[session.id] = session
        // Report the device right away: a freshly plugged iPhone is access-restricted until it is
        // unlocked and trusted, and the UI must show that state instead of "Searching…".
        continuation?.yield(.connected(session))
        Task { await session.openWhenAllowed() }
    }

    fileprivate func remove(_ device: ICDevice) {
        let id = device.uuidString ?? ""
        sessions[id] = nil
        continuation?.yield(.disconnected(id: id))
    }
}

extension ImageCaptureDeviceMonitor: ICDeviceBrowserDelegate {
    // ImageCaptureCore calls the browser delegate on the main thread.
    nonisolated public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        // ICDevice is not Sendable; this callback already runs on the main thread.
        nonisolated(unsafe) let device = device
        MainActor.assumeIsolated { add(device) }
    }

    nonisolated public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        nonisolated(unsafe) let device = device
        MainActor.assumeIsolated { remove(device) }
    }
}
