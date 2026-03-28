import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/subscription_controller.dart';
import '../models/category.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../widgets/subscription_card.dart';
import 'add_subscription_screen.dart';

class SubscriptionListScreen extends StatefulWidget {
  const SubscriptionListScreen({super.key});

  @override
  State<SubscriptionListScreen> createState() => _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {
  String? _filterCategoryId;
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SubscriptionController>();
    final storage = context.read<StorageService>();
    final categories = storage.getCategories();

    final subs = ctrl.sorted(
      categoryId: _filterCategoryId,
      activeOnly: !_showInactive,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subskrypcje'),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            tooltip: _showInactive ? 'Ukryj nieaktywne' : 'Pokaż nieaktywne',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (categories.isNotEmpty) _CategoryFilter(
            categories: categories,
            selected: _filterCategoryId,
            onSelect: (id) => setState(() => _filterCategoryId = id),
          ),
          Expanded(
            child: subs.isEmpty
                ? _EmptyState(hasFilter: _filterCategoryId != null)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: subs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _buildCard(context, subs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Subscription sub) {
    return SubscriptionCard(
      subscription: sub,
      onTap: () => _openEdit(context, sub),
      onLongPress: () => _showActions(context, sub),
    );
  }

  void _showActions(BuildContext context, Subscription sub) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(sub.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(sub.isPinned ? 'Odepnij' : 'Przypnij na górze'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<SubscriptionController>().togglePin(sub.id);
              },
            ),
            ListTile(
              leading: Icon(sub.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
              title: Text(sub.isActive ? 'Anuluj subskrypcję' : 'Wznów subskrypcję'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<SubscriptionController>().toggleActive(sub.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Usuń', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, sub);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń subskrypcję'),
        content: Text('Czy na pewno chcesz usunąć "${sub.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SubscriptionController>().delete(sub.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AddSubscriptionScreen(),
    ));
  }

  Future<void> _openEdit(BuildContext context, Subscription sub) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddSubscriptionScreen(existing: sub),
    ));
  }
}

class _CategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final String? selected;
  final void Function(String?) onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('Wszystkie'),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          const SizedBox(width: 8),
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat.name),
                  selected: selected == cat.id,
                  selectedColor: cat.color.withValues(alpha: 0.2),
                  onSelected: (_) => onSelect(selected == cat.id ? null : cat.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'Brak subskrypcji w tej kategorii' : 'Brak subskrypcji',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
