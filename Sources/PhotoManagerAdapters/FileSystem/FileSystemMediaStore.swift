import Foundation
import PhotoManagerCore

/// Saves media on the Mac's disk and verifies copies by file size.
public struct FileSystemMediaStore: MediaStore {
    private let timeZone: TimeZone

    public init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    public func folder(for item: MediaItem, options: TransferOptions) throws -> URL {
        var folder = options.destination
        if options.organizeByDate, let date = item.createdAt {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            folder = folder
                .appending(path: String(format: "%04d", parts.year ?? 0), directoryHint: .isDirectory)
                .appending(path: String(format: "%02d-%02d", parts.month ?? 0, parts.day ?? 0), directoryHint: .isDirectory)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    public func existingCopy(of item: MediaItem, in folder: URL) -> URL? {
        let candidate = folder.appending(path: item.fileName)
        return isVerifiedCopy(at: candidate, of: item) ? candidate : nil
    }

    public func isVerifiedCopy(at url: URL, of item: MediaItem) -> Bool {
        // A device that reports size 0 gives nothing to verify against: never treat it as safe.
        guard item.byteSize > 0 else { return false }
        // FileManager reads fresh attributes; URL.resourceValues may return cached ones.
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)),
            attributes[.type] as? FileAttributeType == .typeRegular,
            let size = attributes[.size] as? NSNumber
        else { return false }
        return size.int64Value == item.byteSize
    }

    public func contentsEqual(_ first: URL, _ second: URL) -> Bool {
        FileManager.default.contentsEqual(
            atPath: first.path(percentEncoded: false),
            andPath: second.path(percentEncoded: false)
        )
    }

    public func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// A file name in `folder` that does not overwrite an existing file:
    /// `IMG_0001.HEIC`, then `IMG_0001 (1).HEIC`, `IMG_0001 (2).HEIC`…
    public static func availableFileName(_ fileName: String, in folder: URL) -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: folder.appending(path: fileName).path(percentEncoded: false)) else {
            return fileName
        }
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var index = 1
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            if !manager.fileExists(atPath: folder.appending(path: candidate).path(percentEncoded: false)) {
                return candidate
            }
            index += 1
        }
    }
}
