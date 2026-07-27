import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/bill_scan_controller.dart';
import '../services/ai_engine_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_widgets.dart';

/// Ustawienia Asystenta AI: przełącznik WSPOMAGANIA skanu lokalnym silnikiem
/// + link do uruchomienia albo pobrania apki silnika.
///
/// Samo skanowanie rachunków nie ma tu przełącznika — odczyt robi model OCR
/// wbudowany w APK (ADR-017), więc działa zawsze, tak jak każda inna funkcja
/// apki. Wyłączony asystent oznacza tylko tyle, że dokumenty nierozpoznane
/// regułami czekają na ręczne uzupełnienie zamiast iść do silnika.
///
/// Archiwum zdjęć ma własną sekcję w Ustawieniach (`ReceiptArchiveScreen`) —
/// dotyczy każdego zatwierdzonego rachunku, nie tylko odczytanego silnikiem.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _engine = AiEngineService();

  late bool _enabled;
  AiEngineStatus? _engineStatus;

  @override
  void initState() {
    super.initState();
    _enabled = context.read<BillScanController>().aiAssistantEnabled;
    _refreshEngineStatus();
  }

  Future<void> _refreshEngineStatus() async {
    final status = await _engine.status();
    if (mounted) setState(() => _engineStatus = status);
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    // Przez kontroler (nie storage wprost): notyfikacja przebudowuje menu
    // na ekranie Rachunki i podtytul kafla w Ustawieniach.
    await context.read<BillScanController>().setAiAssistantEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installed = _engineStatus?.installed ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Asystent AI')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
        children: [
          // Skan rachunków jest zwykłą funkcją apki i nie ma tu przełącznika —
          // ten ekran dotyczy WYŁĄCZNIE wspomagania silnikiem.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Skanowanie rachunków ze zdjęć działa zawsze — apka odczytuje '
              'paragony i potwierdzenia płatności własnym mechanizmem, bez '
              'sieci i bez dodatkowych aplikacji.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SettingsGroup(children: [
            SwitchListTile(
              title: const Text('Wspomaganie silnikiem AI'),
              subtitle: const Text(
                'Dokumenty, których apka nie odczyta sama (faktury, nietypowe '
                'układy), trafiają do aplikacji „Lokalny Silnik AI”',
              ),
              isThreeLine: true,
              value: _enabled,
              onChanged: _setEnabled,
            ),
          ]),

          // Link zależny od stanu silnika: uruchom (jest) / pobierz (brak).
          if (_engineStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: Icon(
                    installed ? LucideIcons.externalLink : LucideIcons.download,
                    size: 18,
                  ),
                  label: Text(
                    installed
                        ? 'Uruchom aplikację silnika AI'
                        : 'Pobierz aplikację silnika AI (APK)',
                  ),
                  onPressed: () async {
                    if (installed) {
                      await _engine.openEngineApp();
                    } else {
                      await _engine.openDownloadPage();
                    }
                    // Po powrocie odśwież stan (mogła dojść instalacja).
                    _refreshEngineStatus();
                  },
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _enabled
                  ? 'Silnik czyta rachunek ze zdjęcia (kwota, wystawca, termin '
                        'płatności) — w pełni lokalnie, bez chmury. Wymaga '
                        'jednorazowego pobrania modelu (~3,7 GB) w aplikacji '
                        '„Lokalny Silnik AI”. Rozpoznanie trwa ok. minuty.'
                  : 'Bez silnika: paragony i potwierdzenia płatności apka '
                        'odczyta sama w kilka sekund, a dokumenty, których nie '
                        'rozpozna, czekają w „Do zatwierdzenia” do ręcznego '
                        'uzupełnienia.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Stan silnika. „Gotowy" (zielone) dopiero gdy model WCZYTANY do
          // pamięci — sam pobrany wczyta się przy pierwszym skanie (~10 s),
          // więc nie oznaczamy go jako w pełni gotowego.
          if (_engineStatus != null && _enabled) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                !installed
                    ? 'Aplikacja silnika nie jest zainstalowana.'
                    : !_engineStatus!.modelReady
                        ? 'Silnik zainstalowany — pobierz w nim model, by skanować.'
                        : _engineStatus!.modelLoaded
                            ? 'Silnik gotowy do skanowania.'
                            : 'Model pobrany — wczyta się przy pierwszym skanie (~10 s).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (_engineStatus!.modelReady && _engineStatus!.modelLoaded)
                      ? AppColors.positive
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
