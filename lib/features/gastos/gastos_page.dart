import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/installment_purchase.dart';
import '../../models/subscription.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/date_range.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/edit_transaction_sheet.dart';
import '../../widgets/responsive_form_row.dart';

/// Sentinel for the "Conta" dropdown entry — an expense charged directly
/// against the account balance instead of a caixinha.
const _accountOption = '__account__';

class GastosPage extends ConsumerStatefulWidget {
  const GastosPage({super.key});

  @override
  ConsumerState<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends ConsumerState<GastosPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  String _selection = _accountOption;
  String? _error;
  bool _submitting = false;

  DateTime? _filterFrom;
  DateTime? _filterTo;

  final _subNameController = TextEditingController();
  final _subAmountController = TextEditingController();
  int _subDueDay = 5;
  String? _subError;
  bool _subSubmitting = false;

  final _instNameController = TextEditingController();
  final _instTotalController = TextEditingController();
  DateTime _instPurchaseDate = DateTime.now();
  DateTime _instFirstChargeDate = DateTime.now();
  int _instInstallments = 2;
  String? _instError;
  bool _instSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _subNameController.dispose();
    _subAmountController.dispose();
    _instNameController.dispose();
    _instTotalController.dispose();
    super.dispose();
  }

  /// Whether the currently-selected caixinha refuses a new gasto right now:
  /// its balance is already negative and it doesn't (or no longer) allow
  /// that — decision #3, "toggle off + already negative -> block further
  /// gastos". Checked proactively here so the form disables itself with a
  /// clear reason instead of letting the user submit and hit the
  /// `FirestoreService`/`firestore.rules` rejection cold. Always `false` for
  /// the "Conta" option (the account has no such toggle) and while the
  /// summary hasn't loaded yet (nothing to block against).
  bool _blockedByFrozenDebt(List<Category> categories, num? availableBalance) {
    if (_selection == _accountOption || availableBalance == null) return false;
    final category = categories.firstWhereOrNull((c) => c.id == _selection);
    if (category == null) return false;
    return availableBalance < 0 && !category.allowsNegativeBalance;
  }

  Future<void> _submit(List<Category> categories, num? availableBalance) async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    if (_blockedByFrozenDebt(categories, availableBalance)) {
      setState(() => _error = l10n.frozenDebtBlockShort);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.createExpense(
        date: isoDateFrom(_date),
        amount: value,
        categoryId: _selection == _accountOption ? null : _selection,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      );
      _amountController.clear();
      _descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeExpenseConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteExpense(id);
  }

  Future<void> _submitSubscription() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _subNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _subError = l10n.nameRequiredError);
      return;
    }
    final value = double.tryParse(_subAmountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _subError = l10n.invalidAmountError);
      return;
    }
    if (_subDueDay < 1 || _subDueDay > 31) {
      setState(() => _subError = l10n.invalidDueDayError);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _subSubmitting = true;
      _subError = null;
    });
    try {
      await firestore.createSubscription(name: name, amount: value, dueDay: _subDueDay);
      _subNameController.clear();
      _subAmountController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _subError = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _subSubmitting = false);
    }
  }

  Future<void> _deleteSubscription(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeSubscriptionConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteSubscription(id);
  }

  Future<void> _submitInstallmentPurchase() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _instNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _instError = l10n.nameRequiredError);
      return;
    }
    final value = double.tryParse(_instTotalController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _instError = l10n.invalidAmountError);
      return;
    }
    if (_instInstallments < 2 || _instInstallments > 36) {
      setState(() => _instError = l10n.invalidInstallmentsError);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _instSubmitting = true;
      _instError = null;
    });
    try {
      await firestore.createInstallmentPurchase(
        name: name,
        totalAmount: value,
        installments: _instInstallments,
        purchaseDate: isoDateFrom(_instPurchaseDate),
        firstChargeDate: isoDateFrom(_instFirstChargeDate),
      );
      _instNameController.clear();
      _instTotalController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _instError = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _instSubmitting = false);
    }
  }

  Future<void> _deleteInstallmentPurchase(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeInstallmentPurchaseConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteInstallmentPurchase(id);
  }

  void _editExpense(Expense expense, List<Category> categories) {
    showEditTransactionSheet(
      context,
      ref: ref,
      transaction: EditableExpense(expense),
      categories: categories,
    );
  }

  void _clearFilter() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expensesAsync = ref.watch(expensesProvider);
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final installmentPurchasesAsync = ref.watch(installmentPurchasesProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final summary = ref.watch(summaryProvider);

    final categoryName = {for (final c in categories) c.id: c.name};
    final availableBalance = _selection == _accountOption
        ? (summary?.accountBalance ?? 0)
        : (summary?.balancesByCategory[_selection] ?? 0);
    final blocked = _blockedByFrozenDebt(categories, availableBalance);
    final filterActive = _filterFrom != null || _filterTo != null;

    return ListView(
      children: [
        Text(l10n.gastosTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.gastosSubtitle, style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveFormRow(
                fields: [
                  (
                    width: 160.0,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.dateLabel),
                        child: Text(formatDate(isoDateFrom(_date))),
                      ),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _amountController,
                      enabled: !blocked,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
                    ),
                  ),
                  (
                    width: 200.0,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selection,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.expenseSourceLabel),
                      items: [
                        DropdownMenuItem(value: _accountOption, child: Text(l10n.accountLabel)),
                        for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() {
                        _selection = v ?? _accountOption;
                        _error = null;
                      }),
                    ),
                  ),
                  (
                    width: 220.0,
                    child: TextField(
                      controller: _descriptionController,
                      enabled: !blocked,
                      decoration: InputDecoration(labelText: l10n.descriptionOptionalLabel, hintText: l10n.expenseDescriptionHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.availableLabel(formatCurrency(availableBalance)),
                style: TextStyle(
                  fontSize: 12,
                  color: availableBalance < 0 ? context.tokens.statusCritical : context.tokens.subtle,
                  fontWeight: availableBalance < 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.frozenDebtBlockLong,
                    style: TextStyle(fontSize: 12, color: context.tokens.statusCritical, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting || blocked ? null : () => _submit(categories, availableBalance),
                child: Text(l10n.submitExpenseButton),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveFormRow(
                fields: [
                  (
                    width: 160.0,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterFrom ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _filterFrom = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.filterFromLabel),
                        child: Text(_filterFrom == null ? '—' : formatDate(isoDateFrom(_filterFrom!))),
                      ),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterTo ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _filterTo = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.filterToLabel),
                        child: Text(_filterTo == null ? '—' : formatDate(isoDateFrom(_filterTo!))),
                      ),
                    ),
                  ),
                  if (filterActive)
                    (
                      width: 140.0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _clearFilter, child: Text(l10n.clearFilterButton)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.expensesListTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) return EmptyState(l10n.expensesEmptyState);
                  final filtered = expenses.where((e) => isDateWithinRange(e.date, _filterFrom, _filterTo)).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      _filteredEmptyMessage(l10n, _filterFrom, _filterTo),
                      action: TextButton(onPressed: _clearFilter, child: Text(l10n.clearFilterButton)),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++)
                        _ExpenseRow(
                          expense: filtered[i],
                          categoryName: categoryName,
                          onTap: () => _editExpense(filtered[i], categories),
                          onDelete: () => _delete(filtered[i].id),
                          divider: i > 0,
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.genericErrorPrefix(e.toString())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.subscriptionsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(l10n.subscriptionsSubtitle, style: TextStyle(color: context.tokens.muted)),
              const SizedBox(height: 16),
              ResponsiveFormRow(
                fields: [
                  (
                    width: 200.0,
                    child: TextField(
                      controller: _subNameController,
                      enabled: !_subSubmitting,
                      decoration: InputDecoration(
                        labelText: l10n.subscriptionNameLabel,
                        hintText: l10n.subscriptionNameHint,
                      ),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: DropdownButtonFormField<int>(
                      initialValue: _subDueDay,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.subscriptionDueDayLabel),
                      items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                      onChanged: _subSubmitting ? null : (v) => setState(() => _subDueDay = v ?? _subDueDay),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _subAmountController,
                      enabled: !_subSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _subSubmitting ? null : _submitSubscription,
                child: Text(l10n.submitSubscriptionButton),
              ),
              if (_subError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_subError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.subscriptionsListTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              subscriptionsAsync.when(
                data: (subscriptions) {
                  if (subscriptions.isEmpty) return EmptyState(l10n.subscriptionsEmptyState);
                  return Column(
                    children: [
                      for (var i = 0; i < subscriptions.length; i++)
                        _SubscriptionRow(
                          subscription: subscriptions[i],
                          onDelete: () => _deleteSubscription(subscriptions[i].id),
                          divider: i > 0,
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.genericErrorPrefix(e.toString())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.installmentPurchasesTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(l10n.installmentPurchasesSubtitle, style: TextStyle(color: context.tokens.muted)),
              const SizedBox(height: 16),
              ResponsiveFormRow(
                fields: [
                  (
                    width: 200.0,
                    child: TextField(
                      controller: _instNameController,
                      enabled: !_instSubmitting,
                      decoration: InputDecoration(
                        labelText: l10n.installmentNameLabel,
                        hintText: l10n.installmentNameHint,
                      ),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: InkWell(
                      onTap: _instSubmitting
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _instPurchaseDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _instPurchaseDate = picked);
                            },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.purchaseDateLabel),
                        child: Text(formatDate(isoDateFrom(_instPurchaseDate))),
                      ),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _instTotalController,
                      enabled: !_instSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
                    ),
                  ),
                  (
                    width: 120.0,
                    child: DropdownButtonFormField<int>(
                      initialValue: _instInstallments,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.installmentsCountLabel),
                      items: [for (var n = 2; n <= 36; n++) DropdownMenuItem(value: n, child: Text('${n}x'))],
                      onChanged: _instSubmitting
                          ? null
                          : (v) => setState(() => _instInstallments = v ?? _instInstallments),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: InkWell(
                      onTap: _instSubmitting
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _instFirstChargeDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _instFirstChargeDate = picked);
                            },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.firstChargeDateLabel),
                        child: Text(formatDate(isoDateFrom(_instFirstChargeDate))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _instSubmitting ? null : _submitInstallmentPurchase,
                child: Text(l10n.submitInstallmentPurchaseButton),
              ),
              if (_instError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_instError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.installmentPurchasesListTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              installmentPurchasesAsync.when(
                data: (purchases) {
                  if (purchases.isEmpty) return EmptyState(l10n.installmentPurchasesEmptyState);
                  return Column(
                    children: [
                      for (var i = 0; i < purchases.length; i++)
                        _InstallmentPurchaseRow(
                          purchase: purchases[i],
                          onDelete: () => _deleteInstallmentPurchase(purchases[i].id),
                          divider: i > 0,
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.genericErrorPrefix(e.toString())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _filteredEmptyMessage(AppLocalizations l10n, DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return l10n.expensesEmptyFilteredRange(formatDate(isoDateFrom(from)), formatDate(isoDateFrom(to)));
  }
  if (from != null) {
    return l10n.expensesEmptyFilteredFrom(formatDate(isoDateFrom(from)));
  }
  if (to != null) {
    return l10n.expensesEmptyFilteredTo(formatDate(isoDateFrom(to)));
  }
  return l10n.expensesEmptyState;
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final Map<String, String> categoryName;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool divider;

  const _ExpenseRow({
    required this.expense,
    required this.categoryName,
    required this.onTap,
    required this.onDelete,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: context.tokens.border)) : null),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatCurrency(expense.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' · ${_originLabel(l10n, expense.categoryId, categoryName)} · ${expense.date}',
                          style: TextStyle(color: context.tokens.subtle),
                        ),
                      ],
                    ),
                  ),
                  if (expense.description != null)
                    Text(expense.description!, style: TextStyle(fontSize: 12, color: context.tokens.subtle)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.removeExpenseTooltip,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

String _originLabel(AppLocalizations l10n, String? categoryId, Map<String, String> categoryName) {
  if (categoryId == null) return l10n.accountLabel;
  return categoryName[categoryId] ?? l10n.removedCategoryLabel;
}

class _SubscriptionRow extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onDelete;
  final bool divider;

  const _SubscriptionRow({required this.subscription, required this.onDelete, required this.divider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: context.tokens.border)) : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatCurrency(subscription.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' · ${subscription.name}',
                        style: TextStyle(color: context.tokens.subtle),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.subscriptionChargedOnLabel('${subscription.dueDay}'),
                  style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.removeSubscriptionTooltip,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _InstallmentPurchaseRow extends StatelessWidget {
  final InstallmentPurchase purchase;
  final VoidCallback onDelete;
  final bool divider;

  const _InstallmentPurchaseRow({required this.purchase, required this.onDelete, required this.divider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Display-only approximation (Nx de R$Y): the actual last Expense may be
    // a cent higher to absorb rounding, see FirestoreService._installmentAmounts.
    final perInstallment = purchase.totalAmount / purchase.installments;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: context.tokens.border)) : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatCurrency(purchase.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${purchase.name} · ${l10n.installmentSummaryLabel('${purchase.installments}', formatCurrency(perInstallment))}',
                        style: TextStyle(color: context.tokens.subtle),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.installmentProgressLabel('${purchase.chargedInstallments}', '${purchase.installments}'),
                  style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.removeInstallmentPurchaseTooltip,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
