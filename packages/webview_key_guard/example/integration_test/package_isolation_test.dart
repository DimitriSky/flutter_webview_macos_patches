import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_key_guard/webview_key_guard.dart';

const bridge = MethodChannel('dev.dmilab.keylab');
const guard = WebViewKeyGuard();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isolated package preserves native keys, repeats and editing', (
    tester,
  ) async {
    debugPrint('KEY_GUARD_TEST_EXECUTABLE=${Platform.resolvedExecutable}');
    final originalEnabled = await guard.isEnabled();
    final loaded = Completer<void>();
    final web = WebViewController();
    final flutterText = TextEditingController();
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!loaded.isCompleted) loaded.complete();
        },
      ),
    );

    Future<void> wait(bool Function() condition, String reason) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) fail(reason);
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    Future<Map<String, dynamic>> state() async =>
        jsonDecode(
              await web.runJavaScriptReturningResult(
                    'JSON.stringify(window.keyProbe)',
                  )
                  as String,
            )
            as Map<String, dynamic>;

    Future<void> focus(String id) async {
      expect(await bridge.invokeMethod<bool>('reviewFocus', 'web'), isTrue);
      await web.runJavaScript('document.getElementById("$id").focus()');
      await tester.pump();
    }

    Future<void> key(
      int code,
      String text, {
      int mask = 0,
      bool up = false,
      bool repeat = false,
    }) async {
      await bridge.invokeMethod<void>('reviewKey', {
        'code': code,
        'text': text,
        'mask': mask,
        'up': up,
        'repeat': repeat,
      });
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    Future<void> press(int code, String text, {int mask = 0}) async {
      await key(code, text, mask: mask);
      await key(code, text, mask: mask, up: true);
    }

    try {
      await bridge.invokeMethod<void>('configure', {
        'mode': 'P',
        'run': 'isolated-review',
      });
      final native = Map<String, dynamic>.from(
        await bridge.invokeMapMethod('snapshot') ?? {},
      );
      expect(native['implementation'], 'webview_key_guard');
      expect(native['packageEnabled'], isTrue);
      expect(
        native['webKitObservationEnabled'],
        isFalse,
        reason: 'Run with KEY_LAB_WEBKIT_OBSERVATION=off',
      );
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: flutterText),
                Expanded(child: WebViewWidget(controller: web)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await web.loadHtmlString(
        '''<!doctype html><input id="input"><textarea id="textarea"></textarea>
        <div id="editor" contenteditable="true"></div><script>
        window.keyProbe = {downs: 0, ups: 0, repeats: 0, duplicates: 0, prevented: 0, events: []};
        const seen = new Set();
        document.addEventListener('keydown', e => {
          const p = window.keyProbe, identity = [e.timeStamp,e.code,e.repeat].join(':');
          if (seen.has(identity)) p.duplicates++; seen.add(identity);
          p.downs++; if (e.repeat) p.repeats++; if (e.defaultPrevented) p.prevented++;
          p.events.push({code:e.code,target:e.target.id,trusted:e.isTrusted});
        }); document.addEventListener('keyup', () => window.keyProbe.ups++);
        </script>''',
      );
      await wait(() => loaded.isCompleted, 'Owned WebView did not load');
      await tester.pumpAndSettle();

      // Native AppKit queue input to all three actual WebKit editing targets.
      for (final id in ['input', 'textarea', 'editor']) {
        await focus(id);
        final before = (await state())['downs'] as int;
        for (final chord in [(53, '\u001b', 8), (11, 'b', 1), (36, '\r', 1)]) {
          await press(chord.$1, chord.$2, mask: chord.$3);
        }
        final after = await state();
        expect(
          after['downs'],
          before + 3,
          reason: '$id: one keydown per native press',
        );
        expect(after['duplicates'], 0);
      }

      await focus('input');
      final beforeRepeats = await state();
      await key(0, 'a');
      for (var i = 0; i < 4; i++) {
        await key(0, 'a', repeat: true);
      }
      await key(0, 'a', up: true);
      final repeated = await state();
      expect(repeated['downs'], (beforeRepeats['downs'] as int) + 5);
      expect(repeated['repeats'], 4);
      expect(repeated['ups'], (beforeRepeats['ups'] as int) + 1);
      expect(repeated['duplicates'], 0);

      // Standard native editing, without using the system clipboard.
      await press(0, 'a', mask: 1);
      expect(
        await web.runJavaScriptReturningResult(
          'document.getElementById("input").selectionEnd-document.getElementById("input").selectionStart',
        ),
        5,
      );
      await press(11, 'b');
      expect(
        await web.runJavaScriptReturningResult(
          'document.getElementById("input").value',
        ),
        'b',
      );
      await press(6, 'z', mask: 1);
      expect(
        await web.runJavaScriptReturningResult(
          'document.getElementById("input").value',
        ),
        'aaaaa',
      );
      await press(6, 'z', mask: 9);
      expect(
        await web.runJavaScriptReturningResult(
          'document.getElementById("input").value',
        ),
        'b',
      );

      // Off passes an ordinary key; re-enable and verify the next fresh press.
      expect(await guard.setEnabled(false), isFalse);
      await press(2, 'd');
      expect(await guard.setEnabled(true), isTrue);
      await press(14, 'e');
      expect(
        await web.runJavaScriptReturningResult(
          'document.getElementById("input").value',
        ),
        'bde',
      );

      final pageBeforeFlutter = await state();
      await tester.tap(find.byType(TextField));
      expect(await bridge.invokeMethod<bool>('reviewFocus', 'flutter'), isTrue);
      await press(3, 'f');
      await wait(
        () => flutterText.text == 'f',
        'Flutter text input did not receive native key',
      );
      expect((await state())['downs'], pageBeforeFlutter['downs']);
      await focus('input');
      await press(5, 'g');
      final finalPage = await state();
      expect(
        finalPage['downs'],
        (pageBeforeFlutter['downs'] as int) + 1,
        reason: 'Fresh WebView input must resume after returning from Flutter',
      );
      expect(finalPage['duplicates'], 0);
      expect(finalPage['prevented'], 0);
      expect(
        (finalPage['events'] as List).every((e) => e['trusted'] == true),
        isTrue,
      );
      final finalNative = Map<String, dynamic>.from(
        await bridge.invokeMapMethod('snapshot') ?? {},
      );
      expect(finalNative['restartRequired'], isFalse);
      expect(finalNative['suppressed'], 0);
      expect(finalNative['routed'], 0);
      expect(
        (finalNative['commandRouting'] as Map)['commands'],
        0,
        reason: 'Historical B3 must not participate',
      );
      final evidence = {
        'kind': 'self-posted AppKit events, observation disabled',
        'passed': true,
        'downs': finalPage['downs'],
        'ups': finalPage['ups'],
        'repeats': finalPage['repeats'],
        'duplicates': finalPage['duplicates'],
        'prevented': finalPage['prevented'],
        'labSuppressed': finalNative['suppressed'],
        'labRouted': finalNative['routed'],
        'restartRequired': finalNative['restartRequired'],
        'physicalKeyboardQualified': false,
      };
      debugPrint('KEY_GUARD_REVIEW_RESULT=${jsonEncode(evidence)}');
    } finally {
      await guard.setEnabled(originalEnabled);
      runApp(const SizedBox());
      await tester.pumpAndSettle();
      flutterText.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
