import AppKit
import Foundation
import Observation
import PhotoManagerAdapters
import PhotoManagerCore

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, photos, videos, screenshots

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Items"
        case .photos: "Photos"
        case .videos: "Videos"
        case .screenshots: "Screenshots"
        }
    }

    var symbol: String {
        switch self {
        case .all: "photo.on.rectangle"
        case .photos: "photo"
        case .videos: "video"
        case .screenshots: "camera.viewfinder"
        }
    }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: true
        case .photos: item.kind == .photo
        case .videos: item.kind == .video
        case .screenshots: item.kind == .screenshot
        }
    }
}

enum ThumbnailSize: String, CaseIterable, Identifiable {
    case standard, large

    var id: Self { self }
    var title: String { self == .standard ? "Default" : "Large" }
    var symbol: String { self == .standard ? "square.grid.3x3" : "square.grid.2x2" }
    /// Minimum tile width in points; the grid fits as many columns as the window allows.
    var minimumTileWidth: CGFloat { self == .standard ? 110 : 220 }
    /// Requested from the iPhone: about 2× the tile width so Retina screens stay sharp.
    var maxPixelSize: Int { self == .standard ? 360 : 720 }
}

struct LibrarySection: Identifiable {
    let id: Date
    let title: String
    let items: [MediaItem]
}

struct TransferState {
    let action: TransferAction
    let items: [MediaItem]
    var progress: TransferProgress
    var report: TransferReport?
}

/// Screen state for the whole app. Views read it; only this type talks to the domain.
@MainActor
@Observable
final class AppModel {
    private(set) var device: DeviceInfo?
    private(set) var library: [MediaItem] = []
    private(set) var isLoadingLibrary = false
    private var reloadPending = false
    private(set) var loadError: String?

    var selection = Selection()
    var filter: LibraryFilter = .all
    var thumbnailSize: ThumbnailSize = ThumbnailSize(rawValue: UserDefaults.standard.string(forKey: "thumbnailSize") ?? "") ?? .standard {
        didSet { UserDefaults.standard.set(thumbnailSize.rawValue, forKey: "thumbnailSize") }
    }
    var options = TransferOptions(
        destination: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appending(path: "iPhone Import", directoryHint: .isDirectory)
    )
    /// Set when an action needs confirmation; drives the confirm sheet.
    var pendingAction: TransferAction?
    /// Set while a transfer runs and until the user closes its result.
    var transfer: TransferState?

    private let monitor: any DeviceMonitor
    private var session: (any DeviceSession)?
    private var accessedFolder: URL?
    /// Keyed by item and pixel size, so switching sizes keeps both sets cached.
    private var thumbnails: [String: NSImage] = [:]

    init(monitor: any DeviceMonitor) {
        self.monitor = monitor
    }

    // MARK: Device lifecycle

    func start() async {
        for await event in monitor.events() {
            switch event {
            case .connected(let session):
                // Item ids are only unique within one device session:
                // never carry a selection or pending action over to another device.
                resetDevice()
                self.session = session
                device = await session.info
                await reloadLibrary()
            case .changed(let info) where info.id == device?.id:
                let becameReady = device?.access != .ready && info.access == .ready
                device = info
                if becameReady { await reloadLibrary() }
            case .changed:
                break
            case .libraryChanged(let id) where id == device?.id:
                await reloadLibrary()
            case .libraryChanged:
                break
            case .disconnected(let id) where id == device?.id:
                resetDevice()
            case .disconnected:
                break
            }
        }
    }

    func reloadLibrary() async {
        guard let session, let deviceID = device?.id, device?.access == .ready else { return }
        // A change that arrives mid-load is not lost: the load runs once more when it ends.
        if isLoadingLibrary { reloadPending = true; return }
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        repeat {
            reloadPending = false
            loadError = nil
            do {
                let items = try await session.loadLibrary()
                // The device may have changed while loading.
                guard device?.id == deviceID else { return }
                library = items
                selection.keepOnly(library)
            } catch {
                loadError = error.localizedDescription
            }
        } while reloadPending
    }

    func eject() async {
        await session?.eject()
        resetDevice()
    }

    private func resetDevice() {
        session = nil
        device = nil
        library = []
        thumbnails = [:]
        selection.clear()
        pendingAction = nil
        closePreview()
        previewFiles = [:]
        try? FileManager.default.removeItem(at: Self.previewFolder)
    }

    // MARK: Preview

    enum PreviewContent: Equatable {
        case loading
        case ready(URL)
        case failed(String)
    }

    /// The item shown full size; nil when the preview is closed.
    private(set) var previewItem: MediaItem?
    private(set) var previewContent: PreviewContent = .loading
    private var previewFiles: [MediaItem.ID: URL] = [:]
    private var previewTask: Task<Void, Never>?

    /// Originals are downloaded here only to be displayed, never as the user's saved copy.
    private static let previewFolder = FileManager.default.temporaryDirectory
        .appending(path: "PhotoManagerPreview", directoryHint: .isDirectory)

    var hasPreviousPreview: Bool { previewItem.flatMap { visibleItems.neighbor(of: $0.id, step: -1) } != nil }
    var hasNextPreview: Bool { previewItem.flatMap { visibleItems.neighbor(of: $0.id, step: 1) } != nil }

    func openPreview(_ item: MediaItem) {
        previewItem = item
        previewTask?.cancel()
        if let cached = previewFiles[item.id] {
            previewContent = .ready(cached)
            return
        }
        previewContent = .loading
        previewTask = Task { await loadPreview(item) }
    }

    func showPreview(step: Int) {
        guard let current = previewItem, let next = visibleItems.neighbor(of: current.id, step: step) else { return }
        openPreview(next)
    }

    func closePreview() {
        previewTask?.cancel()
        previewItem = nil
    }

    private func loadPreview(_ item: MediaItem) async {
        guard let session else { return }
        do {
            try FileManager.default.createDirectory(at: Self.previewFolder, withIntermediateDirectories: true)
            let url = try await session.download(item, into: Self.previewFolder)
            previewFiles[item.id] = url
            // Ignore a late result if the user already moved to another item.
            if previewItem?.id == item.id { previewContent = .ready(url) }
        } catch {
            if previewItem?.id == item.id { previewContent = .failed(error.localizedDescription) }
        }
    }

    // MARK: Library

    var visibleItems: [MediaItem] { library.filter(filter.matches) }

    func count(for filter: LibraryFilter) -> Int { library.filter(filter.matches).count }

    var librarySize: Int64 { library.reduce(0) { $0 + $1.byteSize } }

    var sections: [LibrarySection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleItems) { calendar.startOfDay(for: $0.createdAt ?? .distantPast) }
        return groups.keys.sorted(by: >).map { day in
            LibrarySection(id: day, title: Self.sectionTitle(for: day, calendar: calendar), items: groups[day] ?? [])
        }
    }

    private static func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if day == .distantPast { return "Unknown Date" }
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month(.wide).day().year())
    }

    func thumbnail(for item: MediaItem) async -> NSImage? {
        let pixels = thumbnailSize.maxPixelSize
        let key = "\(item.id)@\(pixels)"
        if let cached = thumbnails[key] { return cached }
        guard let data = await session?.thumbnail(for: item, maxPixelSize: pixels), let image = NSImage(data: data) else { return nil }
        thumbnails[key] = image
        return image
    }

    // MARK: Selection

    var selectedItems: [MediaItem] { selection.items(in: library) }

    var allVisibleSelected: Bool { selection.containsAll(of: visibleItems) }

    func toggleAllVisible() {
        if allVisibleSelected { selection.deselect(visibleItems) } else { selection.select(visibleItems) }
    }

    func toggle(section: LibrarySection) {
        if selection.containsAll(of: section.items) { selection.deselect(section.items) } else { selection.select(section.items) }
    }

    // MARK: Transfer

    func request(_ action: TransferAction) {
        guard !selection.isEmpty else { return }
        if action.requiresConfirmation {
            pendingAction = action
        } else {
            Task { await perform(action) }
        }
    }

    func perform(_ action: TransferAction) async {
        pendingAction = nil
        // One transfer at a time: a double click on Confirm must not start a second run.
        guard transfer == nil, let session, let deviceID = device?.id else { return }
        let items = selectedItems
        guard !items.isEmpty else { return }

        transfer = TransferState(
            action: action,
            items: items,
            progress: TransferProgress(completed: 0, total: items.count, currentFileName: items.first?.fileName, phase: action == .delete ? .deleting : .copying)
        )
        let service = TransferService(device: session, store: FileSystemMediaStore())
        let report = await service.run(action, items: items, options: options) { progress in
            Task { @MainActor [weak self] in self?.transfer?.progress = progress }
        }

        transfer?.report = report
        // If another device connected meanwhile, these ids mean nothing in its library.
        guard device?.id == deviceID else { return }
        let removed = report.removedFromDevice
        library.removeAll { removed.contains($0.id) }
        selection.deselect(items.filter { report.outcomes[$0.id].map(Self.isFinished) ?? false })
    }

    func closeTransfer() { transfer = nil }

    /// In the App Sandbox a folder picked in the open panel is reachable only while its
    /// security scope is open, so it stays open until another folder is chosen.
    func useDestination(_ url: URL) {
        accessedFolder?.stopAccessingSecurityScopedResource()
        accessedFolder = url.startAccessingSecurityScopedResource() ? url : nil
        options.destination = url
    }

    func revealDestination() {
        NSWorkspace.shared.activateFileViewerSelecting([options.destination])
    }

    private static func isFinished(_ outcome: ItemOutcome) -> Bool {
        if case .failed = outcome { return false }
        return true
    }
}
