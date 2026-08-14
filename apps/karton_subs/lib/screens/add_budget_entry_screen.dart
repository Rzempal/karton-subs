import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../controllers/budget_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import '../widgets/category_icons.dart'
    show paymentMethodIcon, paymentMethodIconColor;
import '../widgets/cycle_months_picker.dart';
import '../widgets/form_action_bar.dart';

class AddBudgetEntryScreen extends StatefulWidget {
  final BudgetEntry? existing;

  /// Typ wstępnie wybrany przy dodawaniu (np. z konkretnej sekcji dashboardu).
  final BudgetEntryType? initialType;

  /// Nazwa wstępnie wpisana (np. „Wkład — " przy dodawaniu członka).
  final String? initialName;

  /// Zakres, w którym dodajemy — decyduje o dostępnych typach
  /// (przelew do domowego tylko w osobistym).
  final BudgetScope scope;

  /// Typy do wyboru, zawężone do sekcji, z której otwarto formularz.
  /// Odkąd wpływy mają własny ekran (ADR-019), pokazywanie przy nich „Kosztu
  /// cyklicznego" czy „Raty" tylko zaśmiecało wybór — a zmiana typu i tak
  /// przeniosłaby pozycję na inny ekran, poza zasięg wzroku.
  /// `null` = wszystkie typy (wejście spoza sekcji).
  final List<BudgetEntryType>? allowedTypes;

  const AddBudgetEntryScreen({
    super.key,
    this.existing,
    this.initialType,
    this.initialName,
    this.scope = BudgetScope.personal,
    this.allowedTypes,
  });

  @override
  State<AddBudgetEntryScreen> createState() => _AddBudgetEntryScreenState();
}

class _AddBudgetEntryScreenState extends State<AddBudgetEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _customDaysCtrl;

  late BudgetEntryType _type;
  String? _categoryId;
  String? _paymentMethod;
  late Map<String, MonthAmountOverride> _overrides;
  late final TextEditingController _installmentCountCtrl;
  bool _installmentByCount = true;
  DateTime? _installmentStart;
  DateTime? _installmentLastDate;
  Currency _currency = Currency.PLN;
  BillingCycle _cycle = BillingCycle.monthly;

  /// Miesiące płatności dla cyklu „wybrane miesiące" (ADR-020).
  List<int> _cycleMonths = const [];
  late DateTime _oneTimeDate; // dokładna data wydatku jednorazowego
  DateTime? _anchorDate; // data-kotwica pozycji cyklicznej (opcjonalna)
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;
  bool get _isOneTime => _type == BudgetEntryType.oneTimeIncome;

  /// Kategoria dotyczy wydatków (koszt cykliczny, rata) oraz przelewu do
  /// domowego. Wpływy nie mają kategorii.
  bool get _typeHasCategory =>
      _type == BudgetEntryType.recurringCost ||
      _type == BudgetEntryType.installment ||
      _type == BudgetEntryType.householdTransfer;

  /// Metoda płatności dotyczy wydatków — bez przelewu do domowego (nie ma
  /// sensu jako „metoda płatności" wewnętrznego przesunięcia środków).
  ///
  /// Wpływ jednorazowy jest wyjątkiem: dostaje to pole WYŁĄCZNIE po to, żeby
  /// dało się wskazać kartę kredytową, czyli powiedzieć „te pieniądze są
  /// pożyczone" (ADR-033). Bez zdefiniowanej karty pole się nie pokazuje —
  /// pensja żadnej „metody płatności" nie ma.
  bool get _typeHasPaymentMethod =>
      _type == BudgetEntryType.recurringCost ||
      _type == BudgetEntryType.installment ||
      (_type == BudgetEntryType.oneTimeIncome && _creditCards.isNotEmpty);

  /// Karty kredytowe z gotowymi warunkami — tylko takie mogą być źródłem
  /// pożyczki, bo bez liczby dni nie ma jak wyznaczyć terminu spłaty.
  List<PaymentMethod> get _creditCards => context
      .read<StorageService>()
      .getPaymentMethods()
      .where((pm) => pm.hasCreditTerms)
      .toList();

  /// Wpływ wybiera tylko spośród kart; wydatek — spośród wszystkich metod.
  bool get _paymentMethodIsCreditOnly => _type == BudgetEntryType.oneTimeIncome;

  /// Koszt cykliczny — typ z opcjonalnymi korektami miesięcznymi (ADR-008).
  bool get _isRecurring => _type == BudgetEntryType.recurringCost;

  /// Przelew do domowego — też obsługuje korekty kwoty (analogicznie do kosztu).
  bool get _isTransfer => _type == BudgetEntryType.householdTransfer;

  /// Czy pokazać sekcję korekt miesięcznych.
  bool get _hasOverrides => _isRecurring || _isTransfer;

  /// Rata — typ z datą startu i liczbą rat (koszt miesięczny z końcem).
  bool get _isInstallment => _type == BudgetEntryType.installment;

  /// Typy dostępne w danym zakresie — „przelew do domowego" tylko w osobistym.
  /// Wydatki jednorazowe NIE są tu obecne: to ten sam byt co wydatek, więc
  /// mają jedno miejsce dodawania — ekran „Bieżące" (ADR-018).
  List<BudgetEntryType> get _availableTypes {
    final inScope = [
      BudgetEntryType.income,
      BudgetEntryType.recurringCost,
      BudgetEntryType.installment,
      BudgetEntryType.oneTimeIncome,
      if (widget.scope == BudgetScope.personal)
        BudgetEntryType.householdTransfer,
    ];
    final allowed = widget.allowedTypes;
    if (allowed == null) return inScope;

    final list = inScope.where(allowed.contains).toList();
    // Edytowana pozycja musi zostac na liscie, nawet jesli jej typ nie nalezy
    // do sekcji (stare dane) — inaczej zaden chip nie bylby zaznaczony.
    final current = widget.existing?.type;
    if (current != null && !list.contains(current)) list.insert(0, current);
    return list;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = Subscription.devDateOverride ?? DateTime.now();
    _nameCtrl = TextEditingController(
      text: e?.name ?? widget.initialName ?? '',
    );
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2) : '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _customDaysCtrl = TextEditingController(
      text: e?.customCycleDays != null ? '${e!.customCycleDays}' : '',
    );

    _type = e?.type ?? widget.initialType ?? BudgetEntryType.recurringCost;
    _categoryId = e?.categoryId;
    _paymentMethod = e?.paymentMethod;
    _overrides = {...?e?.monthOverrides};
    _installmentCountCtrl = TextEditingController(
      text: e?.installmentCount != null ? '${e!.installmentCount}' : '',
    );
    if (e != null && e.isInstallment) {
      _installmentStart = e.startDate;
      _installmentLastDate = e.lastInstallmentDate;
    }
    if (e != null) {
      _currency = e.currency;
      _cycle = e.cycle;
      _cycleMonths = e.cycleMonths ?? const [];
    }
    // Data jednorazowego: startDate -> (fallback) 1. dzień z month -> dziś.
    final fallbackMonth = e?.month != null
        ? DateTime.tryParse('${e!.month}-01')
        : null;
    _oneTimeDate =
        e?.startDate ?? fallbackMonth ?? DateTime(now.year, now.month, now.day);
    // Kotwica cykliczna: startDate (gdy edytujemy pozycję cykliczną).
    _anchorDate = (e != null && !e.isOneTime) ? e.startDate : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _customDaysCtrl.dispose();
    _installmentCountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Domyślna waluta z ustawień (tylko przy dodawaniu nowej pozycji).
    if (!_isEditing) {
      final code = context.read<StorageService>().getCurrency();
      _currency = Currency.values.firstWhere(
        (c) => c.name == code || c.label == code,
        orElse: () => Currency.PLN,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Zapis w stałym miejscu — pasek tytułu nie musi go już dublować.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FormActionBar(
        onCancel: _isSubmitting ? null : () => Navigator.of(context).pop(),
        onSave: _isSubmitting ? null : _submit,
      ),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj pozycję' : 'Dodaj pozycję budżetu'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kFormActionBarSpace),
          children: [
            _SectionLabel('Typ pozycji'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTypes.map((t) {
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            if (_typeHint() != null) ...[
              const SizedBox(height: 8),
              Text(
                _typeHint()!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),

            _SectionLabel('Podstawowe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: _nameLabel()),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wymagane' : null,
            ),
            const SizedBox(height: 24),

            _SectionLabel('Kwota'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Kwota *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wymagane';
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Nieprawidłowa kwota';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Currency>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Waluta'),
                    items: Currency.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Data (jednorazowy) LUB cykl + data-kotwica (cykliczne).
            if (_isOneTime) ...[
              _SectionLabel('Data wydatku'),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendar),
                title: Text(_dateLabel(_oneTimeDate)),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickOneTimeDate,
              ),
            ] else if (_isInstallment) ...[
              _SectionLabel('Pierwsza rata'),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendar),
                title: Text(
                  _installmentStart != null
                      ? _dateLabel(_installmentStart!)
                      : 'Wybierz datę pierwszej raty',
                ),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickInstallmentStart,
              ),
              const SizedBox(height: 16),
              _SectionLabel('Koniec rat'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Liczba rat'),
                    selected: _installmentByCount,
                    onSelected: (_) =>
                        setState(() => _installmentByCount = true),
                  ),
                  ChoiceChip(
                    label: const Text('Data ostatniej raty'),
                    selected: !_installmentByCount,
                    onSelected: (_) =>
                        setState(() => _installmentByCount = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_installmentByCount)
                TextFormField(
                  controller: _installmentCountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Liczba rat *',
                    hintText: 'np. 12',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.calendarClock),
                  title: Text(
                    _installmentLastDate != null
                        ? _dateLabel(_installmentLastDate!)
                        : 'Wybierz datę ostatniej raty',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: _pickInstallmentLastDate,
                ),
              if (_installmentSummary() != null) ...[
                const SizedBox(height: 8),
                Text(
                  _installmentSummary()!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else ...[
              _SectionLabel('Cykl rozliczeniowy'),
              const SizedBox(height: 8),
              DropdownButtonFormField<BillingCycle>(
                initialValue: _cycle,
                decoration: const InputDecoration(labelText: 'Cykl'),
                items: BillingCycle.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(_cycleLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cycle = v!),
              ),
              if (_cycle == BillingCycle.monthsOfYear) ...[
                const SizedBox(height: 12),
                CycleMonthsPicker(
                  months: _cycleMonths,
                  anchorMonth: (_anchorDate ?? _oneTimeDate).month,
                  onChanged: (m) => setState(() => _cycleMonths = m),
                ),
              ],
              if (_cycle == BillingCycle.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Co ile dni *',
                    hintText: 'np. 14',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (_cycle != BillingCycle.custom) return null;
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Podaj liczbę dni';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendarClock),
                title: Text(
                  _anchorDate != null
                      ? _dateLabel(_anchorDate!)
                      : 'Data / dzień (opcjonalnie)',
                ),
                subtitle: Text(
                  _anchorDate != null
                      ? 'Wystąpienia liczone od tej daty (kalendarz)'
                      : 'Bez daty pozycja nie pojawi się na kalendarzu',
                ),
                trailing: _anchorDate != null
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        tooltip: 'Usuń datę',
                        onPressed: () => setState(() => _anchorDate = null),
                      )
                    : const Icon(LucideIcons.chevronRight),
                onTap: _pickAnchorDate,
              ),
            ],
            const SizedBox(height: 24),

            if (_hasOverrides) ...[
              _SectionLabel('Korekty miesięczne'),
              const SizedBox(height: 4),
              Text(
                _isTransfer
                    ? 'Przelew zmienny: w wybranym miesiącu możesz ustawić inną datę '
                          'i kwotę. Korekta wpływa też na budżet domowy. '
                          'Nie zmienia „zostaje/mies", tylko bilans miesiąca i kalendarz.'
                    : 'Koszt cykliczny: w wybranym miesiącu możesz ustawić inną datę '
                          'i kwotę (korekta, np. wyższy prąd). Bez korekty liczy się kwota bazowa. '
                          'Korekty nie zmieniają „zostaje/mies", tylko bilans miesiąca i kalendarz.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ..._sortedOverrideKeys().map((mk) {
                final ov = _overrides[mk]!;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(LucideIcons.calendarClock, size: 20),
                  title: Text(_overrideTitle(mk, ov)),
                  subtitle: Text(_overrideSubtitle(ov)),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    tooltip: 'Usuń korektę',
                    onPressed: () => setState(() => _overrides.remove(mk)),
                  ),
                  onTap: () => _editOverride(existingKey: mk),
                );
              }),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _editOverride(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Dodaj korektę miesiąca'),
              ),
              const SizedBox(height: 24),
            ],

            if (_typeHasCategory) ...[
              _SectionLabel('Kategoria'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Brak'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  ...context.read<StorageService>().getCategories().map(
                    (cat) => FilterChip(
                      label: Text(cat.name),
                      selected: _categoryId == cat.id,
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _categoryId = cat.id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (_typeHasPaymentMethod) ...[
              _SectionLabel(
                _paymentMethodIsCreditOnly
                    ? 'Pożyczone z karty'
                    : 'Metoda płatności',
              ),
              if (_paymentMethodIsCreditOnly) ...[
                const SizedBox(height: 4),
                Text(
                  'Wskaż kartę, jeśli to pieniądze pożyczone — spłata powstanie '
                  'sama po okresie bezodsetkowym.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Brak'),
                    selected: _paymentMethod == null,
                    onSelected: (_) => setState(() => _paymentMethod = null),
                  ),
                  ...(_paymentMethodIsCreditOnly
                          ? _creditCards
                          : context.read<StorageService>().getPaymentMethods())
                      .map(
                        (pm) => FilterChip(
                          avatar: Icon(
                            paymentMethodIcon(pm),
                            size: 16,
                            // Zaznaczony chip ma ciemne tlo akcentu — ikona musi
                            // byc kontrastowa (onAccent), tak jak tekst.
                            color: _paymentMethod == pm.name
                                ? AppColors.onAccent
                                : paymentMethodIconColor(
                                    pm,
                                    context.semanticColors,
                                  ),
                          ),
                          label: Text(pm.name),
                          selected: _paymentMethod == pm.name,
                          onSelected: (_) =>
                              setState(() => _paymentMethod = pm.name),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Metoda automatyczna: wydatek na żółto na kalendarzu. '
                'Manualna (lub brak): czerwony i trafia na listę „Płatności".',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ],

            _SectionLabel('Notatka'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Notatka (opcjonalnie)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(
                  widget.existing!.isActive
                      ? LucideIcons.pauseCircle
                      : LucideIcons.playCircle,
                ),
                label: Text(
                  widget.existing!.isActive
                      ? 'Wstrzymaj pozycję'
                      : 'Wznów pozycję',
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: Icon(LucideIcons.trash2, color: AppColors.negative),
                label: Text(
                  'Usuń pozycję',
                  style: TextStyle(color: AppColors.negative),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.negative),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOneTimeDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Wybierz datę wydatku',
    );
    if (picked != null) {
      setState(
        () => _oneTimeDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickAnchorDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Data / pierwsze wystąpienie',
    );
    if (picked != null) {
      setState(
        () => _anchorDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickInstallmentStart() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _installmentStart ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Data pierwszej raty',
    );
    if (picked != null) {
      setState(
        () =>
            _installmentStart = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickInstallmentLastDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final base =
        _installmentLastDate ??
        _installmentStart ??
        DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 15, 12, 31),
      helpText: 'Data ostatniej raty',
    );
    if (picked != null) {
      setState(
        () => _installmentLastDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        ),
      );
    }
  }

  /// Liczba rat z bieżących pól (start + tryb). `null` gdy dane niekompletne.
  int? _installmentCountValue() {
    final start = _installmentStart;
    if (start == null) return null;
    if (_installmentByCount) {
      final n = int.tryParse(_installmentCountCtrl.text.trim());
      return (n != null && n > 0) ? n : null;
    }
    final last = _installmentLastDate;
    if (last == null || last.isBefore(start)) return null;
    return (last.year - start.year) * 12 + (last.month - start.month) + 1;
  }

  /// Podsumowanie raty do podpowiedzi (liczba rat + miesiąc ostatniej).
  String? _installmentSummary() {
    final start = _installmentStart;
    final n = _installmentCountValue();
    if (start == null || n == null) return null;
    final last = DateTime(start.year, start.month + n - 1, start.day);
    return '$n rat · ostatnia: ${DateFormat('LLLL yyyy', 'pl').format(last)}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń pozycję'),
        content: Text(
          'Czy na pewno chcesz trwale usunąć "${widget.existing!.name}"?\n\n'
          'Ta operacja jest nieodwracalna.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              await context.read<BudgetController>().delete(
                widget.existing!.id,
              );
              if (mounted) nav.pop(true);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive() async {
    await context.read<BudgetController>().toggleActive(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final ctrl = context.read<BudgetController>();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final customDays = _cycle == BillingCycle.custom && !_isOneTime
        ? int.tryParse(_customDaysCtrl.text.trim())
        : null;
    final monthKey = _isOneTime ? BudgetEntry.monthKeyOf(_oneTimeDate) : null;
    // Kotwica daty: jednorazowy = dokładna data; cykliczny = opcjonalna kotwica.
    final startDate = _isOneTime ? _oneTimeDate : _anchorDate;
    // Kategoria/metoda tylko dla wydatków — przy wpływie/przelewie czyścimy.
    final categoryId = _typeHasCategory ? _categoryId : null;
    final paymentMethod = _typeHasPaymentMethod ? _paymentMethod : null;
    // Korekty miesięczne dla wydatku i przelewu do domowego.
    final overrides = _hasOverrides && _overrides.isNotEmpty
        ? Map<String, MonthAmountOverride>.from(_overrides)
        : null;

    // Rata: cykl miesięczny, data pierwszej raty + liczba rat.
    var effCycle = _cycle;
    var effCustomDays = customDays;
    var effStartDate = startDate;
    int? installmentCount;
    if (_isInstallment) {
      final start = _installmentStart;
      final count = _installmentCountValue();
      if (start == null) {
        _snack('Podaj datę pierwszej raty');
        setState(() => _isSubmitting = false);
        return;
      }
      if (count == null) {
        _snack(
          _installmentByCount
              ? 'Podaj liczbę rat'
              : 'Data ostatniej raty musi być po pierwszej',
        );
        setState(() => _isSubmitting = false);
        return;
      }
      effCycle = BillingCycle.monthly;
      effCustomDays = null;
      effStartDate = start;
      installmentCount = count;
    }
    // Miesiące płatności tylko dla swojego cyklu; pusty wybór = wszystkie
    // (zachowuje się jak miesięczny, zamiast gubić pozycję w kalendarzu).
    final effCycleMonths = effCycle == BillingCycle.monthsOfYear && !_isOneTime
        ? (_cycleMonths.isEmpty
              ? CycleMonthsPicker.everyN(
                  2,
                  (effStartDate ?? _oneTimeDate).month,
                )
              : _cycleMonths)
        : null;

    try {
      if (_isEditing) {
        await ctrl.update(
          widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            type: _type,
            amount: amount,
            currency: _currency,
            cycle: effCycle,
            customCycleDays: effCustomDays,
            clearCustomCycleDays: effCustomDays == null,
            cycleMonths: effCycleMonths,
            clearCycleMonths: effCycleMonths == null,
            month: monthKey,
            clearMonth: monthKey == null,
            startDate: effStartDate,
            clearStartDate: effStartDate == null,
            categoryId: categoryId,
            clearCategoryId: categoryId == null,
            paymentMethod: paymentMethod,
            clearPaymentMethod: paymentMethod == null,
            monthOverrides: overrides,
            clearMonthOverrides: overrides == null,
            installmentCount: installmentCount,
            clearInstallmentCount: installmentCount == null,
            note: note,
            clearNote: note == null,
          ),
        );
      } else {
        final created = await ctrl.create(
          name: _nameCtrl.text.trim(),
          type: _type,
          amount: amount,
          currency: _currency,
          cycle: effCycle,
          customCycleDays: effCustomDays,
          cycleMonths: effCycleMonths,
          month: monthKey,
          categoryId: categoryId,
          paymentMethod: paymentMethod,
          monthOverrides: overrides,
          installmentCount: installmentCount,
          startDate: effStartDate,
          note: note,
        );
        // Automat karty (ADR-033) dokłada pozycje — mówimy o tym wprost,
        // inaczej wyglądałoby to na błąd apki.
        final creditNote = ctrl.creditSummaryFor(created);
        if (mounted && creditNote != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(creditNote),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _nameLabel() => switch (_type) {
    BudgetEntryType.income => 'Nazwa wpływu *',
    BudgetEntryType.spending => 'Nazwa wydatku *',
    BudgetEntryType.recurringCost => 'Nazwa kosztu *',
    BudgetEntryType.oneTimeIncome => 'Nazwa wpływu *',
    BudgetEntryType.householdTransfer => 'Nazwa przelewu *',
    BudgetEntryType.installment => 'Nazwa raty *',
  };

  /// Krótkie wyjaśnienie różnicy między wydatkiem (zmienny) a kosztem cyklicznym (stały).
  String? _typeHint() => switch (_type) {
    BudgetEntryType.recurringCost =>
      'Koszt cykliczny: stała kwota w interwale (np. czynsz, prąd, ubezpieczenie). '
          'Opcjonalnie w wybranym miesiącu możesz nadpisać kwotę/datę (korekta).',
    BudgetEntryType.installment =>
      'Rata: kwota miesięczna z określonym końcem (start + liczba rat lub data '
          'ostatniej raty). Liczy się do „zostaje/mies" tylko w trakcie spłaty.',
    _ => null,
  };

  String _typeLabel(BudgetEntryType t) => switch (t) {
    BudgetEntryType.income => 'Wpływ',
    BudgetEntryType.spending => 'Wydatek',
    BudgetEntryType.recurringCost => 'Koszt cykliczny',
    BudgetEntryType.oneTimeIncome => 'Wpływ jednorazowy',
    BudgetEntryType.householdTransfer => 'Przelew do domowego',
    BudgetEntryType.installment => 'Rata',
  };

  String _cycleLabel(BillingCycle cycle) => switch (cycle) {
    BillingCycle.weekly => 'Tygodniowo',
    BillingCycle.monthly => 'Miesięcznie',
    BillingCycle.quarterly => 'Kwartalnie',
    BillingCycle.yearly => 'Rocznie',
    BillingCycle.monthsOfYear => 'Wybrane miesiące',
    BillingCycle.custom => 'Własny cykl',
  };

  String _dateLabel(DateTime d) => DateFormat('d MMMM yyyy', 'pl').format(d);

  // ── Korekty miesięczne wydatku (ADR-008) ────────────────────────────────────

  List<String> _sortedOverrideKeys() => _overrides.keys.toList()..sort();

  String _overrideTitle(String monthKey, MonthAmountOverride ov) {
    final base = DateTime.tryParse('$monthKey-01');
    final label = base != null
        ? DateFormat('LLLL yyyy', 'pl').format(base)
        : monthKey;
    return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
  }

  String _overrideSubtitle(MonthAmountOverride ov) {
    final parts = <String>[];
    if (ov.date != null) {
      parts.add('dzień ${DateFormat('d MMM', 'pl').format(ov.date!)}');
    }
    if (ov.amount != null) {
      parts.add(
        '${ov.amount!.toStringAsFixed(2)}${curLabelSuffix(_currency.label)}',
      );
    }
    return parts.isEmpty ? 'bez zmian' : parts.join(' · ');
  }

  Future<void> _editOverride({String? existingKey}) async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final existing = existingKey != null ? _overrides[existingKey] : null;
    var date =
        existing?.date ??
        (existingKey != null
            ? (DateTime.tryParse('$existingKey-01') ?? now)
            : DateTime(now.year, now.month, now.day));
    final amountCtrl = TextEditingController(
      text: existing?.amount != null
          ? existing!.amount!.toStringAsFixed(2)
          : '',
    );

    final result = await showDialog<MonthAmountOverride>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existingKey == null ? 'Dodaj korektę' : 'Edytuj korektę'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendar),
                title: Text(_dateLabel(date)),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(now.year - 2, 1, 1),
                    lastDate: DateTime(now.year + 5, 12, 31),
                    helpText: 'Data wystąpienia w danym miesiącu',
                  );
                  if (picked != null) {
                    setLocal(
                      () => date = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      ),
                    );
                  }
                },
              ),
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Kwota — opcjonalnie${_currency == appDefaultCurrency ? '' : ' (${_currency.label})'}',
                  hintText: 'puste = kwota bazowa',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final txt = amountCtrl.text.trim();
                double? amt;
                if (txt.isNotEmpty) {
                  amt = double.tryParse(txt.replaceAll(',', '.'));
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Nieprawidłowa kwota')),
                    );
                    return;
                  }
                }
                Navigator.pop(
                  ctx,
                  MonthAmountOverride(amount: amt, date: date),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );

    amountCtrl.dispose();
    if (result != null) {
      final newKey = BudgetEntry.monthKeyOf(result.date!);
      setState(() {
        if (existingKey != null && existingKey != newKey) {
          _overrides.remove(existingKey);
        }
        _overrides[newKey] = result;
      });
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
