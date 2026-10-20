import 'package:flutter/material.dart';

import 'lab_controller.dart';
import 'variant.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({required this.lab, super.key});
  final LabController lab;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xffd4dadd))),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row([
          'Метод',
          'Последний прогон',
          'keydown',
          'Дубликаты',
          'Время',
        ], header: true),
        for (final variant in LabVariant.values)
          _row([
            '${variant.id}  ${variant.label}',
            '${lab.results[variant.id]?['status'] ?? 'Не проверен'}',
            '${lab.results[variant.id]?['keydown'] ?? '-'}',
            '${lab.results[variant.id]?['duplicates'] ?? '-'}',
            lab.results[variant.id] == null
                ? '-'
                : '${((lab.results[variant.id]!['elapsedMs'] as int) / 1000).toStringAsFixed(1)} s',
          ]),
      ],
    ),
  );

  TableRow _row(List<String> cells, {bool header = false}) => TableRow(
    children: [
      for (final cell in cells)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Text(
            cell,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: header ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
    ],
  );
}
