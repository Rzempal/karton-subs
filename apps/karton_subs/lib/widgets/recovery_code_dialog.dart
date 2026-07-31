// recovery_code_dialog.dart
// Okno z kodem odzyskiwania kopii zapasowych.
//
// [firstTime] = przed pierwszym eksportem. [backedUp] = kod siedzi w sejfie
// konta Google i wroci sam na nowym telefonie — wtedy okno tylko informuje,
// zamiast wymuszac "Zapisalem kod". Bramka z kodem odstrasza osoby
// nietechniczne, a kopia i tak zostaje bez zapisanego kodu (ADR-012 w APPteczce).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/backup_crypto_service.dart';

/// Zwraca true, gdy uzytkownik potwierdzil (albo tylko przeczytal informacje).
Future<bool?> showRecoveryCodeDialog(
  BuildContext context,
  String code, {
  required bool firstTime,
  required bool backedUp,
}) {
  final formatted = BackupCryptoService.formatRecoveryCode(code);
  final mustSaveManually = firstTime && !backedUp;

  return showDialog<bool>(
    context: context,
    barrierDismissible: !mustSaveManually,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        icon: Icon(
          LucideIcons.key,
          size: 32,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Kod odzyskiwania'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                firstTime
                    ? 'Tym kodem szyfrowane będą Twoje kopie zapasowe. '
                          'Zapisz go w bezpiecznym miejscu (menedżer haseł, '
                          'wydruk) — bez niego nie odtworzysz kopii na nowym '
                          'telefonie.'
                    : 'Tym kodem odszyfrujesz kopię zapasową na innym '
                          'urządzeniu. Znajdziesz go tu zawsze w razie potrzeby.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _VaultStatus(backedUp: backedUp),
              const SizedBox(height: 16),
              SelectableText(
                formatted,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: formatted));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Skopiowano kod do schowka'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Kopiuj kod'),
              ),
            ],
          ),
        ),
        actions: mustSaveManually
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Zapisałem kod'),
                ),
              ]
            : [
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(firstTime ? 'Rozumiem' : 'Zamknij'),
                ),
              ],
      );
    },
  );
}

/// Wiersz stanu sejfu: czy kod wroci sam po zmianie telefonu.
class _VaultStatus extends StatelessWidget {
  final bool backedUp;

  const _VaultStatus({required this.backedUp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = backedUp ? theme.colorScheme.primary : theme.colorScheme.error;
    final text = backedUp
        ? 'Kod jest zapisany na Twoim koncie Google — po zmianie telefonu '
              'wróci sam.'
        : 'Kod nie jest zapisany na koncie Google. Ustaw blokadę ekranu '
              'telefonu, żeby wracał sam po zmianie urządzenia.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          backedUp ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
