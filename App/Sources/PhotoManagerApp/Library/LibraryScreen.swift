import PhotoManagerCore
import SwiftUI

/// Container for the connected-device screen: sidebar, grid, selection bar and sheets.
struct LibraryScreen: View {
    @Bindable var model: AppModel
    @State private var columns: Double = 7

    var body: some View {
        NavigationSplitView {
            DeviceSidebar(
                device: model.device,
                librarySize: model.librarySize,
                filter: $model.filter,
                count: model.count(for:),
                onEject: { Task { await model.eject() } }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 272, max: 320)
        } detail: {
            ZStack(alignment: .bottom) {
                content
                    // Fill the detail column so the bar sits at the window's bottom, not under a short empty state.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                SelectionBar(
                    count: model.selection.count,
                    totalBytes: model.selection.totalBytes(in: model.library),
                    canSelectAll: !model.visibleItems.isEmpty,
                    allSelected: model.allVisibleSelected,
                    onToggleAll: model.toggleAllVisible,
                    onAction: model.request
                )
                .padding(.bottom, 18)
            }
            .navigationTitle(model.filter.title)
            .navigationSubtitle("\(model.visibleItems.count) items on this iPhone")
            .toolbar {
                ToolbarItemGroup {
                    Button("Smaller Thumbnails", systemImage: "minus") { columns = min(columns + 1, 10) }
                    Button("Larger Thumbnails", systemImage: "plus") { columns = max(columns - 1, 3) }
                }
                ToolbarItem {
                    Button("Reload", systemImage: "arrow.clockwise") { Task { await model.reloadLibrary() } }
                }
            }
        }
        .overlay {
            if let item = model.previewItem {
                PreviewOverlay(
                    item: item,
                    content: model.previewContent,
                    isSelected: model.selection.contains(item.id),
                    hasPrevious: model.hasPreviousPreview,
                    hasNext: model.hasNextPreview,
                    thumbnail: model.thumbnail(for:),
                    onPrevious: { model.showPreview(step: -1) },
                    onNext: { model.showPreview(step: 1) },
                    onToggleSelection: { model.selection.toggle(item.id) },
                    onClose: model.closePreview
                )
            }
        }
        .animation(.smooth(duration: 0.2), value: model.previewItem?.id)
        .sheet(item: $model.pendingAction) { action in
            ConfirmSheet(
                action: action,
                items: model.selectedItems,
                deviceName: model.device?.name ?? "your iPhone",
                options: $model.options,
                thumbnail: model.thumbnail(for:),
                onCancel: { model.pendingAction = nil },
                onConfirm: { chosen in Task { await model.perform(chosen) } }
            )
        }
        .sheet(isPresented: transferPresented) {
            if let transfer = model.transfer {
                ProgressSheet(
                    state: transfer,
                    thumbnail: model.thumbnail(for:),
                    onClose: model.closeTransfer,
                    onReveal: model.revealDestination
                )
            }
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoadingLibrary && model.library.isEmpty {
            ProgressView("Reading photos from \(model.device?.name ?? "iPhone")…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t read the library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await model.reloadLibrary() } }.buttonStyle(.glass)
            }
        } else if model.visibleItems.isEmpty {
            ContentUnavailableView("No \(model.filter.title)", systemImage: model.filter.symbol, description: Text("There is nothing here on this iPhone."))
        } else {
            MediaGrid(
                sections: model.sections,
                columns: Int(columns),
                isSelected: model.selection.contains,
                allSelected: { model.selection.containsAll(of: $0.items) },
                onToggle: { model.selection.toggle($0.id) },
                onToggleSection: model.toggle(section:),
                onPreview: model.openPreview,
                thumbnail: model.thumbnail(for:)
            )
        }
    }

    private var transferPresented: Binding<Bool> {
        Binding(get: { model.transfer != nil }, set: { if !$0 { model.closeTransfer() } })
    }
}

extension TransferAction: Identifiable {
    public var id: Self { self }
}
