import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_hover_guard/webview_hover_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('webview_hover_guard');
  const guard = WebViewHoverGuard();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'enabled': call.arguments?['enabled'] ?? true, 'skipped': 3};
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('status and switch go to the native plugin on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(await guard.status(), {'enabled': true, 'skipped': 3});
    expect((await guard.setEnabled(false))['enabled'], false);
    expect(calls.map((c) => c.method), ['status', 'setEnabled']);
    expect(calls.last.arguments, {'enabled': false});
  });

  test('other platforms never call the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await guard.status(), {'supported': false});
    expect(await guard.setEnabled(true), {'supported': false});
    expect(calls, isEmpty);
  });
}
