import Foundation
import Testing
import PhotoManagerCore
@testable import PhotoManagerAdapters

@Suite("FileSystemMediaStore")
struct FileSystemMediaStoreTests {
    let root: URL
    let store = FileSystemMediaStore()
    // 2026-11-16 12:00 UTC
    let date = Date(timeIntervalSince1970: 1_794_830_400)

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "pm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func write(_ bytes: Int, to url: URL) throws {
        try Data(count: bytes).write(to: url)
    }

    @Test func folderIsTheDestinationWhenNotOrganizingByDate() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 4, createdAt: date)
        let folder = try store.folder(for: item, options: TransferOptions(destination: root, organizeByDate: false))
        #expect(folder == root)
    }

    @Test func folderUsesYearAndDayAndIsCreated() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 4, createdAt: date)
        let store = FileSystemMediaStore(timeZone: TimeZone(identifier: "UTC")!)

        let folder = try store.folder(for: item, options: TransferOptions(destination: root))

        #expect(folder.path(percentEncoded: false).hasSuffix("/2026/11-16/"))
        #expect(FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test func folderFallsBackToDestinationWithoutADate() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 4)
        #expect(try store.folder(for: item, options: TransferOptions(destination: root)) == root)
    }

    @Test func aCopyIsVerifiedOnlyWhenTheSizeMatches() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 4)
        let file = root.appending(path: "A.HEIC")

        #expect(!store.isVerifiedCopy(at: file, of: item))
        try write(3, to: file)
        #expect(!store.isVerifiedCopy(at: file, of: item))
        try write(4, to: file)
        #expect(store.isVerifiedCopy(at: file, of: item))
    }

    @Test func anEmptyFileIsNeverAVerifiedCopy() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 0)
        let file = root.appending(path: "A.HEIC")
        try write(0, to: file)
        #expect(!store.isVerifiedCopy(at: file, of: item))
    }

    @Test func existingCopyRequiresSameNameAndSize() throws {
        let item = MediaItem(id: "1", fileName: "A.HEIC", byteSize: 4)
        #expect(store.existingCopy(of: item, in: root) == nil)

        try write(9, to: root.appending(path: "A.HEIC"))
        #expect(store.existingCopy(of: item, in: root) == nil)

        try write(4, to: root.appending(path: "A.HEIC"))
        #expect(store.existingCopy(of: item, in: root)?.lastPathComponent == "A.HEIC")
    }

    @Test func availableFileNameAvoidsOverwritingADifferentFile() throws {
        #expect(FileSystemMediaStore.availableFileName("IMG_0001.HEIC", in: root) == "IMG_0001.HEIC")
        try write(1, to: root.appending(path: "IMG_0001.HEIC"))
        try write(1, to: root.appending(path: "IMG_0001 (1).HEIC"))
        #expect(FileSystemMediaStore.availableFileName("IMG_0001.HEIC", in: root) == "IMG_0001 (2).HEIC")
    }
}
