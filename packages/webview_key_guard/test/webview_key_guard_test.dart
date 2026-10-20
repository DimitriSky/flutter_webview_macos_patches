import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_key_guard/webview_key_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('webview_key_guard');
  const guard = WebViewKeyGuard();
  final calls = <MethodCall>[];
  Object? response = true;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    response = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return response;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads native state and returns the applied value', () async {
    expect(await guard.isEnabled(), isTrue);
    response = false;
    expect(await guard.setEnabled(false), isFalse);
    expect(calls.map((call) => call.method), ['getEnabled', 'setEnabled']);
    expect(calls.last.arguments, {'enabled': false});
  });

  test('invalid native state is not silently treated as enabled', () async {
    response = null;
    await expectLater(guard.isEnabled(), throwsFormatException);
  });

  test(
    'native failure propagates instead of fabricating a guard state',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'UNAVAILABLE');
          });
      await expectLater(guard.isEnabled(), throwsA(isA<PlatformException>()));
      await expectLater(
        guard.setEnabled(false),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('setEnabled rejects a non-boolean acknowledgment', () async {
    response = 'false';
    await expectLater(guard.setEnabled(false), throwsFormatException);
  });

  test('unsupported platforms do not call a missing plugin', () async {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.macOS) continue;
      debugDefaultTargetPlatformOverride = platform;
      expect(WebViewKeyGuard.supported, isFalse);
      expect(await guard.isEnabled(), isFalse);
      expect(await guard.setEnabled(true), isFalse);
    }
    expect(calls, isEmpty);
  });
}
