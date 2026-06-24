// category_management_screen.dart — Zarządzanie kategoriami

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/subscription_card.dart' show categoryIcon, availableIconNames;

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    // Watch controller to rebuild after changes
    context.watch<SubscriptionController>();
    final categories = storage.getCategories();
    final theme = Theme.of(context);

    return AuroraBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Kategorie'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Dodaj kategorię',
            onPressed: () => _showEditor(context, storage, null),
          ),
        ],
      ),
      body: categories.isEmpty
          ? Center(
              child: Text('Brak kategorii',
                  style: theme.textTheme.bodyMedium),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorder(storage, categories, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final subsCount = storage
                    .getSubscriptions()
                    .where((s) => s.categoryId == cat.id)
                    .length;
                return Card(
                  key: ValueKey(cat.id),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        categoryIcon(cat.iconName),
                        color: cat.color,
                        size: 18,
                      ),
                    ),
                    title: Text(cat.name),
                    subtitle: Text(
                      '$subsCount subskrypcji',
                      style: theme.textTheme.labelMedium,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.edit3, size: 18),
                          onPressed: () =>
                              _showEditor(context, storage, cat),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.trash2,
                              size: 18, color: AppColors.negative),
                          onPressed: () =>
                              _confirmDelete(context, storage, cat, subsCount),
                        ),
                        const Icon(LucideIcons.gripVertical, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _reorder(
    StorageService storage,
    List<Category> categories,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final list = List<Category>.from(categories);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      storage.saveCategory(list[i].copyWith(order: i));
    }
    context.read<SubscriptionController>().refresh();
  }

  void _confirmDelete(
    BuildContext context,
    StorageService storage,
    Category cat,
    int subsCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Usuń "${cat.name}"?'),
        content: subsCount > 0
            ? Text(
                '$subsCount subskrypcji zostanie przeniesionych do kategorii "Inne".')
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory(storage, cat);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(StorageService storage, Category cat) async {
    // Przenieś subskrypcje do "Inne"
    final subs = storage
        .getSubscriptions()
        .where((s) => s.categoryId == cat.id)
        .toList();
    final ctrl = context.read<SubscriptionController>();
    for (final sub in subs) {
      await ctrl.update(sub.copyWith(categoryId: 'cat_other'));
    }
    await storage.deleteCategory(cat.id);
    ctrl.refresh();
  }

  void _showEditor(
    BuildContext context,
    StorageService storage,
    Category? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CategoryEditor(
        existing: existing,
        onSave: (cat) async {
          final ctrl = context.read<SubscriptionController>();
          await storage.saveCategory(cat);
          if (mounted) ctrl.refresh();
        },
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  final Category? existing;
  final Future<void> Function(Category) onSave;

  const _CategoryEditor({this.existing, required this.onSave});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late TextEditingController _nameCtrl;
  late String _colorHex;
  late String _iconName;
  late bool _excludeFromGhost;

  static const _palette = [
    '#2563EB', '#7C3AED', '#0891B2', '#EA580C',
    '#16A34A', '#DB2777', '#D97706', '#64748B',
    '#DC2626', '#059669', '#4F46E5', '#0D9488',
    '#CA8A04', '#9333EA', '#E11D48', '#1D4ED8',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _colorHex = widget.existing?.colorHex ?? _palette[0];
    _iconName = widget.existing?.iconName ?? 'folder';
    _excludeFromGhost = widget.existing?.excludeFromGhostAnalysis ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Edytuj kategorię' : 'Nowa kategoria',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nazwa',
              hintText: 'np. AI',
            ),
            autofocus: widget.existing == null,
          ),
          const SizedBox(height: 16),

          // Kolor
          Text('Kolor', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _palette.map((hex) {
              final color = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
              final isSelected = _colorHex == hex;
              return GestureDetector(
                onTap: () => setState(() => _colorHex = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Ikona
          Text('Ikona', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: availableIconNames.length,
              itemBuilder: (context, index) {
                final name = availableIconNames[index];
                final isSelected = _iconName == name;
                final color = Color(int.parse(
                    'FF${_colorHex.replaceFirst('#', '')}', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _iconName = name),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: color, width: 2)
                          : Border.all(color: theme.dividerColor),
                    ),
                    child: Icon(
                      categoryIcon(name),
                      color: isSelected ? color : theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Wykluczenie z analizy ghost
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pomijaj w analizie nieużywanych'),
            subtitle: Text(
              'Subskrypcje w tej kategorii nie będą oznaczane jako nieużywane',
              style: theme.textTheme.bodySmall,
            ),
            value: _excludeFromGhost,
            onChanged: (v) => setState(() => _excludeFromGhost = v),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(
                  widget.existing != null ? 'Zapisz zmiany' : 'Dodaj kategorię'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final cat = widget.existing != null
        ? widget.existing!.copyWith(
            name: name,
            colorHex: _colorHex,
            iconName: _iconName,
            excludeFromGhostAnalysis: _excludeFromGhost,
          )
        : Category(
            id: const Uuid().v4(),
            name: name,
            colorHex: _colorHex,
            iconName: _iconName,
            order: 99,
            excludeFromGhostAnalysis: _excludeFromGhost,
          );

    await widget.onSave(cat);
    if (mounted) Navigator.pop(context);
  }
}
