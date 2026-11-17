import Testing
@testable import PhotoManagerCore

@Suite("Library neighbors")
struct NeighborTests {
    let items = ["a", "b", "c"].map { MediaItem(id: $0, fileName: "\($0).HEIC", byteSize: 1) }

    @Test func nextAndPreviousFollowLibraryOrder() {
        #expect(items.neighbor(of: "b", step: 1)?.id == "c")
        #expect(items.neighbor(of: "b", step: -1)?.id == "a")
    }

    @Test func thereIsNoNeighborPastTheEnds() {
        #expect(items.neighbor(of: "c", step: 1) == nil)
        #expect(items.neighbor(of: "a", step: -1) == nil)
    }

    @Test func anUnknownItemHasNoNeighbor() {
        #expect(items.neighbor(of: "zzz", step: 1) == nil)
    }
}
