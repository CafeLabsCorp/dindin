import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
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

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Informe um valor válido.');
      return;
    }
    if (_blockedByFrozenDebt(categories, availableBalance)) {
      setState(() => _error = 'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos.');
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
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover esse gasto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteExpense(id);
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
    final expensesAsync = ref.watch(expensesProvider);
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
        Text('Gastos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Registre uma saída direto da conta ou de uma caixinha específica.', style: TextStyle(color: context.tokens.muted)),
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
                        decoration: const InputDecoration(labelText: 'Data'),
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
                      decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
                    ),
                  ),
                  (
                    width: 200.0,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selection,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'De onde sai'),
                      items: [
                        const DropdownMenuItem(value: _accountOption, child: Text('Conta')),
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
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)', hintText: 'Ex: supermercado'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Disponível: ${formatCurrency(availableBalance)}',
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
                    'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos, ou ligue "Permitir saldo negativo" na categoria.',
                    style: TextStyle(fontSize: 12, color: context.tokens.statusCritical, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting || blocked ? null : () => _submit(categories, availableBalance),
                child: const Text('Lançar gasto'),
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
                        decoration: const InputDecoration(labelText: 'De'),
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
                        decoration: const InputDecoration(labelText: 'Até'),
                        child: Text(_filterTo == null ? '—' : formatDate(isoDateFrom(_filterTo!))),
                      ),
                    ),
                  ),
                  if (filterActive)
                    (
                      width: 140.0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _clearFilter, child: const Text('Limpar filtro')),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Gastos lançados', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) return const EmptyState('Nenhum gasto lançado ainda.');
                  final filtered = expenses.where((e) => isDateWithinRange(e.date, _filterFrom, _filterTo)).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      _filteredEmptyMessage(_filterFrom, _filterTo),
                      action: TextButton(onPressed: _clearFilter, child: const Text('Limpar filtro')),
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
                error: (e, _) => Text('Erro: $e'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _filteredEmptyMessage(DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return 'Nenhum gasto entre ${formatDate(isoDateFrom(from))} e ${formatDate(isoDateFrom(to))}.';
  }
  if (from != null) {
    return 'Nenhum gasto a partir de ${formatDate(isoDateFrom(from))}.';
  }
  if (to != null) {
    return 'Nenhum gasto até ${formatDate(isoDateFrom(to))}.';
  }
  return 'Nenhum gasto lançado ainda.';
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
                          text: ' · ${_originLabel(expense.categoryId, categoryName)} · ${expense.date}',
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
              tooltip: 'Remover gasto',
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

String _originLabel(String? categoryId, Map<String, String> categoryName) {
  if (categoryId == null) return 'Conta';
  return categoryName[categoryId] ?? 'categoria removida';
}
