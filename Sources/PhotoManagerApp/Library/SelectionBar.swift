import PhotoManagerCore
import SwiftUI

/// Floating Liquid Glass bar with the selection summary and the three actions.
struct SelectionBar: View {
    let count: Int
    let totalBytes: Int64
    let allSelected: Bool
    let onToggleAll: () -> Void
    let onAction: (TransferAction) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(count) selected").font(.headline)
                    Text(count == 0 ? "Nothing selected" : "\(totalBytes.formatted(.byteCount(style: .file))) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 128, alignment: .leading)
                .padding(.leading, 12)

                Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                    .buttonStyle(.glass)

                Divider().frame(height: 26)

                Group {
                    Button("Save", systemImage: "arrow.down.to.line") { onAction(.save) }
                        .buttonStyle(.glass)
                    Button("Save & Delete", systemImage: "arrow.down.doc") { onAction(.saveAndDelete) }
                        .buttonStyle(.glassProminent)
                    Button("Delete", systemImage: "trash", role: .destructive) { onAction(.delete) }
                        .buttonStyle(.glass)
                        .tint(.red)
                }
                .disabled(count == 0)
            }
            .controlSize(.large)
            .padding(8)
            .glassEffect(.regular, in: .capsule)
        }
    }
}
