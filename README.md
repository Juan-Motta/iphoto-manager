# Photo Manager

Native macOS app that detects a connected iPhone, shows its device data and media, and lets you **Save**, **Save & Delete** or **Delete** a selection. UI follows macOS 26 Liquid Glass.

## Architecture

Hexagonal, one Swift package:

| Target | Role |
|---|---|
| `PhotoManagerCore` | Domain: `MediaItem`, `Selection`, `DeviceInfo`, `TransferService` and the ports `DeviceMonitor`, `DeviceSession`, `MediaTransferring`, `MediaStore`. No Apple device frameworks. |
| `PhotoManagerAdapters` | `ImageCaptureDeviceMonitor` / `ImageCaptureDeviceSession` (ImageCaptureCore) and `FileSystemMediaStore` (disk). |
| `App/` → `PhotoManagerApp` | Separate package with the SwiftUI app. `AppModel` is the only type that talks to the domain; views are presentational. |

Safety rule: **Save & Delete removes an item from the iPhone only after its copy on the Mac is verified** (same file size). A file already on the Mac with the same name and size is not trusted on its own: the item is downloaded again and compared byte by byte; an identical download is discarded, a different one is kept as a new copy. Failed copies stay on the iPhone.

Device data is limited to what ImageCaptureCore exposes: name, model, connection, battery, iCloud Photos, lock/trust state. iOS version and storage capacity are not available.

## Requirements

- macOS 26 or later.
- **Xcode 26 or later** to build the app: SwiftUI's `@State` is a compiler macro whose plugin ships only with Xcode. Core and adapters build and test with the Command Line Tools alone.

## Commands

```bash
./scripts/test.sh   # run the test suite (works with Command Line Tools only)
swift run --package-path App PhotoManager   # build and launch the app (needs Xcode)
```
