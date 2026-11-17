import Testing
import PhotoManagerCore
@testable import PhotoManagerAdapters

@Suite("Library integrity")
struct LibraryIntegrityTests {
    @Test func duplicateIDsAreRejected() {
        // Real iPhones report ptpObjectHandle 0 for every file; ids built from it collide.
        let items = [
            MediaItem(id: "0", fileName: "IMG_1.HEIC", byteSize: 1),
            MediaItem(id: "0", fileName: "IMG_2.HEIC", byteSize: 1),
        ]
        #expect(throws: LibraryIntegrityError.duplicateIdentifiers) {
            try LibraryIntegrity.ensureUniqueIDs(items)
        }
    }

    @Test func uniqueIDsPass() throws {
        let items = [
            MediaItem(id: "a", fileName: "IMG_1.HEIC", byteSize: 1),
            MediaItem(id: "b", fileName: "IMG_1.HEIC", byteSize: 1),
        ]
        try LibraryIntegrity.ensureUniqueIDs(items)
    }
}
