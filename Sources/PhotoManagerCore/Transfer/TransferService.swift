import Foundation

/// Runs Save, Save & Delete and Delete.
///
/// Safety rule: Save & Delete only removes items from the iPhone after their copy on
/// the Mac is verified. Any item that fails to copy or verify stays on the iPhone.
public struct TransferService: Sendable {
    private let device: any MediaTransferring
    private let store: any MediaStore

    public init(device: any MediaTransferring, store: any MediaStore) {
        self.device = device
        self.store = store
    }

    public func run(
        _ action: TransferAction,
        items: [MediaItem],
        options: TransferOptions,
        onProgress: @Sendable (TransferProgress) -> Void = { _ in }
    ) async -> TransferReport {
        guard !items.isEmpty else { return TransferReport(outcomes: [:]) }

        switch action {
        case .save:
            let copies = await copy(items, options: options, verifyExistingContent: false, onProgress: onProgress)
            return TransferReport(outcomes: copies)

        case .saveAndDelete:
            // Name + size is not proof before deleting: existing copies are compared byte by byte.
            var outcomes = await copy(items, options: options, verifyExistingContent: true, onProgress: onProgress)
            let verified = items.filter { outcomes[$0.id] == .saved || outcomes[$0.id] == .alreadySaved }
            if !verified.isEmpty {
                onProgress(TransferProgress(completed: items.count, total: items.count, currentFileName: nil, phase: .deleting))
                let deleted = await device.delete(verified)
                for item in verified {
                    outcomes[item.id] = deleted.contains(item.id) ? .savedAndDeleted : .savedNotDeleted
                }
            }
            return TransferReport(outcomes: outcomes)

        case .delete:
            onProgress(TransferProgress(completed: 0, total: items.count, currentFileName: nil, phase: .deleting))
            let deleted = await device.delete(items)
            onProgress(TransferProgress(completed: items.count, total: items.count, currentFileName: nil, phase: .deleting))
            return TransferReport(outcomes: Dictionary(uniqueKeysWithValues: items.map {
                ($0.id, deleted.contains($0.id) ? ItemOutcome.deleted : .failed(.deleteFailed))
            }))
        }
    }

    private func copy(
        _ items: [MediaItem],
        options: TransferOptions,
        verifyExistingContent: Bool,
        onProgress: @Sendable (TransferProgress) -> Void
    ) async -> [MediaItem.ID: ItemOutcome] {
        var outcomes: [MediaItem.ID: ItemOutcome] = [:]
        for (index, item) in items.enumerated() {
            onProgress(TransferProgress(completed: index, total: items.count, currentFileName: item.fileName, phase: .copying))
            outcomes[item.id] = await copy(item, options: options, verifyExistingContent: verifyExistingContent)
        }
        onProgress(TransferProgress(completed: items.count, total: items.count, currentFileName: nil, phase: .copying))
        return outcomes
    }

    /// - Parameter verifyExistingContent: when false, a name + size match is enough to skip the item
    ///   (fast, used by Save). When true, the item is downloaded anyway and compared with the existing
    ///   file; an identical download is discarded, a different one is kept as a new copy.
    private func copy(_ item: MediaItem, options: TransferOptions, verifyExistingContent: Bool) async -> ItemOutcome {
        guard let folder = try? store.folder(for: item, options: options) else {
            return .failed(.downloadFailed)
        }
        let existing = options.skipExisting ? store.existingCopy(of: item, in: folder) : nil
        if existing != nil, !verifyExistingContent {
            return .alreadySaved
        }
        guard let saved = try? await device.download(item, into: folder) else {
            return .failed(.downloadFailed)
        }
        guard store.isVerifiedCopy(at: saved, of: item) else {
            return .failed(.verificationFailed)
        }
        if let existing, saved != existing, store.contentsEqual(existing, saved) {
            try? store.remove(saved)
            return .alreadySaved
        }
        return .saved
    }
}
