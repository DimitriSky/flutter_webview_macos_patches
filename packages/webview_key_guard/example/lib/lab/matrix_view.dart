import 'package:flutter/material.dart';

import 'key_matrix.dart';
import 'lab_controller.dart';

class MatrixView extends StatefulWidget {
  const MatrixView({required this.lab, super.key});
  final LabController lab;

  @override
  State<MatrixView> createState() => _MatrixViewState();
}

class _MatrixViewState extends State<MatrixView> {
  final matrix = buildKeyMatrix();
  String filter = '';

  @override
  Widget build(BuildContext context) {
    final visible = matrix
        .where((e) => e.chord.toLowerCase().contains(filter.toLowerCase()))
        .toList();
    return Dialog(
      child: SizedBox(
        width: 650,
        height: 580,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Матрица: ${matrix.length} сочетаний',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Сочетание',
                ),
                onChanged: (value) => setState(() => filter = value),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (_, index) {
                  final item = visible[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.chord),
                    subtitle: item.manualReason == null
                        ? null
                        : Text(item.manualReason!),
                    trailing: Text(_result(item)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _result(KeyCase item) {
    final bucket = widget.lab.page['combinations']?[item.browserChord];
    if (bucket != null) {
      return (bucket['duplicates'] as int) > 0
          ? 'Дубликаты: ${bucket['duplicates']}'
          : 'Получено: ${bucket['count']}';
    }
    return item.manualReason == null ? 'Нет результата' : 'Ручная проверка';
  }
}
