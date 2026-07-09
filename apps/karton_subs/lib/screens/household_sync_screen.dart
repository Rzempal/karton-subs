import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
// Ikona cloudSync — tylko w nowszym pakiecie (alias, bo oba definiują LucideIcons).
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../controllers/budget_controller.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/frost_card.dart';
import '../widgets/sync_now_button.dart';

/// Ekran synchronizacji budżetu domowego (ADR-009): parowanie QR + hasło,
/// ręczny sync, rozłączenie. Synchronizuje wyłącznie budżet domowy.
class HouseholdSyncScreen extends StatelessWidget {
  const HouseholdSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Synchronizacja domowego')),
      body: Consumer<SyncService>(
        builder: (context, sync, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              _previewDisclaimer(context),
              const SizedBox(height: 12),
              _intro(context),
              const SizedBox(height: 12),
              if (sync.isPaired)
                _PairedView(sync: sync)
              else
                _UnpairedView(sync: sync),
            ],
          );
        },
      ),
    );
  }

  Widget _previewDisclaimer(BuildContext context) {
    final c = context.semanticColors.warning;
    return FrostCard(
      color: c.withValues(alpha: 0.12),
      borderColor: c.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Funkcja w wersji preview',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c)),
                const SizedBox(height: 4),
                const Text(
                  'Synchronizacja jest jeszcze testowana i może działać '
                  'nieprawidłowo. Zachowaj kopię zapasową (backup .zostaje) '
                  'i traktuj wyniki ostrożnie.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final muted = context.semanticColors.textMuted;
    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.users, size: 18, color: context.semanticColors.textMuted),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Wspólny budżet domowy',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Budżet domowy współdzielony między telefonami. Dane są szyfrowane '
            'hasłem na Twoim telefonie — serwer nie widzi kwot ani nazw. '
            'Budżety osobiste zostają tylko na tym urządzeniu.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Widok niesparowany: Dodaj członka / Dołącz ───────────────────────────────

class _UnpairedView extends StatelessWidget {
  final SyncService sync;
  const _UnpairedView({required this.sync});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FrostCard(
          onTap: () => _create(context),
          child: const _ActionRow(
            icon: LucideIcons.userPlus,
            title: 'Dodaj członka',
            subtitle: 'Ustaw hasło i pokaż kod QR drugiej osobie',
          ),
        ),
        const SizedBox(height: 8),
        FrostCard(
          onTap: () => _join(context),
          child: const _ActionRow(
            icon: LucideIcons.qrCode,
            title: 'Dołącz do gospodarstwa',
            subtitle: 'Zeskanuj kod QR i podaj hasło',
          ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final password = await _askPassword(context, confirm: true);
    if (password == null || !context.mounted) return;

    final created = sync.newHousehold(password);
    await sync.setPairing(created.pairing);
    // Pierwszy push w tle — wystawia obecny budżet domowy do skrzynki.
    sync.syncNow();
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ShowQrScreen(payload: created.qrPayload),
    ));
  }

  Future<void> _join(BuildContext context) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScanQrScreen()),
    );
    if (payload == null || !context.mounted) return;

    final password = await _askPassword(context, confirm: false);
    if (password == null || !context.mounted) return;

    try {
      final pairing = sync.pairingFromQr(payload, password);
      await sync.setPairing(pairing);
      final result = await sync.syncNow();
      if (!context.mounted) return;
      if (result.changedLocal) {
        context.read<BudgetController>().refresh();
      }
      showSyncResultSnack(context, result, joined: true);
    } on FormatException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, isError: true);
    }
  }
}

// ── Widok sparowany: status + Synchronizuj / Rozłącz ──────────────────────────

class _PairedView extends StatelessWidget {
  final SyncService sync;
  const _PairedView({required this.sync});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      children: [
        FrostCard(
          color: c.positiveBg,
          borderColor: c.positive.withValues(alpha: 0.3),
          child: Row(children: [
            Icon(LucideIcons.checkCircle, color: c.positive),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Połączono',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        FrostCard(
          onTap: sync.isSyncing ? null : () => _syncNow(context),
          child: _ActionRow(
            icon: lucide.LucideIcons.cloudSync,
            title: 'Synchronizuj teraz',
            subtitle: 'Pobierz i wyślij zmiany budżetu domowego',
            trailing: sync.isSyncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
        ),
        const SizedBox(height: 8),
        FrostCard(
          onTap: () => _unpair(context),
          child: _ActionRow(
            icon: LucideIcons.unlink,
            title: 'Rozłącz',
            subtitle: 'Przestań synchronizować (dane domowe zostają)',
            color: c.negative,
          ),
        ),
      ],
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    final result = await sync.syncNow();
    if (!context.mounted) return;
    if (result.changedLocal) {
      context.read<BudgetController>().refresh();
    }
    showSyncResultSnack(context, result);
  }

  Future<void> _unpair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rozłączyć?'),
        content: const Text(
            'To urządzenie przestanie synchronizować budżet domowy. '
            'Dotychczasowe dane domowe zostaną na telefonie.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rozłącz')),
        ],
      ),
    );
    if (ok == true) await sync.unpair();
  }
}

// ── Ekran QR (telefon A pokazuje) ─────────────────────────────────────────────

class _ShowQrScreen extends StatelessWidget {
  final String payload;
  const _ShowQrScreen({required this.payload});

  @override
  Widget build(BuildContext context) {
    final muted = context.semanticColors.textMuted;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Kod QR gospodarstwa')),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: QrImageView(
                data: payload,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '1. Na drugim telefonie wybierz „Dołącz do gospodarstwa".\n'
              '2. Zeskanuj ten kod.\n'
              '3. Podaj tej osobie hasło — ustnie, nie zapisuj go nigdzie.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Gotowe'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ekran skanera (telefon B) ─────────────────────────────────────────────────

class _ScanQrScreen extends StatefulWidget {
  const _ScanQrScreen();

  @override
  State<_ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<_ScanQrScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zeskanuj kod QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.isNotEmpty
              ? capture.barcodes.first.rawValue
              : null;
          if (code == null || code.isEmpty) return;
          _handled = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}

// ── Wspólne pomocnicze ────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final Widget? trailing;
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.semanticColors.textMuted;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12.5, color: muted)),
            ],
          ),
        ),
        trailing ?? Icon(LucideIcons.chevronRight, color: muted, size: 18),
      ],
    );
  }
}

Future<String?> _askPassword(BuildContext context, {required bool confirm}) {
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(confirm ? 'Ustaw hasło szyfrowania' : 'Hasło gospodarstwa'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: pass,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Hasło'),
              validator: (v) =>
                  (v == null || v.length < 4) ? 'Min. 4 znaki' : null,
            ),
            if (confirm)
              TextFormField(
                controller: pass2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Powtórz hasło'),
                validator: (v) => v != pass.text ? 'Hasła różne' : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, pass.text);
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

