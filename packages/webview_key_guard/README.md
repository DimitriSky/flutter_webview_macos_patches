# Flutter WebView Key Guard

An optional Flutter plugin that prevents keyboard events from being
redispatched repeatedly to an embedded macOS WebView. It does not patch
application code or the Flutter SDK. Other platforms do not invoke the
plugin's native channel.

## Behavior

A single native event object must not be interpreted repeatedly by the
original WebView. New key presses and normal auto-repeat while holding
a key remain separate events.

The guard has two parts:

- When the WebView has focus, key redispatch bypasses Flutter's deferred
  queue; repeated delivery of the same event object is stopped at this boundary.
- While a native command executes, the original event is prevented from
  re-entering its WebView. The command context is cleared afterward.

There is no shortcut-specific list, debounce, WKWebView method swizzling,
or JavaScript filter in the application. The package does not depend on
an application's server, navigation, logging, or settings implementation.

## Installation

For a consuming application's `pubspec.yaml`, use the repository URL and
pin an immutable commit:

```yaml
dependencies:
  webview_key_guard:
    git:
      url: https://github.com/DimitriSky/flutter_webview_key_guard.git
      ref: 07cf45b4f041655802ab4d0230abe06be8e28153
```

Then run `flutter pub get` from the application directory. The snippet pins
the existing published package revision. The example in this checkout uses
`path: ..` instead. Publishing to pub.dev is not required.

### Native Integration

In the macOS application bootstrap:

1. Import `webview_key_guard`.
2. Subclass `WebViewKeyGuardWindow` for the application window.
3. Use `WebViewKeyGuardFlutterViewController` instead of the standard
   `FlutterViewController`.
4. Assign `contentViewController = keyGuardHost(for: controller)`.
5. Keep the usual `RegisterGeneratedPlugins` registration.

These changes modify the existing bootstrap; they do not create a second
window. Preserve the application's window sizing and lifecycle behavior.
The integration requires both the guarded controller and the guarded
window's host.

Swift Package Manager and CocoaPods are supported. The root `Package.swift`
is for standalone native tests; the one in `macos/webview_key_guard` is
used by the Flutter integration.
Rebuild and restart the application after changing Swift code.

### Enabling and Disabling

```dart
const guard = WebViewKeyGuard();
final enabled = await guard.isEnabled();
await guard.setEnabled(false);
```

In your Dart file, import
`package:webview_key_guard/webview_key_guard.dart`.

The guard is enabled by default. The setting is stored in the application's
`UserDefaults` under `webview_key_guard.enabled.v1` and read before the first
Flutter frame. The application owns the settings UI and error handling.

Disabling the guard turns off both parts and restores standard event handling.
The original failure may return, so compare modes on a diagnostic page,
not on a page that performs user actions.
On unsupported platforms, the API returns `false` without a native call.

## Testing

The standalone [macOS comparison app](example/README.md) lives in `example/`.
It uses `path: ..` to test the source in this checkout, with historical
controls, a loopback probe, and [saved evidence](example/evidence/LAB-RESULTS.md).
Its earlier lab history was not imported. Existing evidence retains its
original test scope; it does not establish a pass on a new build.

The [isolated package audit](docs/review-loops-2026-10-08.md) records current
review rounds, new regression coverage, and separate verification limits.

Use Flutter 3.47.5 on your PATH for the example's existing toolchain:

```sh
cd example
flutter pub get
flutter analyze
flutter test
node --test scripts/*_test.mjs
flutter run -d macos
```

From the package root:

```sh
swift test
flutter pub get
flutter test --no-pub
flutter analyze --no-pub
node tool/keyboard_probe.mjs
```

Native tests cover routing for 128 key codes and 16 modifier combinations,
setting persistence, nested commands, and neighboring native cancel buttons.
They verify routing rules, not physical keyboard input for every combination.
Dart tests cover the API, invalid channel responses, and platforms without
the native plugin.

The diagnostic server listens only on loopback, uses an automatically
selected port, and prints its address at startup. It keeps at most eight
runs in memory. The page collects key codes, modifiers, and event counts;
do not enter passwords or other sensitive information.
Emergency event suppression in the diagnostic tool indicates a failed
test, not successful protection by the guard.

### Limitations

- Synthetic input does not replace physical keyboard testing.
- Previous successful tests do not establish correctness for every Flutter,
  macOS, or WebKit version, or every window configuration.
- Native views neighboring the original WebView retain shortcut handling,
  but custom handlers in its ancestors require separate verification.
- In the integrating application, separately test held keys, focus changes,
  text editing, and system dialogs.

## Removal

Restore the standard `NSWindow` and `FlutterViewController`, then remove
the guarded host, import, and application-owned settings toggle.
Remove the dependency, run `flutter pub get`, and rebuild the application.
There is no need to delete the package repository.

## Publishing Metadata

The repository and podspec homepage point to
[flutter_webview_key_guard](https://github.com/DimitriSky/flutter_webview_key_guard).
The current license type in the podspec is `Proprietary`. Removing personal
information does not change the licensing terms.

## Documentation

- [Flutter packages](https://docs.flutter.dev/packages-and-plugins/using-packages).
- [SwiftPM integration](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors).
- [Dart dependencies](https://dart.dev/tools/pub/dependencies).
- [AppKit keyboard events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingKeyEvents/HandlingKeyEvents.html).
