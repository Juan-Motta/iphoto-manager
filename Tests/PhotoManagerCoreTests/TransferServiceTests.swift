import Foundation
import Testing
@testable import PhotoManagerCore

@Suite("TransferService")
struct TransferServiceTests {
    let destination = URL(filePath: "/Mac/Pictures/iPhone Import")
    let a = MediaItem(id: "a", fileName: "A.HEIC", byteSize: 10)
    let b = MediaItem(id: "b", fileName: "B.HEIC", byteSize: 20)
    let c = MediaItem(id: "c", fileName: "C.MOV", byteSize: 30)

    var options: TransferOptions { TransferOptions(destination: destination) }

    @Test func saveCopiesEveryItemAndNeverDeletes() async {
        let device = FakeDevice()
        let service = TransferService(device: device, store: FakeStore())

        let report = await service.run(.save, items: [a, b], options: options)

        #expect(report.outcomes == ["a": .saved, "b": .saved])
        #expect(await device.downloaded == ["a", "b"])
        #expect(await device.deleteRequests.isEmpty)
    }

    @Test func saveSkipsItemsAlreadyOnTheMac() async {
        let device = FakeDevice()
        let service = TransferService(device: device, store: FakeStore(existing: ["A.HEIC"]))

        let report = await service.run(.save, items: [a, b], options: options)

        #expect(report.outcomes == ["a": .alreadySaved, "b": .saved])
        #expect(await device.downloaded == ["b"])
    }

    @Test func saveDownloadsAgainWhenSkippingIsOff() async {
        let device = FakeDevice()
        let service = TransferService(device: device, store: FakeStore(existing: ["A.HEIC"]))
        var options = options
        options.skipExisting = false

        let report = await service.run(.save, items: [a], options: options)

        #expect(report.outcomes == ["a": .saved])
        #expect(await device.downloaded == ["a"])
    }

    @Test func saveAndDeleteRemovesOnlyVerifiedCopies() async {
        let device = FakeDevice(failingDownloads: ["b"])
        let store = FakeStore(unverifiable: ["C.MOV"])
        let service = TransferService(device: device, store: store)

        let report = await service.run(.saveAndDelete, items: [a, b, c], options: options)

        #expect(report.outcomes == [
            "a": .savedAndDeleted,
            "b": .failed(.downloadFailed),
            "c": .failed(.verificationFailed),
        ])
        #expect(await device.deleteRequests == [["a"]])
    }

    @Test func saveAndDeleteTrustsAnExistingCopyOnlyAfterComparingContent() async {
        let device = FakeDevice()
        let store = FakeStore(existing: ["A.HEIC"])
        let service = TransferService(device: device, store: store)

        let report = await service.run(.saveAndDelete, items: [a], options: options)

        #expect(report.outcomes == ["a": .savedAndDeleted])
        #expect(await device.downloaded == ["a"])
        #expect(store.removed == ["A.HEIC"]) // the identical duplicate is discarded
        #expect(await device.deleteRequests == [["a"]])
    }

    @Test func saveAndDeleteKeepsANewCopyWhenTheExistingFileIsADifferentPhoto() async {
        let device = FakeDevice()
        let store = FakeStore(existing: ["A.HEIC"], differentContent: ["A.HEIC"])
        let service = TransferService(device: device, store: store)

        let report = await service.run(.saveAndDelete, items: [a], options: options)

        #expect(report.outcomes == ["a": .savedAndDeleted])
        #expect(store.removed.isEmpty) // both photos stay on the Mac
        #expect(await device.deleteRequests == [["a"]])
    }

    @Test func saveAndDeleteKeepsTheItemWhenTheContentCheckDownloadFails() async {
        let device = FakeDevice(failingDownloads: ["a"])
        let service = TransferService(device: device, store: FakeStore(existing: ["A.HEIC"]))

        let report = await service.run(.saveAndDelete, items: [a], options: options)

        #expect(report.outcomes == ["a": .failed(.downloadFailed)])
        #expect(await device.deleteRequests.isEmpty)
    }

    @Test func saveAndDeleteKeepsTheCopyWhenTheIPhoneRefusesToDelete() async {
        let device = FakeDevice(undeletable: ["b"])
        let service = TransferService(device: device, store: FakeStore())

        let report = await service.run(.saveAndDelete, items: [a, b], options: options)

        #expect(report.outcomes == ["a": .savedAndDeleted, "b": .savedNotDeleted])
    }

    @Test func saveAndDeleteSkipsTheDeleteCallWhenNothingWasVerified() async {
        let device = FakeDevice(failingDownloads: ["a"])
        let service = TransferService(device: device, store: FakeStore())

        let report = await service.run(.saveAndDelete, items: [a], options: options)

        #expect(report.outcomes == ["a": .failed(.downloadFailed)])
        #expect(await device.deleteRequests.isEmpty)
    }

    @Test func deleteOnlyNeverDownloads() async {
        let device = FakeDevice(undeletable: ["b"])
        let service = TransferService(device: device, store: FakeStore())

        let report = await service.run(.delete, items: [a, b], options: options)

        #expect(report.outcomes == ["a": .deleted, "b": .failed(.deleteFailed)])
        #expect(await device.downloaded.isEmpty)
        #expect(await device.deleteRequests == [["a", "b"]])
    }

    @Test func emptySelectionDoesNothing() async {
        let device = FakeDevice()
        let service = TransferService(device: device, store: FakeStore())

        let report = await service.run(.saveAndDelete, items: [], options: options)

        #expect(report.outcomes.isEmpty)
        #expect(await device.downloaded.isEmpty)
        #expect(await device.deleteRequests.isEmpty)
    }

    @Test func progressEndsWithEveryItemCompleted() async {
        let recorder = ProgressRecorder()
        let service = TransferService(device: FakeDevice(), store: FakeStore())

        _ = await service.run(.saveAndDelete, items: [a, b, c], options: options) { progress in
            recorder.append(progress)
        }

        let last = recorder.values.last
        #expect(last?.completed == 3)
        #expect(last?.total == 3)
        #expect(recorder.values.contains { $0.phase == .copying && $0.currentFileName == "B.HEIC" })
        #expect(recorder.values.contains { $0.phase == .deleting })
    }

    @Test func reportCountsFailures() {
        let report = TransferReport(outcomes: ["a": .saved, "b": .failed(.downloadFailed), "c": .savedNotDeleted])
        #expect(report.failedCount == 1)
        #expect(report.removedFromDevice.isEmpty)
    }

    @Test func onlySaveRunsWithoutConfirmation() {
        #expect(!TransferAction.save.requiresConfirmation)
        #expect(TransferAction.saveAndDelete.requiresConfirmation)
        #expect(TransferAction.delete.requiresConfirmation)
    }
}

// MARK: - Fakes

actor FakeDevice: MediaTransferring {
    private let failingDownloads: Set<MediaItem.ID>
    private let undeletable: Set<MediaItem.ID>
    private(set) var downloaded: [MediaItem.ID] = []
    private(set) var deleteRequests: [[MediaItem.ID]] = []

    init(failingDownloads: Set<MediaItem.ID> = [], undeletable: Set<MediaItem.ID> = []) {
        self.failingDownloads = failingDownloads
        self.undeletable = undeletable
    }

    func download(_ item: MediaItem, into folder: URL) async throws -> URL {
        if failingDownloads.contains(item.id) { throw URLError(.cannotWriteToFile) }
        downloaded.append(item.id)
        // Like the real adapter, never overwrite: downloads get their own file name.
        return folder.appending(path: FakeStore.downloadPrefix + item.fileName)
    }

    func delete(_ items: [MediaItem]) async -> Set<MediaItem.ID> {
        deleteRequests.append(items.map(\.id))
        return Set(items.map(\.id)).subtracting(undeletable)
    }
}

final class FakeStore: MediaStore, @unchecked Sendable {
    let existing: Set<String>
    let unverifiable: Set<String>
    /// Existing copies whose bytes differ from what the device sends (same name and size).
    let differentContent: Set<String>
    private let lock = NSLock()
    private var removedNames: [String] = []

    init(existing: Set<String> = [], unverifiable: Set<String> = [], differentContent: Set<String> = []) {
        self.existing = existing
        self.unverifiable = unverifiable
        self.differentContent = differentContent
    }

    static let downloadPrefix = "downloaded-"

    private static func originalName(_ url: URL) -> String {
        let name = url.lastPathComponent
        return name.hasPrefix(downloadPrefix) ? String(name.dropFirst(downloadPrefix.count)) : name
    }

    /// Original file names of the downloads the service discarded.
    var removed: [String] { lock.withLock { removedNames } }

    func contentsEqual(_ first: URL, _ second: URL) -> Bool {
        !differentContent.contains(Self.originalName(first))
    }

    func remove(_ url: URL) throws {
        lock.withLock { removedNames.append(Self.originalName(url)) }
    }

    func folder(for item: MediaItem, options: TransferOptions) throws -> URL { options.destination }

    func existingCopy(of item: MediaItem, in folder: URL) -> URL? {
        existing.contains(item.fileName) ? folder.appending(path: item.fileName) : nil
    }

    func isVerifiedCopy(at url: URL, of item: MediaItem) -> Bool {
        !unverifiable.contains(Self.originalName(url))
    }
}

final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [TransferProgress] = []

    func append(_ value: TransferProgress) { lock.withLock { storage.append(value) } }
    var values: [TransferProgress] { lock.withLock { storage } }
}
