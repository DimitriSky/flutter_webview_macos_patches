import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'lab_server.dart';
import 'variant.dart';

class LabController extends ChangeNotifier {
  static const channel = MethodChannel('dev.dmilab.keylab');
  late final server = LabServer(snapshot: snapshot, onReport: acceptReport);
  LabVariant variant = LabVariant.currentPackage;
  WebViewController? webView;
  Map<String, dynamic> page = {};
  Map<String, dynamic> native = {};
  final Map<String, Map<String, Object?>> results = {};
  String run = '';
  String url = '';
  String status = 'Запуск';
  String? error;
  bool busy = true;
  bool restartRequired = false;
  bool _disposed = false;
  bool _polling = false;
  bool _selecting = false;
  Timer? _timer;
  DateTime? _started;
  DateTime? _ended;

  int get elapsedMs => _started == null
      ? 0
      : (_ended ?? DateTime.now()).difference(_started!).inMilliseconds;

  Future<void> initialize() async {
    try {
      final saved = await channel.invokeMethod<String>('loadResults');
      if (saved != null) {
        final decoded = jsonDecode(saved) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final result = Map<String, Object?>.from(entry.value as Map);
          if (result['restartRequired'] != true &&
              (result['duplicates'] as int? ?? 0) > 0) {
            result['status'] = 'Повторы';
          }
          results[entry.key] = result;
        }
      }
      await server.start();
      await select(variant);
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _poll(),
      );
    } catch (e) {
      error = '$e';
      status = 'Ошибка';
      busy = false;
      _notify();
    }
  }

  Future<void> select(LabVariant next) async {
    if (restartRequired || _disposed || _selecting) return;
    _selecting = true;
    _remember();
    busy = true;
    webView = null;
    run = '';
    _notify();
    try {
      await _saveResults();
    } catch (e) {
      error = '$e';
      status = 'Ошибка сохранения';
      busy = false;
      _selecting = false;
      _notify();
      return;
    }
    // Remove the previous platform view before creating a fresh native experiment.
    await WidgetsBinding.instance.endOfFrame;
    variant = next;
    run = DateTime.now().microsecondsSinceEpoch.toString();
    page = {};
    native = {};
    error = null;
    status = 'Загрузка';
    _started = DateTime.now();
    _ended = null;
    url = '${server.baseUrl}/keys?run=$run&mode=${variant.id}';
    try {
      await channel.invokeMethod<void>('configure', {
        'mode': variant.id,
        'run': run,
      });
      if (variant == LabVariant.nativeWindow) {
        await showNative();
      } else {
        final controller = WebViewController();
        final expectedRun = run;
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        await controller.setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (event) {
              if (event.isForMainFrame == true && run == expectedRun) {
                error = event.description;
                status = 'Ошибка загрузки';
                _notify();
              }
            },
          ),
        );
        await controller.loadRequest(Uri.parse(url));
        webView = controller;
      }
    } catch (e) {
      error = '$e';
      status = 'Ошибка';
    } finally {
      busy = false;
      _selecting = false;
      _notify();
    }
  }

  void acceptReport(Map<String, dynamic> report) {
    if (_disposed || report['run'] != run || report['mode'] != variant.id) {
      return;
    }
    page = report;
    if (!restartRequired && status != 'Остановлено') status = 'Активен';
    _remember();
    if (restartRequired) unawaited(_saveResults());
    _notify();
  }

  Future<void> _poll() async {
    if (_polling || _disposed || busy) return;
    _polling = true;
    final expectedRun = run;
    try {
      final raw = await channel.invokeMethod<Object?>('snapshot');
      if (_disposed || expectedRun != run || raw == null) return;
      final report = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      if (report['run'] != run) return;
      native = report;
      final firstAbort = report['restartRequired'] == true && !restartRequired;
      if (firstAbort) _ended = DateTime.now();
      if (report['restartRequired'] == true) {
        restartRequired = true;
        status = 'Петля: нужен перезапуск';
        error = 'Аварийная остановка после 256 проходов одного события';
      }
      _remember();
      if (firstAbort) await _saveResults();
      _notify();
    } catch (e) {
      error = '$e';
      _notify();
    } finally {
      _polling = false;
    }
  }

  Future<void> stop() async {
    _ended = DateTime.now();
    await channel.invokeMethod<void>('stop');
    webView = null;
    status = restartRequired ? 'Петля: нужен перезапуск' : 'Остановлено';
    _remember();
    await _saveResults();
    _notify();
  }

  Future<void> showNative() => channel.invokeMethod<void>('openNative', url);

  void _remember() {
    if (run.isEmpty || (page['keydowns'] ?? 0) == 0) return;
    results[variant.id] = {
      'run': run,
      'status': restartRequired
          ? 'Петля'
          : error != null
          ? 'Ошибка'
          : (page['duplicates'] ?? 0) > 0
          ? 'Повторы'
          : 'Нет повторов',
      'keydown': page['keydowns'] ?? 0,
      'duplicates': page['duplicates'] ?? 0,
      'repeat': page['repeats'] ?? 0,
      'elapsedMs': elapsedMs,
      'error': error,
      'restartRequired': restartRequired,
    };
  }

  Future<void> _saveResults() =>
      channel.invokeMethod<void>('saveResults', jsonEncode(results));

  Map<String, Object?> snapshot() => {
    'run': run,
    'mode': variant.id,
    'url': url,
    'status': status,
    'error': error,
    'restartRequired': restartRequired,
    'elapsedMs': elapsedMs,
    'page': page,
    'native': native,
    'results': results,
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(server.close());
    super.dispose();
  }
}
