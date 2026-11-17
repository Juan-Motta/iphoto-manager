import AppKit
import PhotoManagerCore
import SwiftUI

/// Thumbnail grid grouped by day, with per-item and per-day selection.
struct MediaGrid: View {
    let sections: [LibrarySection]
    let size: ThumbnailSize
    let isSelected: (MediaItem.ID) -> Bool
    let allSelected: (LibrarySection) -> Bool
    let onToggle: (MediaItem) -> Void
    let onToggleSection: (LibrarySection) -> Void
    let onPreview: (MediaItem) -> Void
    let thumbnail: (MediaItem) async -> NSImage?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(section.title).font(.title3.bold())
                            Text("\(section.items.count) items").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(allSelected(section) ? "Deselect" : "Select") { onToggleSection(section) }
                                .buttonStyle(.borderless)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: size.minimumTileWidth), spacing: 6)], spacing: 6) {
                            ForEach(section.items) { item in
                                ThumbnailTile(
                                    item: item,
                                    isSelected: isSelected(item.id),
                                    thumbnail: thumbnail,
                                    onPreview: { onPreview(item) }
                                )
                                // A new identity per size reloads the thumbnail at the matching resolution.
                                .id("\(item.id)-\(size.rawValue)")
                                .onTapGesture { onToggle(item) }
                                .contextMenu {
                                    Button("Preview", systemImage: "eye") { onPreview(item) }
                                    Button(isSelected(item.id) ? "Deselect" : "Select") { onToggle(item) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 110) // room for the floating selection bar
        }
    }
}

struct ThumbnailTile: View {
    let item: MediaItem
    let isSelected: Bool
    let thumbnail: (MediaItem) async -> NSImage?
    /// Hidden where the tile only illustrates items (confirm and progress sheets).
    var showsCheck: Bool = true
    /// When set, hovering shows a button that opens the full-size preview.
    var onPreview: (() -> Void)? = nil
    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                }
            }
            .overlay(alignment: .bottomLeading) { badge.padding(7) }
            .overlay(alignment: .topTrailing) { if showsCheck { check.padding(7) } }
            .overlay(alignment: .bottomTrailing) {
                if let onPreview, isHovering {
                    Button("Preview", systemImage: "arrow.up.left.and.arrow.down.right", action: onPreview)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .padding(6)
                        .transition(.opacity)
                }
            }
            .onHover { hovering in withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering } }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 10))
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
            .task(id: item.id) { image = await thumbnail(item) }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Preview") { onPreview?() }
    }

    @ViewBuilder private var badge: some View {
        switch item.kind {
        case .video:
            Label(Duration.seconds(item.duration ?? 0).formatted(.time(pattern: .minuteSecond)), systemImage: "play.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .shadow(radius: 2)
        case .screenshot:
            Text("Screenshot")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .glassEffect(.regular, in: .capsule)
        case .photo:
            EmptyView()
        }
    }

    private var check: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white.opacity(0.3))
                .strokeBorder(.white, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private var accessibilityLabel: String {
        let kind = switch item.kind {
        case .photo: "Photo"
        case .video: "Video"
        case .screenshot: "Screenshot"
        }
        return "\(kind), \(item.fileName)"
    }
}
