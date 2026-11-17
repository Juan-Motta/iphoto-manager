import AVKit
import PhotoManagerCore
import SwiftUI

/// Full-size photo or video over the library, with Liquid Glass controls.
/// Presentational: state and actions come from the container.
struct PreviewOverlay: View {
    let item: MediaItem
    let content: AppModel.PreviewContent
    let isSelected: Bool
    let hasPrevious: Bool
    let hasNext: Bool
    let thumbnail: (MediaItem) async -> NSImage?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleSelection: () -> Void
    let onClose: () -> Void

    @State private var placeholder: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.88))
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            media
                .padding(.horizontal, 80)
                .padding(.vertical, 84)

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(16)
        }
        .task(id: item.id) { placeholder = await thumbnail(item) }
        .transition(.opacity)
    }

    @ViewBuilder private var media: some View {
        switch content {
        case .ready(let url) where item.kind == .video:
            VideoPreview(url: url)
                .clipShape(.rect(cornerRadius: 12))
        case .ready(let url):
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
                    .accessibilityLabel(item.fileName)
            } else {
                unavailable("This file can’t be shown.")
            }
        case .loading:
            ZStack {
                if let placeholder {
                    Image(nsImage: placeholder).resizable().scaledToFit().blur(radius: 12).opacity(0.6)
                }
                ProgressView("Loading original…")
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        case .failed(let message):
            unavailable(message)
        }
    }

    private func unavailable(_ message: String) -> some View {
        ContentUnavailableView("Can’t preview", systemImage: "exclamationmark.triangle", description: Text(message))
            .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName).font(.headline)
                Text(details).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .glassEffect(.regular, in: .capsule)

            Spacer()

            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button("Previous", systemImage: "chevron.left", action: onPrevious)
                    .labelStyle(.iconOnly)
                    .disabled(!hasPrevious)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button(isSelected ? "Selected" : "Select",
                       systemImage: isSelected ? "checkmark.circle.fill" : "circle",
                       action: onToggleSelection)
                    .tint(isSelected ? .accentColor : nil)
                Button("Next", systemImage: "chevron.right", action: onNext)
                    .labelStyle(.iconOnly)
                    .disabled(!hasNext)
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    private var details: String {
        var parts: [String] = []
        if let date = item.createdAt { parts.append(date.formatted(date: .abbreviated, time: .shortened)) }
        parts.append(item.byteSize.formatted(.byteCount(style: .file)))
        return parts.joined(separator: " · ")
    }
}

/// Wraps AppKit's `AVPlayerView` directly. SwiftUI's `VideoPlayer` aborts in this app
/// ("failed to demangle superclass of VideoPlayerView") while `AVPlayerView` works.
private struct VideoPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        guard (view.player?.currentItem?.asset as? AVURLAsset)?.url != url else { return }
        view.player?.pause()
        let player = AVPlayer(url: url)
        view.player = player
        player.play()
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player?.pause()
        view.player = nil
    }
}
