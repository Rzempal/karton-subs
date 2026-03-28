// subscriptions_screen.dart v0.001 Lista subskrypcji z filtrowaniem i sortowaniem

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../controllers/selection_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/subscription_card.dart';
import 'add_subscription_screen.dart';

enum SortOption { name, amount, renewal, dateAdded }

class SubscriptionsScreen extends StatefulWidget {
  final StorageService storageService;
  final SelectionController selectionController;

  const SubscriptionsScreen({
    super.key,
    required this.storageService,
    required this.selectionController,
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String? _filterCategoryId;
  bool _showCancelled = false;
  SortOption _sortOption = SortOption.name;

  @override
  void initState() {
    super.initState();
    widget.selectionController.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = widget.storageService.getCategories();
    final isSelecting = widget.selectionController.isActive;

    var subscriptions = widget.storageService.getSubscriptions();

    // Filter
    if (!_showCancelled) {
      subscriptions = subscriptions.where((s) => s.isActive).toList();
    }
    if (_filterCategoryId != null) {
      subscriptions = subscriptions
          .where((s) => s.categoryId == _filterCategoryId)
          .toList();
    }

    // Sort
    subscriptions = List.from(subscriptions);
    switch (_sortOption) {
      case SortOption.name:
        subscriptions.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortOption.amount:
        subscriptions.sort(
          (a, b) => b.monthlyAmount.compareTo(a.monthlyAmount),
        );
        break;
      case SortOption.renewal:
        subscriptions.sort(
          (a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate),
        );
        break;
      case SortOption.dateAdded:
        subscriptions.sort(
          (a, b) => b.dataDodania.compareTo(a.dataDodania),
        );
        break;
    }

    // Pinned first
    final pinned = subscriptions.where((s) => s.isPinned).toList();
    final unpinned = subscriptions.where((s) => !s.isPinned).toList();
    subscriptions = [...pinned, ...unpinned];

    return Scaffold(
      appBar: AppBar(
        title: isSelecting
            ? Text('Zaznaczono: ${widget.selectionController.selectedCount}')
            : const Text('Subskrypcje'),
        leading: isSelecting
            ? IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: widget.selectionController.exitMode,
              )
            : null,
        actions: [
          if (isSelecting) ...[
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: _deleteSelected,
            ),
          ] else ...[
            // Sort
            PopupMenuButton<SortOption>(
              icon: const Icon(LucideIcons.arrowUpDown),
              onSelected: (v) => setState(() => _sortOption = v),
              itemBuilder: (_) => [
                _sortMenuItem(SortOption.name, 'Nazwa', LucideIcons.type),
                _sortMenuItem(SortOption.amount, 'Kwota', LucideIcons.banknote),
                _sortMenuItem(
                  SortOption.renewal,
                  'Odnowienie',
                  LucideIcons.calendar,
                ),
                _sortMenuItem(
                  SortOption.dateAdded,
                  'Data dodania',
                  LucideIcons.clock,
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppGeometry.spacingBase,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppGeometry.spacingSm),
                  child: FilterChip(
                    label: const Text('Wszystkie'),
                    selected: _filterCategoryId == null,
                    onSelected: (_) =>
                        setState(() => _filterCategoryId = null),
                  ),
                ),
                ...categories.map(
                  (cat) => Padding(
                    padding:
                        const EdgeInsets.only(right: AppGeometry.spacingSm),
                    child: FilterChip(
                      avatar: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: parseHexColor(cat.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(cat.name),
                      selected: _filterCategoryId == cat.id,
                      onSelected: (_) => setState(
                        () => _filterCategoryId =
                            _filterCategoryId == cat.id ? null : cat.id,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppGeometry.spacingSm),
                  child: FilterChip(
                    label: const Text('Anulowane'),
                    selected: _showCancelled,
                    onSelected: (v) => setState(() => _showCancelled = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.spacingSm),

          // List
          Expanded(
            child: subscriptions.isEmpty
                ? Center(
                    child: Text(
                      'Brak subskrypcji w tej kategorii',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppGeometry.spacingBase,
                    ),
                    itemCount: subscriptions.length,
                    itemBuilder: (context, index) {
                      final sub = subscriptions[index];
                      final cat = sub.categoryId != null
                          ? widget.storageService
                              .getCategoryById(sub.categoryId!)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppGeometry.spacingSm,
                        ),
                        child: SubscriptionCard(
                          subscription: sub,
                          category: cat,
                          isSelected:
                              widget.selectionController.isSelected(sub.id),
                          onTap: isSelecting
                              ? () => widget.selectionController.toggle(sub.id)
                              : () => _editSubscription(context, sub),
                          onLongPress: isSelecting
                              ? null
                              : () =>
                                  widget.selectionController.enterMode(sub.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => _addSubscription(context),
              child: const Icon(LucideIcons.plus),
            ),
    );
  }

  PopupMenuItem<SortOption> _sortMenuItem(
    SortOption option,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
          if (_sortOption == option) ...[
            const Spacer(),
            Icon(LucideIcons.check, size: 16, color: AppColors.lightAccent),
          ],
        ],
      ),
    );
  }

  Future<void> _addSubscription(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(
          storageService: widget.storageService,
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _editSubscription(
    BuildContext context,
    Subscription subscription,
  ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(
          storageService: widget.storageService,
          subscription: subscription,
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _deleteSelected() async {
    final ids = widget.selectionController.selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń subskrypcje'),
        content: Text('Czy na pewno chcesz usunąć ${ids.length} subskrypcji?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteSubscriptions(ids);
      widget.selectionController.exitMode();
      setState(() {});
    }
  }
}
