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
| T1 | — | inline | pending | |
| T2 | S4, S5, S6 | inline | pending | |
| T3 | S1, S2, S3, S5 | inline | pending | |
| T4 | S1–S7 | inline | pending | |

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
