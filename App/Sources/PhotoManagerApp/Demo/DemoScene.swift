import AppKit
import Foundation
import PhotoManagerCore

/// Screens the README shows. Launch with `PHOTO_MANAGER_DEMO=<scene>`; see `scripts/screenshots.sh`.
enum DemoScene: String, CaseIterable {
    case waiting, library, preview, confirm, progress

    /// The scene requested by the environment, or nil for the normal app.
    static var current: DemoScene? {
        ProcessInfo.processInfo.environment["PHOTO_MANAGER_DEMO"].flatMap(DemoScene.init(rawValue:))
    }

    @MainActor var monitor: any DeviceMonitor { DemoDeviceMonitor(connects: self != .waiting) }

    /// Puts the app in this scene's state, then prints the window number for `screencapture`.
    @MainActor
    func stage(_ model: AppModel) async {
        // Never write demo files into the user's Pictures folder.
        model.options.destination = FileManager.default.temporaryDirectory
            .appending(path: "PhotoManagerDemo", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: model.options.destination, withIntermediateDirectories: true)

        if self != .waiting {
            while model.library.isEmpty { try? await Task.sleep(for: .milliseconds(100)) }
        }

        let items = model.library
        switch self {
        case .waiting:
            break
        case .library:
            model.selection.select(Array(items.prefix(6)))
        case .preview:
            model.selection.select(Array(items.prefix(3)))
            if let photo = items.first(where: { $0.kind == .photo }) { model.openPreview(photo) }
        case .confirm:
            model.selection.select(Array(items.prefix(9)))
            model.request(.delete)
        case .progress:
            model.selection.select(Array(items.prefix(14)))
            Task { await model.perform(.saveAndDelete) }
        }

        if let window = NSApp.windows.first(where: \.isVisible) {
            window.setContentSize(NSSize(width: 1240, height: 780))
            window.center()
            // Captures of an inactive window show grey controls.
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        // Let thumbnails load and animations settle before the capture.
        try? await Task.sleep(for: .seconds(self == .progress ? 2.6 : 2.0))
        if let window = NSApp.windows.first(where: \.isVisible) {
            print("PHOTO_MANAGER_WINDOW=\(window.windowNumber)")
            fflush(stdout)
        }
    }
}
