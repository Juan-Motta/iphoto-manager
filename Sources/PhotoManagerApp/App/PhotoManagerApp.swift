import AppKit
import PhotoManagerAdapters
import SwiftUI

@main
struct PhotoManagerApp: App {
    // Composition root: the real iPhone monitor is wired here and nowhere else.
    @State private var model = AppModel(monitor: ImageCaptureDeviceMonitor())

    init() {
        // Running from `swift run` has no app bundle; make it a regular foreground app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("Photo Manager") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 640)
                .task { await model.start() }
        }
        .windowToolbarStyle(.unified)
    }
}

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if let device = model.device, device.access == .ready {
                LibraryScreen(model: model)
            } else {
                WaitingView(device: model.device)
            }
        }
        .animation(.smooth, value: model.device?.access)
        .animation(.smooth, value: model.device == nil)
    }
}
