import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The fix is active as soon as the plugin is a dependency of a macOS app.
/// This class only exposes diagnostics and a switch for A/B checks.
class WebViewHoverGuard {
  const WebViewHoverGuard({
    this.channel = const MethodChannel('webview_hover_guard'),
  });

  final MethodChannel channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// `enabled`, `patched` and `missing` engine class names, `skipped` re-adds.
  Future<Map<String, dynamic>> status() async {
    if (!supported) return {'supported': false};
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('status') ?? {},
    );
  }

  /// Turns the fix off and on at runtime, e.g. to show the bug for comparison.
  Future<Map<String, dynamic>> setEnabled(bool enabled) async {
    if (!supported) return {'supported': false};
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('setEnabled', {
            'enabled': enabled,
          }) ??
          {},
    );
  }
}
