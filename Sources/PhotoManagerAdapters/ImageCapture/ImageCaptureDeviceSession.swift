import Foundation
import ImageCaptureCore
import PhotoManagerCore

/// One open session with a connected iPhone through `ICCameraDevice`.
@MainActor
public final class ImageCaptureDeviceSession: NSObject, DeviceSession {
    nonisolated public let id: String
    private let camera: ICCameraDevice
    private let onChange: (DeviceInfo) -> Void
    private var files: [MediaItem.ID: ICCameraFile] = [:]
    private var catalogReady = false
    private var catalogWaiters: [CheckedContinuation<Void, Never>] = []

    init(camera: ICCameraDevice, onChange: @escaping (DeviceInfo) -> Void) {
        self.id = camera.uuidString ?? UUID().uuidString
        self.camera = camera
        self.onChange = onChange
        super.init()
        camera.delegate = self
    }

    private var isOpen = false

    /// Opens the session. While the iPhone is locked or not trusted, ImageCaptureCore rejects it
    /// ("Please unlock", code -9943); it is retried when the access restriction is removed.
    func openWhenAllowed() async {
        guard !isOpen else { return }
        let error: (any Error)? = await withCheckedContinuation { continuation in
            camera.requestOpenSession(options: [:]) { error in continuation.resume(returning: error) }
        }
        if error == nil { isOpen = true }
    }

    // MARK: DeviceSession

    public var info: DeviceInfo { currentInfo() }

    public func loadLibrary() async throws -> [MediaItem] {
        await waitForCatalog()
        let cameraFiles = (camera.mediaFiles ?? []).compactMap { $0 as? ICCameraFile }
        files = [:]
        let items = cameraFiles.map { file -> MediaItem in
            let id = Self.itemID(file)
            let item = MediaItem(
                id: id,
                fileName: file.name ?? "Item \(id)",
                byteSize: Int64(file.fileSize),
                createdAt: file.creationDate ?? file.fileCreationDate,
                duration: file.duration > 0 ? file.duration : nil
            )
            files[item.id] = file
            return item
        }
        try LibraryIntegrity.ensureUniqueIDs(items)
        return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// iPhones report `ptpObjectHandle` 0 for every file, so it cannot identify items.
    /// The camera item object itself is unique for the life of this session, which is the
    /// only scope ids are valid in (selection is cleared when a device connects).
    private static func itemID(_ item: ICCameraItem) -> String {
        String(UInt(bitPattern: ObjectIdentifier(item).hashValue), radix: 16)
    }

    public func thumbnail(for item: MediaItem) async -> Data? {
        guard let file = files[item.id] else { return nil }
        return await withCheckedContinuation { continuation in
            file.requestThumbnailData(options: [.imageSourceThumbnailMaxPixelSize: 360]) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    public func download(_ item: MediaItem, into folder: URL) async throws -> URL {
        guard let file = files[item.id] else { throw CocoaError(.fileNoSuchFile) }
        let name = FileSystemMediaStore.availableFileName(item.fileName, in: folder)
        let options: [ICDownloadOption: Any] = [
            .downloadsDirectoryURL: folder,
            .saveAsFilename: name,
            .overwrite: false,
        ]
        let savedName: String = try await withCheckedThrowingContinuation { continuation in
            _ = file.requestDownload(options: options) { filename, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: filename ?? name)
                }
            }
        }
        return folder.appending(path: savedName)
    }

    public func delete(_ items: [MediaItem]) async -> Set<MediaItem.ID> {
        let targets = items.compactMap { files[$0.id] }
        guard !targets.isEmpty else { return [] }
        let deletedIDs: Set<MediaItem.ID> = await withCheckedContinuation { continuation in
            _ = camera.requestDeleteFiles(targets, deleteFailed: { _ in }, completion: { result, _ in
                let succeeded = result[.successful] ?? []
                continuation.resume(returning: Set(succeeded.map(Self.itemID)))
            })
        }
        let deleted = Set(items.map(\.id)).intersection(deletedIDs)
        for id in deleted { files[id] = nil }
        return deleted
    }

    public func eject() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            camera.requestEject { _ in continuation.resume() }
        }
    }

    // MARK: Helpers

    private func currentInfo() -> DeviceInfo {
        let access: DeviceInfo.Access =
            camera.isAccessRestrictedAppleDevice ? .needsTrust : (camera.isLocked ? .locked : .ready)
        return DeviceInfo(
            id: id,
            name: camera.name ?? "iPhone",
            model: camera.productKind ?? "iPhone",
            connection: camera.transportType.map { $0 == ICDeviceTransport.transportTypeUSB.rawValue ? "USB" : $0 } ?? "Unknown",
            batteryLevel: camera.batteryLevelAvailable ? Int(camera.batteryLevel) : nil,
            iCloudPhotosEnabled: camera.iCloudPhotosEnabled,
            access: access
        )
    }

    private func waitForCatalog() async {
        if catalogReady { return }
        await withCheckedContinuation { catalogWaiters.append($0) }
    }

    fileprivate func markCatalogReady() {
        catalogReady = true
        catalogWaiters.forEach { $0.resume() }
        catalogWaiters.removeAll()
    }

    fileprivate func notifyChange() { onChange(currentInfo()) }
}

// ImageCaptureCore delivers camera delegate callbacks on the main thread.
extension ImageCaptureDeviceSession: ICCameraDeviceDelegate {
    nonisolated public func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        MainActor.assumeIsolated { markCatalogReady() }
    }

    nonisolated public func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {
        MainActor.assumeIsolated {
            notifyChange()
            Task { await openWhenAllowed() }
        }
    }

    nonisolated public func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {
        MainActor.assumeIsolated { notifyChange() }
    }

    nonisolated public func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {
        MainActor.assumeIsolated { notifyChange() }
    }

    nonisolated public func didRemove(_ device: ICDevice) {}
    nonisolated public func device(_ device: ICDevice, didOpenSessionWithError error: (any Error)?) {}
    nonisolated public func device(_ device: ICDevice, didCloseSessionWithError error: (any Error)?) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: (any Error)?) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: (any Error)?) {}
    nonisolated public func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
}
