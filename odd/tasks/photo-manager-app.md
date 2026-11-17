# Photo Manager app

Objective: native macOS app that detects a connected iPhone, shows device data and its media, and saves/deletes a selection.
Branch: `feat/photo-manager-app` · Delivery: ask-on-risk · Test runner: `swift test` (Swift Testing, Command Line Tools).

## Specs

- S1. "que el programa detecte el iphone" — the app detects an iPhone when it is connected and when it is disconnected.
- S2. "muestre datos del celular" — show device data available from ImageCaptureCore only (user decision: "Solo ImageCaptureCore"): name, model, connection, battery, media count/size, iCloud Photos flag, locked/trust state. No iOS version, no total storage.
- S3. "y sus imagenes" — show the iPhone's photos and videos as a thumbnail grid.
- S4. "el poder selecionar algunas, todas" — select individual items, all items, and clear the selection.
- S5. "decidir si guardar, guardar y eliminar o solo veliminar" — three actions: Save, Save & Delete, Delete.
- S6. Safety rule (from approved design): Save & Delete removes from the iPhone only items whose copy on the Mac was completed and verified; failed copies stay on the iPhone. Delete-only and Save & Delete require confirmation.
- S7. "quiero que uses los disenos actualizados de liquid glass" — UI follows the approved canvas (https://claude.ai/artifact/FmmVQtYwq26i2FMsHSGVYn) using SwiftUI Liquid Glass APIs.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | — | inline | done | cef38cf |
| T2 | S4, S5, S6 | inline | done (19 tests) | cef38cf |
| T3 | S1, S2, S3, S5 | inline | done (6 store tests; ImageCaptureCore adapter compile-checked only, needs a real iPhone) | 821ce24 |
| T4 | S1–S7 | inline | partial: type-checks; real build blocked on Xcode | see log |

- T1: Swift Package scaffold (Core library, App executable, tests).
- T2: Domain models + selection + transfer use cases, test-first.
- T3: ImageCaptureCore `DeviceGateway` adapter + file-system `MediaStore` adapter.
- T4: SwiftUI screens (waiting, library, confirm, progress) with Liquid Glass.

## Log

- L1 (2026-11-16): "quiero trabajar en un nuevo proyecto para simplificar el borrado y guardado de imagenes, lo que quiero es que el programa detecte el iphone, muestre datos del celular y sus imagenes y el poder selecionar algunas, todas y decidir si guardar, guardar y eliminar o solo veliminar, antes que todo me gustaria tener disenos y quiero que uses los disenos actualizados de liquid glass"
- L2: Designs approved: "Se ven bien, sigamos".
- L3: Verified in SDK headers: ImageCaptureCore exposes name, productKind, transportType, serialNumberString, batteryLevel, locked, accessRestrictedAppleDevice, iCloudPhotosEnabled, mediaFiles, requestDownloadFile, requestDeleteFiles. No iOS version or storage capacity.
- L4: User decision: "Solo ImageCaptureCore". Design sidebar updated accordingly.
- L5: Environment: no Xcode, Command Line Tools only (Swift 6.4.2, SDK 27.2); Swift Testing available. Packaging a signed .app will need Xcode later.
- L6: RED/GREEN for T2 observed with `./scripts/test.sh` (wraps the Swift Testing plugin path missing from CLT).
- L7: Bug found by test: `URL.resourceValues` returned a cached file size; store now reads `FileManager.attributesOfItem`.
- L8: T4 blocker: SDK 27 `@State` is a macro; `SwiftUIMacros` plugin ships only with Xcode. Full app type-checked and linked in a scratch copy with an `@State` shim. Needs Xcode 26+ to build and run. HEIC→JPEG toggle from the design was dropped: conversion would break size verification and was not requested.
- L9: Independent verifier: S5 pass, S6 pass in core. Blocker fixed: the selection carried over to a newly connected device (PTP handle ids collide), so the wrong items could be deleted. `.connected` now resets device state, and transfer results apply only to the device that ran them. Also fixed: guard against a double Confirm, and a size-0 item is never a verified copy (RED/GREEN test). Open advisories: `.alreadySaved` (name+size) still authorizes deletion; Live Photo sidecars need a check on a real device.
- L10: User: "Yes, tighten it". Save & Delete no longer trusts name + size: existing copies are re-downloaded and compared byte by byte (`MediaStore.contentsEqual`); identical downloads are removed, different ones kept as new copies. Plain Save keeps the fast name + size skip. RED (compile + fake path) → GREEN, 30 tests.
- L11 (real iPhone, 4,981 items): (a) a fresh iPhone is access-restricted and `requestOpenSession` fails with -9943 "Please unlock"; the monitor dropped the device. Now `.connected` is emitted immediately and the session is reopened when the restriction is removed. (b) iPhones report `ptpObjectHandle` 0 for every file, so all items shared one id (one tile per day; deletion mapping would hit wrong items). Ids now come from the camera item's object identity, and a library with duplicate ids is refused (`LibraryIntegrity`, tested). Verified on device: grid shows real thumbnails and correct counts. Model shows "iPhone" and battery "—": that is all ImageCaptureCore reports for this device. Transfers not yet exercised on the device.
- L12 (2026-11-16): "me gustaria tener una opcion de preview de la foto o video" — full-size preview overlay (hover button or context menu on a tile), originals downloaded to a temp folder only for display, video via AVKit, ← → navigation following the visible order (tested `neighbor(of:step:)`), Select toggle, Esc to close. Temp folder removed when the device resets.
- L13: Crash (SIGTRAP, `dispatch_assert_queue`) when the preview downloaded an original: ImageCaptureCore runs request completions on its own queues (`ICDeviceWriteQueue`), but closures written inside the @MainActor session inherited main-actor isolation and Swift 6 trapped. All completions are now `@Sendable` (nonisolated). Verified on the real iPhone with an adapter probe: download completed and verified by size (201,832 bytes). Save/Save & Delete use the same path and were affected too.
- L14: Crash (SIGABRT) opening a video preview: SwiftUI `VideoPlayer` aborted with "failed to demangle superclass of VideoPlayerView from mangled name 'So12AVPlayerViewC'". A probe showed `AVPlayerView` itself loads and instantiates fine, so linking AVKit was not the fix (tried and reverted). Replaced `VideoPlayer` with an `NSViewRepresentable` around `AVPlayerView`.
- L15 (2026-11-16): "mejora el modal de confirmar eliminacion" — confirm sheet redesigned: glass icon, title by kind ("Delete 5 videos?"), names the device, no selection circles on thumbnails, readable warning in a glass card instead of red-on-red, "Save a copy first, then delete" switches the sheet to Save & Delete in place, confirm button names what it deletes.
