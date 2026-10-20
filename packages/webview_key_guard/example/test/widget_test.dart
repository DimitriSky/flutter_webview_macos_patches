import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webview_repeated_keys/lab/key_matrix.dart';
import 'package:flutter_webview_repeated_keys/lab/lab_controller.dart';
import 'package:flutter_webview_repeated_keys/lab/variant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LabController.channel, (_) async => null);
  });
  test('matrix covers every key with all 16 modifier sets', () {
    final matrix = buildKeyMatrix();
    expect(matrix.length, 74 * 16);
    expect(matrix.map((e) => e.chord).toSet().length, matrix.length);
    for (final key in matrixKeys) {
      expect(
        matrix.where((e) => e.key == key).map((e) => e.mask).toSet(),
        Set.of(List.generate(16, (index) => index)),
      );
    }
  });

  test('dangerous global shortcuts are never in the automatic list', () {
    for (final item in buildKeyMatrix()) {
      if (item.command &&
          ['q', 'w', 'h', 'm', 'n', 'Tab', 'space'].contains(item.key)) {
        expect(item.manualReason, isNotNull, reason: item.chord);
      }
    }
    expect(const KeyCase('Escape', 5).manualReason, isNotNull);
    expect(const KeyCase('d', 5).manualReason, isNotNull);
    expect(const KeyCase('b', 1).manualReason, isNull);
    expect(const KeyCase('Return', 13).manualReason, isNull);
  });

  test('unique modes including both keyDown routing controls', () {
    expect(LabVariant.values.map((e) => e.id).toSet(), {
      'P',
      '0',
      'A',
      'B',
      'B1',
      'B2',
      'B3',
      'C',
      'C2',
      'D',
      'E',
    });
  });

  test('new runs default to the current package', () {
    final lab = LabController();
    expect(lab.variant, LabVariant.currentPackage);
    expect(lab.snapshot()['mode'], 'P');
    lab.dispose();
  });

  test('package reports do not overwrite historical B3 results', () {
    final lab = LabController()..run = 'package-run';
    lab.acceptReport({'run': 'package-run', 'mode': 'B3', 'keydowns': 9});
    expect(lab.page, isEmpty);
    lab.acceptReport({'run': 'package-run', 'mode': 'P', 'keydowns': 3});
    expect(lab.results['P']!['keydown'], 3);
    expect(lab.results.containsKey('B3'), isFalse);
    lab.dispose();
  });

  test('reports from a previous run or other mode are ignored', () {
    final lab = LabController()
      ..variant = LabVariant.routing
      ..run = 'current';
    lab.acceptReport({'run': 'previous', 'mode': 'B', 'keydowns': 999});
    lab.acceptReport({'run': 'current', 'mode': 'A', 'keydowns': 999});
    expect(lab.page, isEmpty);
    lab.acceptReport({'run': 'current', 'mode': 'B', 'keydowns': 1});
    expect(lab.page['keydowns'], 1);
    lab.dispose();
  });

  test('an aborted run cannot silently become active again', () {
    final lab = LabController()
      ..variant = LabVariant.routing
      ..run = 'current'
      ..restartRequired = true
      ..status = 'aborted';
    lab.acceptReport({'run': 'current', 'mode': 'B', 'keydowns': 256});
    expect(lab.status, 'aborted');
    expect(lab.results['B']!['restartRequired'], true);
    lab.dispose();
  });
}
