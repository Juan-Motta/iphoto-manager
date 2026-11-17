import AppKit
import PhotoManagerCore
import SwiftUI

/// Confirmation before anything is removed from the iPhone.
/// From Delete, the user can switch to Save & Delete without closing the sheet.
struct ConfirmSheet: View {
    @State private var action: TransferAction
    let items: [MediaItem]
    let deviceName: String
    @Binding var options: TransferOptions
    let thumbnail: (MediaItem) async -> NSImage?
    let onCancel: () -> Void
    let onConfirm: (TransferAction) -> Void

    @State private var choosingFolder = false
    private let previewLimit = 5

    init(
        action: TransferAction,
        items: [MediaItem],
        deviceName: String,
        options: Binding<TransferOptions>,
        thumbnail: @escaping (MediaItem) async -> NSImage?,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (TransferAction) -> Void
    ) {
        _action = State(initialValue: action)
        self.items = items
        self.deviceName = deviceName
        _options = options
        self.thumbnail = thumbnail
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var isDelete: Bool { action == .delete }
    private var tint: Color { isDelete ? .red : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            thumbnails
            if isDelete { deleteNotice } else { saveOptions }
            buttons
        }
        .padding(24)
        .frame(width: 460)
        .animation(.smooth(duration: 0.25), value: action)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { options.destination = url }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: isDelete ? "trash.fill" : "square.and.arrow.down.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.tint(tint.opacity(0.18)), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(isDelete ? "Delete \(itemSummary)?" : "Save and delete \(itemSummary)?")
                    .font(.title3.bold())
                Text(isDelete
                     ? "\(totalSize) will be removed from \(deviceName)."
                     : "\(totalSize) will be copied to this Mac, then removed from \(deviceName).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Six equal slots that share the sheet's width, so the row never overflows and tiles keep
    /// the same size for 1 item or 200. The last slot shows "+N" when items don't fit.
    private var thumbnails: some View {
        let slots = previewLimit + 1
        let overflow = items.count > slots ? items.count - previewLimit : 0
        let shown = Array(items.prefix(overflow > 0 ? previewLimit : slots))
        return HStack(spacing: 8) {
            ForEach(0..<slots, id: \.self) { index in
                Group {
                    if index < shown.count {
                        ThumbnailTile(item: shown[index], isSelected: false, thumbnail: thumbnail, showsCheck: false)
                            .allowsHitTesting(false)
                    } else if index == previewLimit, overflow > 0 {
                        Text("+\(overflow)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .glassEffect(.regular, in: .rect(cornerRadius: 10))
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(items.count) items")
    }

    private var deleteNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("They won’t be saved to this Mac").font(.callout.weight(.semibold))
                    Text("Photo Manager can’t restore them afterwards.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
            }

            Button {
                action = .saveAndDelete
            } label: {
                Label("Save a copy first, then delete", systemImage: "square.and.arrow.down")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.glass)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var saveOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill").foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Save to").font(.caption).foregroundStyle(.secondary)
                    Text(options.destination.lastPathComponent).font(.callout.weight(.medium))
                }
                Spacer()
                Button("Change…") { choosingFolder = true }.buttonStyle(.glass)
            }
            .padding(.bottom, 12)
            Divider()
            Toggle("Organize into folders by date", isOn: $options.organizeByDate)
                .padding(.vertical, 10)
            Divider()
            Toggle("Don’t duplicate identical files already on this Mac", isOn: $options.skipExisting)
                .padding(.top, 10)
            Text("Each item is removed from the iPhone only after its copy is verified.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .toggleStyle(.switch)
        .font(.callout)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
            Button(isDelete ? "Delete \(itemSummary.capitalizedFirst)" : "Save & Delete",
                   role: isDelete ? .destructive : nil) { onConfirm(action) }
                .buttonStyle(.glassProminent)
                .tint(tint)
        }
        .controlSize(.large)
    }

    // MARK: Copy

    private var totalSize: String {
        items.reduce(Int64(0)) { $0 + $1.byteSize }.formatted(.byteCount(style: .file))
    }

    /// "5 videos", "1 photo", "3 photos and 2 videos", "6 items".
    private var itemSummary: String {
        let counts = Dictionary(grouping: items, by: \.kind).mapValues(\.count)
        let parts: [String] = [
            counts[.photo].map { $0 == 1 ? "1 photo" : "\($0) photos" },
            counts[.video].map { $0 == 1 ? "1 video" : "\($0) videos" },
            counts[.screenshot].map { $0 == 1 ? "1 screenshot" : "\($0) screenshots" },
        ].compactMap { $0 }
        switch parts.count {
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default: return items.count == 1 ? "1 item" : "\(items.count) items"
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
