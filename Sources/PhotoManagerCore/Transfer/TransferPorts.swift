import Foundation

/// The iPhone side of a transfer.
public protocol MediaTransferring: Sendable {
    /// Copies the original file into `folder` and returns the saved file URL.
    func download(_ item: MediaItem, into folder: URL) async throws -> URL
    /// Deletes the items from the device and returns the ids that were actually deleted.
    func delete(_ items: [MediaItem]) async -> Set<MediaItem.ID>
}

/// The Mac side of a transfer.
public protocol MediaStore: Sendable {
    /// Folder where `item` must be saved. Creates it when needed.
    func folder(for item: MediaItem, options: TransferOptions) throws -> URL
    /// A verified copy of `item` already present in `folder`, if any.
    func existingCopy(of item: MediaItem, in folder: URL) -> URL?
    /// True when the file at `url` is a complete copy of `item`.
    func isVerifiedCopy(at url: URL, of item: MediaItem) -> Bool
    /// Byte-for-byte comparison of two files on the Mac.
    func contentsEqual(_ first: URL, _ second: URL) -> Bool
    /// Removes a file written during the transfer (for example an identical duplicate).
    func remove(_ url: URL) throws
}
