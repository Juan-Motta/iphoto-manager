import PhotoManagerCore
import SwiftUI

/// Device data and library filters. Presentational: everything comes in as values and closures.
struct DeviceSidebar: View {
    let device: DeviceInfo?
    let librarySize: Int64
    @Binding var filter: LibraryFilter
    let count: (LibraryFilter) -> Int
    let onEject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let device {
                header(device)
                details(device)
            }

            List(selection: Binding(get: { filter }, set: { if let value = $0 { filter = value } })) {
                Section("Library") {
                    ForEach(LibraryFilter.allCases) { item in
                        Label(item.title, systemImage: item.symbol)
                            .badge(count(item))
                            .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Button(action: onEject) {
                Label("Eject iPhone", systemImage: "eject")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func header(_ device: DeviceInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.33)], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.headline).lineLimit(1)
                Label("Connected · \(device.connection)", systemImage: "circle.fill")
                    .labelStyle(DotLabelStyle())
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func details(_ device: DeviceInfo) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            // ImageCaptureCore often reports only the generic kind ("iPhone") and no battery;
            // rows that would say nothing useful are hidden.
            if !["", "iphone", "ipad", "ipod"].contains(device.model.lowercased()) {
                row("Model", device.model)
            }
            if let battery = device.batteryLevel {
                row("Battery", "\(battery)%")
            }
            row("Photos & videos", librarySize.formatted(.byteCount(style: .file)))
            row("iCloud Photos", device.iCloudPhotosEnabled ? "On" : "Off")
        }
        .font(.caption)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 12)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}
