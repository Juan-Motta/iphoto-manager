import Foundation

/// What the user wants to do with the selected items.
public enum TransferAction: Sendable, CaseIterable {
    case save
    case saveAndDelete
    case delete

    /// Anything that removes items from the iPhone must be confirmed first.
    public var requiresConfirmation: Bool { self != .save }
}

public struct TransferOptions: Sendable, Equatable {
    public var destination: URL
    /// Saves into `destination/yyyy/MM-dd` folders using each item's creation date.
    public var organizeByDate: Bool
    /// Skips items whose verified copy already exists in the destination.
    public var skipExisting: Bool

    public init(destination: URL, organizeByDate: Bool = true, skipExisting: Bool = true) {
        self.destination = destination
        self.organizeByDate = organizeByDate
        self.skipExisting = skipExisting
    }
}

public enum TransferFailure: Sendable, Equatable {
    case downloadFailed
    case verificationFailed
    case deleteFailed
}

public enum ItemOutcome: Sendable, Equatable {
    case saved
    /// A verified copy was already in the destination.
    case alreadySaved
    case savedAndDeleted
    /// Copied and verified, but the iPhone did not delete it.
    case savedNotDeleted
    case deleted
    case failed(TransferFailure)
}

public struct TransferProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable { case copying, deleting }

    public let completed: Int
    public let total: Int
    public let currentFileName: String?
    public let phase: Phase

    public init(completed: Int, total: Int, currentFileName: String?, phase: Phase) {
        self.completed = completed
        self.total = total
        self.currentFileName = currentFileName
        self.phase = phase
    }

    public var fraction: Double { total == 0 ? 1 : Double(completed) / Double(total) }
}

public struct TransferReport: Sendable, Equatable {
    public let outcomes: [MediaItem.ID: ItemOutcome]

    public init(outcomes: [MediaItem.ID: ItemOutcome]) {
        self.outcomes = outcomes
    }

    public var failedCount: Int {
        outcomes.values.filter { if case .failed = $0 { true } else { false } }.count
    }

    /// Items that no longer exist on the iPhone.
    public var removedFromDevice: Set<MediaItem.ID> {
        Set(outcomes.filter { $0.value == .deleted || $0.value == .savedAndDeleted }.keys)
    }
}
