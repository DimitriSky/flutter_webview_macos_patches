import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'lab_controller.dart';
import 'matrix_view.dart';
import 'results_view.dart';
import 'variant.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  late final LabController lab;
  bool controlsVisible = true;

  @override
  void initState() {
    super.initState();
    lab = LabController();
    unawaited(lab.initialize());
  }

  @override
  void dispose() {
    lab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: lab,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          'WebView Key Lab  /  ${lab.variant.id}',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Матрица клавиш',
            icon: const Icon(Icons.grid_on),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MatrixView(lab: lab),
            ),
          ),
          IconButton(
            tooltip: 'Новый прогон',
            icon: const Icon(Icons.refresh),
            onPressed: lab.busy || lab.restartRequired
                ? null
                : () => lab.select(lab.variant),
          ),
          IconButton(
            tooltip: 'Остановить',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: lab.busy ? null : lab.stop,
          ),
          IconButton(
            tooltip: 'Панель эксперимента',
            icon: const Icon(Icons.tune),
            onPressed: () => setState(() => controlsVisible = !controlsVisible),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (lab.error != null)
            MaterialBanner(
              backgroundColor: const Color(0xffffe5e2),
              content: Text(lab.error!),
              actions: [Text(lab.status)],
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controlsVisible) SizedBox(width: 242, child: _controls()),
                const VerticalDivider(width: 1),
                Expanded(child: _browser()),
              ],
            ),
          ),
          if (controlsVisible) ResultsView(lab: lab),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xffe9edef),
            child: Row(
              children: [
                Expanded(child: Text(lab.status, maxLines: 2)),
                Text('${(lab.elapsedMs / 1000).toStringAsFixed(1)} s'),
                const SizedBox(width: 20),
                Text(
                  lab.url.isEmpty ? '' : lab.server.baseUrl,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _controls() => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'МЕТОД',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 8),
      RadioGroup<LabVariant>(
        groupValue: lab.variant,
        onChanged: (value) {
          if (value != null && !lab.busy && !lab.restartRequired) {
            unawaited(lab.select(value));
          }
        },
        child: Column(
          children: [
            for (final item in LabVariant.values)
              RadioListTile<LabVariant>(
                value: item,
                enabled: !lab.busy && !lab.restartRequired,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  '${item.id}  ${item.label}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      const Divider(height: 32),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Flutter input',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _metric('keydown', lab.page['keydowns']),
            _metric('Дубликаты JS', lab.page['duplicates']),
            _metric('Удержание', lab.page['repeats']),
            _metric('preventDefault', lab.page['prevented']),
            const Divider(height: 24),
            _metric(
              'webview_key_guard',
              lab.native['packageEnabled'] == true ? 'On' : 'Off',
            ),
            _metric('WebKit calls', lab.native['webKit']?['calls']),
            _metric('Flutter calls', lab.native['flutter']?['calls']),
            _metric('Перенаправлено', lab.native['routed']),
            _metric('Перехвачено стендом', lab.native['suppressed']),
            const SizedBox(height: 20),
            Text(
              'Focus: ${lab.page['focus'] ?? '-'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _metric(String name, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
        Text('${value ?? 0}'),
      ],
    ),
  );

  Widget _browser() {
    if (lab.busy) return const Center(child: CircularProgressIndicator());
    if (lab.variant == LabVariant.nativeWindow) {
      return Center(
        child: FilledButton.icon(
          onPressed: lab.showNative,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Нативное окно D'),
        ),
      );
    }
    if (lab.webView == null) return const Center(child: Text('Нет страницы'));
    return WebViewWidget(key: ValueKey(lab.run), controller: lab.webView!);
  }
}
