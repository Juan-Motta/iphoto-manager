import Foundation
import Testing
@testable import PhotoManagerCore

@Suite("Selection")
struct SelectionTests {
    let photo = MediaItem(id: "1", fileName: "IMG_0001.HEIC", byteSize: 3_000_000)
    let video = MediaItem(id: "2", fileName: "IMG_0002.MOV", byteSize: 50_000_000)
    let shot = MediaItem(id: "3", fileName: "IMG_0003.PNG", byteSize: 1_000_000)

    @Test func toggleAddsThenRemovesAnItem() {
        var selection = Selection()
        selection.toggle(photo.id)
        #expect(selection.contains(photo.id))
        selection.toggle(photo.id)
        #expect(!selection.contains(photo.id))
        #expect(selection.isEmpty)
    }

    @Test func selectAllOfAFilteredSetKeepsEarlierSelection() {
        var selection = Selection()
        selection.toggle(photo.id)
        selection.select([video, shot])
        #expect(selection.ids == [photo.id, video.id, shot.id])
        #expect(selection.containsAll(of: [video, shot]))
    }

    @Test func deselectRemovesOnlyTheGivenItems() {
        var selection = Selection()
        selection.select([photo, video, shot])
        selection.deselect([video, shot])
        #expect(selection.ids == [photo.id])
        #expect(!selection.containsAll(of: [video, shot]))
    }

    @Test func containsAllIsFalseForAnEmptyList() {
        #expect(!Selection().containsAll(of: []))
    }

    @Test func clearEmptiesTheSelection() {
        var selection = Selection()
        selection.select([photo, video])
        selection.clear()
        #expect(selection.isEmpty)
    }

    @Test func selectedItemsKeepLibraryOrderAndSumTheirSize() {
        var selection = Selection()
        selection.select([shot, photo])
        let library = [photo, video, shot]
        #expect(selection.items(in: library) == [photo, shot])
        #expect(selection.totalBytes(in: library) == 4_000_000)
    }
}

@Suite("MediaItem kind")
struct MediaKindTests {
    @Test(arguments: [
        ("IMG_1.HEIC", MediaItem.Kind.photo),
        ("IMG_1.jpg", .photo),
        ("IMG_1.MOV", .video),
        ("clip.mp4", .video),
        ("IMG_1.PNG", .screenshot),
    ])
    func kindIsInferredFromTheFileExtension(fileName: String, expected: MediaItem.Kind) {
        #expect(MediaItem(id: "x", fileName: fileName, byteSize: 1).kind == expected)
    }
}
