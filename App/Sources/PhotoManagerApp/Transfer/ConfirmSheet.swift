import AppKit
import PhotoManagerCore
import SwiftUI

/// Confirmation before anything is removed from the iPhone.
struct ConfirmSheet: View {
    let action: TransferAction
    let items: [MediaItem]
    @Binding var options: TransferOptions
    let thumbnail: (MediaItem) async -> NSImage?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var choosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: action == .delete ? "trash" : "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(action == .delete ? Color.red : Color.accentColor, in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold())
                    Text(summary).font(.callout).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                ForEach(items.prefix(6)) { item in
                    ThumbnailTile(item: item, isSelected: false, thumbnail: thumbnail)
                        .frame(width: 62, height: 62)
                        .allowsHitTesting(false)
                }
                if items.count > 6 {
                    Text("+\(items.count - 6)").font(.callout.bold()).foregroundStyle(.secondary).padding(.leading, 4)
                }
            }
            .accessibilityHidden(true)

            if action == .saveAndDelete {
                Form {
                    LabeledContent("Save to") {
                        HStack {
                            Text(options.destination.lastPathComponent).fontWeight(.medium)
                            Button("Change…") { choosingFolder = true }
                        }
                    }
                    Toggle("Organize into folders by date", isOn: $options.organizeByDate)
                    Toggle("Don’t duplicate identical files already on this Mac", isOn: $options.skipExisting)
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .frame(height: 150)
            }

            Label(warning, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 14))

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, role: action == .delete ? .destructive : nil, action: onConfirm)
                    .buttonStyle(.glassProminent)
                    .tint(action == .delete ? .red : .accentColor)
            }
            .controlSize(.large)
        }
        .padding(26)
        .frame(width: 480)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { options.destination = url }
        }
    }

    private var title: String {
        let noun = items.count == 1 ? "item" : "items"
        return action == .delete ? "Delete \(items.count) \(noun) from your iPhone?" : "Save and delete \(items.count) \(noun)?"
    }

    private var summary: String {
        let size = items.reduce(Int64(0)) { $0 + $1.byteSize }.formatted(.byteCount(style: .file))
        return action == .delete
            ? "\(size). These items will not be saved to this Mac."
            : "\(size). Each item is copied and verified on this Mac before it is removed from your iPhone."
    }

    private var warning: String {
        action == .delete
            ? "Items deleted from your iPhone can’t be restored from Photo Manager."
            : "Items deleted from your iPhone can’t be restored from Photo Manager. If a copy fails, that item is kept on the iPhone."
    }

    private var confirmTitle: String { action == .delete ? "Delete" : "Save & Delete" }
}
