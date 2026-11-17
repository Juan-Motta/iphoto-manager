import Foundation

/// The set of items the user picked in the library grid.
public struct Selection: Equatable, Sendable {
    public private(set) var ids: Set<MediaItem.ID> = []

    public init() {}

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ id: MediaItem.ID) -> Bool { ids.contains(id) }

    /// True when every item in a non-empty list is selected.
    public func containsAll(of items: [MediaItem]) -> Bool {
        !items.isEmpty && items.allSatisfy { ids.contains($0.id) }
    }

    public mutating func toggle(_ id: MediaItem.ID) {
        if ids.remove(id) == nil { ids.insert(id) }
    }

    public mutating func select(_ items: [MediaItem]) {
        ids.formUnion(items.map(\.id))
    }

    public mutating func deselect(_ items: [MediaItem]) {
        ids.subtract(items.map(\.id))
    }

    public mutating func clear() { ids.removeAll() }

    /// Removes ids that no longer exist in the library (for example after a deletion).
    public mutating func keepOnly(_ library: [MediaItem]) {
        ids.formIntersection(library.map(\.id))
    }

    /// Selected items in library order.
    public func items(in library: [MediaItem]) -> [MediaItem] {
        library.filter { ids.contains($0.id) }
    }

    public func totalBytes(in library: [MediaItem]) -> Int64 {
        items(in: library).reduce(0) { $0 + $1.byteSize }
    }
}
