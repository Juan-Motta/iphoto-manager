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
    private(set) var loadError: String?

    var selection = Selection()
    var filter: LibraryFilter = .all
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
    private var thumbnails: [MediaItem.ID: NSImage] = [:]

    init(monitor: any DeviceMonitor) {
        self.monitor = monitor
    }

    // MARK: Device lifecycle

    func start() async {
        for await event in monitor.events() {
            switch event {
            case .connected(let session):
                self.session = session
                device = await session.info
                await reloadLibrary()
            case .changed(let info) where info.id == device?.id:
                let becameReady = device?.access != .ready && info.access == .ready
                device = info
                if becameReady { await reloadLibrary() }
            case .changed:
                break
            case .disconnected(let id) where id == device?.id:
                resetDevice()
            case .disconnected:
                break
            }
        }
    }

    func reloadLibrary() async {
        guard let session, device?.access == .ready else { return }
        isLoadingLibrary = true
        loadError = nil
        defer { isLoadingLibrary = false }
        do {
            library = try await session.loadLibrary()
            selection.keepOnly(library)
        } catch {
            loadError = error.localizedDescription
        }
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
        if let cached = thumbnails[item.id] { return cached }
        guard let data = await session?.thumbnail(for: item), let image = NSImage(data: data) else { return nil }
        thumbnails[item.id] = image
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
        guard let session else { return }
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

        let removed = report.removedFromDevice
        library.removeAll { removed.contains($0.id) }
        selection.deselect(items.filter { report.outcomes[$0.id].map(Self.isFinished) ?? false })
        transfer?.report = report
    }

    func closeTransfer() { transfer = nil }

    func revealDestination() {
        NSWorkspace.shared.activateFileViewerSelecting([options.destination])
    }

    private static func isFinished(_ outcome: ItemOutcome) -> Bool {
        if case .failed = outcome { return false }
        return true
    }
}
