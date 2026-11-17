# Photo Manager

**Free up space on your iPhone from your Mac — safely.**

Plug in your iPhone, pick the photos and videos you want, and choose what happens to them:

| Action | What it does |
|---|---|
| **Save** | Copies the items to your Mac. Nothing is removed from the iPhone. |
| **Save & Delete** | Copies the items, verifies each copy, then removes them from the iPhone. |
| **Delete** | Removes the items from the iPhone without saving them. |

Native macOS app built with SwiftUI and the macOS 26 Liquid Glass design.

## Features

- Detects the iPhone as soon as it is plugged in, and guides you through unlocking it and tapping **Trust**.
- Shows the device (name, connection, battery and iCloud Photos when the iPhone reports them) and the size of its library.
- Browses the library by day, with filters for **Photos**, **Videos** and **Screenshots**.
- Selects single items, whole days or everything at once.
- Full-size preview of photos and videos, with ← → to move between items.
- Default or Large thumbnails.
- Optional folders by date (`2026/11-17`) and no duplicates of files already on the Mac.

## Safety first

Photo Manager never removes something it could not save.

- **Save & Delete removes an item only after its copy on the Mac is verified.** If a copy fails, the item stays on the iPhone.
- **A file already on the Mac is not trusted by name and size alone.** The item is downloaded again and compared byte by byte. An identical download is discarded; a different one is kept as a new copy.
- **Delete always asks first**, shows what will be removed, and offers to save a copy instead.

## Install

1. Download `PhotoManager-<version>.dmg` (or [build it](#build-the-dmg)).
2. Open it and drag **Photo Manager** into **Applications**.
3. First launch: if macOS says the app can't be checked, open **System Settings → Privacy & Security** and click **Open Anyway**. This happens only with builds that are not notarized.

Requires **macOS 26** or later.

## Development

### Requirements

- macOS 26 or later.
- **Xcode 26 or later** to build the app. SwiftUI's `@State` is a compiler macro whose plugin ships only with Xcode. The core and the adapters build and test with the Command Line Tools alone.

### Commands

```bash
./scripts/test.sh                            # run the test suite
swift run --package-path App PhotoManager    # build and launch the app
./scripts/build-app.sh                       # build build/Photo Manager.app
./scripts/build-dmg.sh                       # build dist/PhotoManager-<version>.dmg
```

### Build the DMG

`build-dmg.sh` builds a release app bundle and packs it into a DMG with an **Applications** shortcut. It is configured with environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `VERSION` | `1.0.0` | Version shown in the app and in the DMG name. |
| `BUILD_NUMBER` | commit count | `CFBundleVersion`. |
| `BUNDLE_ID` | `com.photomanager.app` | Bundle identifier. |
| `SIGN_IDENTITY` | `-` (ad-hoc) | A `Developer ID Application` identity to sign for distribution. |
| `NOTARY_PROFILE` | none | Keychain profile from `xcrun notarytool store-credentials`. When set, the DMG is notarized and stapled. |

```bash
# Local build, ad-hoc signed
VERSION=1.1.0 ./scripts/build-dmg.sh

# Signed and notarized for distribution
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=photo-manager \
VERSION=1.1.0 ./scripts/build-dmg.sh
```

To give the app an icon, add `App/Resources/AppIcon.icns`; the build script picks it up.

The bundle is built for the Mac's own architecture.

## Architecture

Hexagonal architecture, split into two Swift packages:

```
Package.swift                 PhotoManagerCore + PhotoManagerAdapters (+ tests)
App/Package.swift             PhotoManagerApp (SwiftUI), depends on the root package
```

| Target | Role |
|---|---|
| `PhotoManagerCore` | Domain: `MediaItem`, `Selection`, `DeviceInfo`, `TransferService` and the ports `DeviceMonitor`, `DeviceSession`, `MediaTransferring`, `MediaStore`. No Apple device frameworks. |
| `PhotoManagerAdapters` | `ImageCaptureDeviceMonitor` and `ImageCaptureDeviceSession` (ImageCaptureCore), and `FileSystemMediaStore` (disk). |
| `PhotoManagerApp` | SwiftUI app and composition root. `AppModel` is the only type that talks to the domain; views are presentational. |

The app is a separate package so the domain and adapters keep building and testing without Xcode.

## Limitations

- Photo Manager uses Apple's ImageCaptureCore, which only exposes photos, videos and screenshots. Apps, messages, caches and **Recently Deleted** must be cleaned on the iPhone itself.
- ImageCaptureCore does not report the iOS version or storage capacity. Model and battery appear only when the iPhone reports them.
