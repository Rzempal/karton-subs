import 'package:flutter/material.dart';

/// Wspólny dialog podsumowania importu z Excela (subskrypcje / budżet).
Future<void> showImportSummaryDialog(
  BuildContext context, {
  required String title,
  required int importedCount,
  required String importedNoun,
  List<String> skipped = const [],
  List<String> warnings = const [],
}) async {
  final details = <String>[];
  if (warnings.isNotEmpty) {
    details.add('Ostrzeżenia:');
    details.addAll(warnings.map((w) => '• $w'));
  }
  if (skipped.isNotEmpty) {
    if (details.isNotEmpty) details.add('');
    details.add('Pominięte wiersze (${skipped.length}):');
    details.addAll(skipped.map((s) => '• $s'));
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dodano $importedCount $importedNoun.'),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(details.join('\n'),
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
