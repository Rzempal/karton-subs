import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final storage = context.read<StorageService>();
    final currency = storage.getCurrency();

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          const _SectionDivider('Wygląd'),
          ListTile(
            leading: Icon(theme.isDarkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined),
            title: const Text('Motyw'),
            subtitle: Text(_themeName(theme.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, theme),
          ),
          const Divider(indent: 16, endIndent: 16),
          const _SectionDivider('Waluta domyślna'),
          RadioGroup<String>(
            groupValue: currency,
            onChanged: (v) {
              if (v != null) storage.setCurrency(v);
            },
            child: Column(
              children: Currency.values
                  .map((c) => RadioListTile<String>(
                        value: c.label,
                        title: Text('${c.label} (${c.symbol})'),
                      ))
                  .toList(),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          const _SectionDivider('Informacje'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Wersja'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const ListTile(
              title: Text('Wybierz motyw',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            RadioGroup<ThemeMode>(
              groupValue: provider.themeMode,
              onChanged: (v) {
                if (v != null) {
                  provider.setThemeMode(v);
                  Navigator.pop(ctx);
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: const Text('Systemowy'),
                    secondary: const Icon(Icons.brightness_auto_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: const Text('Jasny'),
                    secondary: const Icon(Icons.light_mode_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: const Text('Ciemny'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _themeName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Systemowy',
      ThemeMode.light => 'Jasny',
      ThemeMode.dark => 'Ciemny',
    };
  }
}

class _SectionDivider extends StatelessWidget {
  final String text;
  const _SectionDivider(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
