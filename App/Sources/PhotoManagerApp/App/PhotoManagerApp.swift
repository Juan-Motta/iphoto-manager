import AppKit
import PhotoManagerAdapters
import PhotoManagerCore
import SwiftUI

@main
struct PhotoManagerApp: App {
    // Composition root: the real iPhone monitor is wired here and nowhere else.
    @State private var model = AppModel(monitor: Self.makeMonitor())

    init() {
        // Running from `swift run` has no app bundle; make it a regular foreground app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("Easy Photo Saver") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 640)
                .task { await model.start() }
                .task { await stageDemo() }
        }
        .windowToolbarStyle(.unified)
    }

    @MainActor
    private static func makeMonitor() -> any DeviceMonitor {
        #if DEBUG
        // PHOTO_MANAGER_DEMO swaps in a fake iPhone for README screenshots.
        if let scene = DemoScene.current { return scene.monitor }
        #endif
        return ImageCaptureDeviceMonitor()
    }

    @MainActor
    private func stageDemo() async {
        #if DEBUG
        await DemoScene.current?.stage(model)
        #endif
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
