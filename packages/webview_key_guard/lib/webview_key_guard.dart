import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The native preference is loaded before the first Flutter frame.
class WebViewKeyGuard {
  const WebViewKeyGuard({
    MethodChannel channel = const MethodChannel('webview_key_guard'),
  }) : _channel = channel;

  final MethodChannel _channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  Future<bool> isEnabled() => _invoke('getEnabled');

  /// Disables both B2 routing and the B3 command boundary when false.
  Future<bool> setEnabled(bool enabled) =>
      _invoke('setEnabled', {'enabled': enabled});

  Future<bool> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (!supported) return false;
    final result = await _channel.invokeMethod<Object?>(method, arguments);
    if (result is! bool) {
      throw const FormatException('Invalid WebView key guard state');
    }
    return result;
  }
}
