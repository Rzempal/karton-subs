import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_widgets.dart';

/// Ustawienia archiwum rachunkow: trwala kopia zdjecia zatwierdzonego rachunku
/// w publicznym katalogu `Documents/<podfolder>` (ADR-013 pkt 5a).
///
/// Osobny ekran, nie podsekcja Asystenta AI: archiwum dotyczy KAZDEGO
/// zatwierdzonego rachunku ze zdjeciem — takze tych odczytanych szybka sciezka
/// OCR, bez udzialu silnika AI (ADR-017).
class ReceiptArchiveScreen extends StatefulWidget {
  const ReceiptArchiveScreen({super.key});

  /// Podtytul kafla w Ustawieniach.
  static String labelFor(bool enabled, String subfolder) =>
      enabled ? 'Włączone · Documents/$subfolder' : 'Wyłączone';

  @override
  State<ReceiptArchiveScreen> createState() => _ReceiptArchiveScreenState();
}

class _ReceiptArchiveScreenState extends State<ReceiptArchiveScreen> {
  late bool _enabled;
  late String _subfolder;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _enabled = storage.getReceiptArchiveEnabled();
    _subfolder = storage.getReceiptArchiveSubfolder();
  }

  String get _archivePath => '/Pamięć wewnętrzna/Documents/$_subfolder';

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await context.read<StorageService>().setReceiptArchiveEnabled(value);
  }

  Future<void> _editSubfolder() async {
    final controller = TextEditingController(text: _subfolder);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Folder archiwum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Podfolder w katalogu Documents:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'Documents/',
                hintText: 'Zostaje',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final storage = context.read<StorageService>();
      await storage.setReceiptArchiveSubfolder(result);
      setState(() => _subfolder = storage.getReceiptArchiveSubfolder());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Archiwum paragonów')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
        children: [
          SettingsGroup(children: [
            SwitchListTile(
              title: const Text('Zapisuj zdjęcia paragonów'),
              subtitle: const Text(
                'Trwała kopia zdjęcia przy zatwierdzeniu wydatku',
              ),
              value: _enabled,
              onChanged: _setEnabled,
            ),
            if (_enabled)
              ListTile(
                leading: const Icon(LucideIcons.folder),
                title: const Text('Folder archiwum'),
                subtitle: Text(_archivePath),
                trailing: const Icon(LucideIcons.pencil),
                onTap: _editSubfolder,
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Zdjęcia zatwierdzonych paragonów trafiają do wybranego folderu '
              '(przeglądniesz je w Plikach lub Galerii). Archiwum jest lokalne '
              '— nie wchodzi do kopii zapasowej ani synchronizacji domowej.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
