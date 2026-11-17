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
            let copies = await copy(items, options: options, onProgress: onProgress)
            return TransferReport(outcomes: copies)

        case .saveAndDelete:
            var outcomes = await copy(items, options: options, onProgress: onProgress)
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
        onProgress: @Sendable (TransferProgress) -> Void
    ) async -> [MediaItem.ID: ItemOutcome] {
        var outcomes: [MediaItem.ID: ItemOutcome] = [:]
        for (index, item) in items.enumerated() {
            onProgress(TransferProgress(completed: index, total: items.count, currentFileName: item.fileName, phase: .copying))
            outcomes[item.id] = await copy(item, options: options)
        }
        onProgress(TransferProgress(completed: items.count, total: items.count, currentFileName: nil, phase: .copying))
        return outcomes
    }

    private func copy(_ item: MediaItem, options: TransferOptions) async -> ItemOutcome {
        guard let folder = try? store.folder(for: item, options: options) else {
            return .failed(.downloadFailed)
        }
        if options.skipExisting, store.existingCopy(of: item, in: folder) != nil {
            return .alreadySaved
        }
        guard let saved = try? await device.download(item, into: folder) else {
            return .failed(.downloadFailed)
        }
        return store.isVerifiedCopy(at: saved, of: item) ? .saved : .failed(.verificationFailed)
    }
}
