import AppKit
import PhotoManagerCore
import SwiftUI

/// Live progress of a transfer, then its per-item result.
struct ProgressSheet: View {
    let state: TransferState
    let thumbnail: (MediaItem) async -> NSImage?
    let onClose: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.bold())
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }

            if state.report == nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(state.progress.completed) of \(state.progress.total) items").fontWeight(.semibold)
                        Spacer()
                        Text(state.progress.fraction.formatted(.percent.precision(.fractionLength(0)))).foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    ProgressView(value: state.progress.fraction)
                }
            }

            List(state.items) { item in
                HStack(spacing: 12) {
                    ThumbnailTile(item: item, isSelected: false, thumbnail: thumbnail, showsCheck: false)
                        .frame(width: 36, height: 36)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.fileName).font(.callout.weight(.medium))
                        Text(status(for: item).text).font(.caption).foregroundStyle(status(for: item).color)
                    }
                    Spacer()
                    statusIcon(for: item)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(height: 260)
            .scrollContentBackground(.hidden)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            HStack {
                if state.report != nil, state.action != .delete {
                    Button("Show in Finder", systemImage: "folder", action: onReveal).buttonStyle(.glass)
                }
                Spacer()
                Button(state.report == nil ? "Hide" : "Done", action: onClose)
                    .buttonStyle(.glassProminent)
                    .disabled(state.report == nil)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(26)
        .frame(width: 500)
        .interactiveDismissDisabled(state.report == nil)
    }

    private var title: String {
        if let report = state.report {
            return report.failedCount == 0 ? "All done" : "Finished with \(report.failedCount) problem\(report.failedCount == 1 ? "" : "s")"
        }
        return switch state.action {
        case .save: "Saving…"
        case .saveAndDelete: "Saving and deleting…"
        case .delete: "Deleting…"
        }
    }

    private var subtitle: String {
        state.report == nil ? "Keep your iPhone connected and unlocked." : "Items with a problem were kept on your iPhone."
    }

    private func status(for item: MediaItem) -> (text: String, color: Color) {
        if let outcome = state.report?.outcomes[item.id] {
            return switch outcome {
            case .saved: ("Saved · Verified", .green)
            case .alreadySaved: ("Already on this Mac", .green)
            case .savedAndDeleted: ("Saved · Verified · Deleted from iPhone", .green)
            case .savedNotDeleted: ("Saved, but the iPhone didn’t delete it", .orange)
            case .deleted: ("Deleted from iPhone", .green)
            case .failed(.downloadFailed): ("Couldn’t copy — kept on iPhone", .red)
            case .failed(.verificationFailed): ("Copy didn’t verify — kept on iPhone", .red)
            case .failed(.deleteFailed): ("Couldn’t delete", .red)
            }
        }
        if state.progress.currentFileName == item.fileName {
            return (state.progress.phase == .copying ? "Copying to Mac…" : "Deleting…", .accentColor)
        }
        if isDeletingBatch { return ("Deleting from iPhone…", .accentColor) }
        if isCopied(item) { return ("Copied", .secondary) }
        return ("Waiting", .secondary)
    }

    /// Items are copied in order, so everything before `completed` is already done;
    /// the real outcome appears when the report arrives.
    private func isCopied(_ item: MediaItem) -> Bool {
        state.progress.phase == .copying && (state.items.firstIndex(of: item) ?? .max) < state.progress.completed
    }

    /// Save & Delete deletes all verified copies in one request after copying.
    private var isDeletingBatch: Bool {
        state.report == nil && state.progress.phase == .deleting && state.progress.currentFileName == nil
    }

    @ViewBuilder private func statusIcon(for item: MediaItem) -> some View {
        if let outcome = state.report?.outcomes[item.id] {
            if case .failed = outcome {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            } else if outcome == .savedNotDeleted {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        } else if state.progress.currentFileName == item.fileName || isDeletingBatch {
            ProgressView().controlSize(.small)
        } else if isCopied(item) {
            Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
        } else {
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }
}
