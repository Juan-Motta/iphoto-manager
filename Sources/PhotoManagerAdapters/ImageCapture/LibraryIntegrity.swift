import Foundation
import PhotoManagerCore

public enum LibraryIntegrityError: Error, Equatable, LocalizedError {
    case duplicateIdentifiers

    public var errorDescription: String? {
        "The iPhone returned items that can’t be told apart. Nothing was changed; reconnect the iPhone and try again."
    }
}

enum LibraryIntegrity {
    /// Selection, transfer and deletion all address items by id: a repeated id could make an
    /// action hit the wrong photo, so a library with duplicates is refused instead of shown.
    static func ensureUniqueIDs(_ items: [MediaItem]) throws {
        if Set(items.map(\.id)).count != items.count {
            throw LibraryIntegrityError.duplicateIdentifiers
        }
    }
}
