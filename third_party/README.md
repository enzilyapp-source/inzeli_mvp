# Native library fixes for Enzily

These are small source copies, used through `dependency_overrides` in the app's
`pubspec.yaml`. The upstream licenses are retained in each package. Do not edit the
developer's `.pub-cache` or generated `ios/Pods` to maintain these changes.

| Package | Upstream version | Local changes |
| --- | --- | --- |
| mobile_scanner | 7.4.2 | Replace the legacy iOS camera enumeration fallback with `AVCaptureDevice.DiscoverySession`. Remove the unused camera binding in the zoom observer. |
| audioplayers_darwin | 6.4.0 | Run KVO-driven player state changes on `MainActor`, resume the preparation continuation once, and handle player disposal. Use the modern Bluetooth HFP option with its equivalent bit value on older iOS. |

Only example apps, upstream tests and publishing screenshots are omitted. The
app uses its existing Flutter 3.38.7 SDK; audioplayers 6.8.1 needs a newer Flutter
SDK, so the compatible Dart package remains 6.7.1. Native changes are compiled by
the iOS release build; the app's Dart analyzer excludes the unchanged vendor code.

To upgrade later, compare each upstream package with these sources, verify that
the fixes landed upstream, remove the corresponding override, run `flutter pub get`,
update CocoaPods, then rebuild iOS and test QR scanning, camera switching, zoom,
short sound effects, and repeated audio playback on a device.

The generated `mobile_scanner-Swift.h` can still trigger an Apple compiler warning
about `objc_ownership` on a Core Video pointer in a completely fresh module build.
The source signature implements Flutter's required texture protocol. It is not a
language setting or the App Store minimum-OS warning; this generated file is not
patched or checked into source control.

Upstream references:

- https://pub.dev/packages/mobile_scanner/changelog
- https://github.com/bluefireteam/audioplayers
