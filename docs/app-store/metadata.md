# App Store listing: Easy Photo Saver

Copy each field into App Store Connect. Limits are in brackets.

## App Information

**Name** [30]: `Easy Photo Saver`

**Subtitle** [30]: `Free up iPhone storage safely`

**Category**: Primary `Photography`, secondary `Utilities`

**Privacy Policy URL**: `https://github.com/Juan-Motta/iphoto-manager/blob/main/docs/privacy-policy.md`

## Version 1.0

**Promotional Text** [170]:

```
Free up space on your iPhone in minutes. Save photos and videos to your Mac, check every copy, then remove them from the phone. All in one simple window.
```

**Description** [4000]:

```
Your iPhone is full, and you don't want to lose a single photo. Easy Photo Saver moves your photos and videos to your Mac and frees up the space on your iPhone, safely.

Plug in your iPhone, pick what you want, and choose what happens:

• Save: copy photos and videos to your Mac. Your iPhone stays as it is.
• Save & Delete: copy them to your Mac, check every copy, then remove them from your iPhone. The fastest way to free up space.
• Delete: remove items from your iPhone without keeping a copy.

SAFE BY DESIGN
• Nothing is removed until its copy is checked. With Save & Delete, each item leaves your iPhone only after its copy on your Mac is complete. If a copy fails, the item stays on your iPhone.
• No guessing about duplicates. If a file with the same name is already on your Mac, the two are compared byte by byte before deciding it's the same photo.
• You always confirm first. Before anything is deleted, you see exactly what will go and how much space you'll get back.

SIMPLE TO USE
• Detects your iPhone as soon as you plug it in, and guides you through unlocking it and tapping Trust.
• Browse your library by day, with filters for Photos, Videos and Screenshots.
• Select single items, whole days or everything at once. The bar at the bottom always shows how much space you picked.
• Open any photo or video full size before you decide, and move through your library with the arrow keys.
• Choose Default or Large thumbnails.
• Save into one folder per day, or into any folder you choose.

PRIVATE
Everything happens between your iPhone and your Mac over the cable. No account, no cloud, no tracking: Easy Photo Saver collects no data.

GOOD TO KNOW
• Works with the photos, videos and screenshots on your iPhone. To free up space used by apps or messages, use Settings › General › iPhone Storage on the iPhone.
• If iCloud Photos is on, deleting from your iPhone can also delete the photo from iCloud and your other devices. The app shows whether iCloud Photos is on.
• Requires a USB cable.
```

**Keywords** [100]:

```
storage,free up space,transfer,import,backup,delete,cleanup,offload,camera roll,videos,pictures,usb
```

**Support URL**: `https://github.com/Juan-Motta/iphoto-manager/issues`

**Marketing URL** (optional): `https://github.com/Juan-Motta/iphoto-manager`

**Copyright**: `2026 Juan Andres Lopez Motta`

**Screenshots** (2880×1800, in order): `docs/app-store/screenshots/1-library.png` to `5-waiting.png`.
Regenerate them with `./scripts/store-screenshots.sh`.

## App Review Information

**Sign-in required**: No.

**Notes**:

```
Easy Photo Saver needs an iPhone connected to the Mac with a USB cable. There is no account or sign-in.

How to test:
1. Launch the app. It shows "Connect your iPhone" with three steps.
2. Connect an iPhone with a USB cable and unlock it. If the iPhone asks, tap "Trust" and enter its passcode. The library appears within a few seconds, grouped by day.
3. Select a few photos by clicking them, then click "Save". The copies are saved to Pictures › iPhone Import, in one folder per day. Click "Show in Finder" in the result to see them.
4. Select a photo and click "Save & Delete". The app copies it to the Mac, verifies the copy, and only then removes it from the iPhone. The confirmation sheet shows exactly what will be removed.
5. Optional: hover over a photo and click the expand button (or right-click > Preview) to see it full size.

Notes:
- The app uses ImageCaptureCore to read the iPhone over USB (com.apple.security.device.usb entitlement), writes to the Pictures folder (com.apple.security.assets.pictures.read-write), and to any folder the user picks with the open panel (com.apple.security.files.user-selected.read-write).
- Nothing is deleted without a confirmation. Items whose copy fails are never deleted.
- The app collects no data and makes no network requests.
```

## App Privacy

**Data Collection**: `No, we do not collect data from this app`.
