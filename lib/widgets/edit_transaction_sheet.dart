import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/allocation.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_source.dart';
import '../providers/providers.dart';
import '../theme/theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/income_source_labels.dart';
import 'adaptive_form_sheet.dart';
import 'responsive_form_row.dart';

/// The 3 kinds of ledger entry `docs/DESIGN.md` §5.1 wants edit support for.
/// A sealed hierarchy (rather than 3 separate widgets/functions) is what lets
/// [showEditTransactionSheet] be the single shared helper the design doc asks
/// for — "one component to build, not three".
sealed class EditableTransaction {
  const EditableTransaction();
}

class EditableIncome extends EditableTransaction {
  final Income income;
  const EditableIncome(this.income);
}

class EditableExpense extends EditableTransaction {
  final Expense expense;
  const EditableExpense(this.expense);
}

/// Only ever constructed for a plain allocation ([Allocation.isTransfer] ==
/// false) — a transfer leg can't be edited on its own (`updateAllocation`
/// rejects it; see `FirestoreService.updateAllocation`), and there is no
/// individual-allocation list in the UI today to invoke this from anyway
/// (flagged in the final summary — this variant exists to satisfy the
/// "one shared helper for all 3" shape, ready for whenever an allocations
/// list is added).
class EditableAllocation extends EditableTransaction {
  final Allocation allocation;
  EditableAllocation(this.allocation) : assert(!allocation.isTransfer, 'transfer legs cannot be edited individually');
}

/// Shows the edit sheet/dialog for [transaction] — wide `Dialog` or narrow
/// `showModalBottomSheet`, see [showAdaptiveFormSheet]. [categories] is only
/// used to render a human-readable caixinha name for expense/allocation
/// (their target category can't be changed here — see the field-level note
/// in [_EditTransactionForm]); pass `const []` when editing an income.
Future<void> showEditTransactionSheet(
  BuildContext context, {
  required WidgetRef ref,
  required EditableTransaction transaction,
  List<Category> categories = const [],
}) {
  return showAdaptiveFormSheet(
    context,
    contentBuilder: (ctx) => _EditTransactionForm(ref: ref, transaction: transaction, categories: categories),
  );
}

class _EditTransactionForm extends StatefulWidget {
  final WidgetRef ref;
  final EditableTransaction transaction;
  final List<Category> categories;

  const _EditTransactionForm({required this.ref, required this.transaction, required this.categories});

  @override
  State<_EditTransactionForm> createState() => _EditTransactionFormState();
}

class _EditTransactionFormState extends State<_EditTransactionForm> {
  late DateTime _date;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  IncomeSource _source = IncomeSource.estagio;
  String? _error;
  bool _submitting = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    switch (t) {
      case EditableIncome(:final income):
        _date = DateTime.parse(income.date);
        _amountController = TextEditingController(text: formatAmountInput(income.amount));
        _descriptionController = TextEditingController(text: income.description ?? '');
        _source = income.source;
      case EditableExpense(:final expense):
        _date = DateTime.parse(expense.date);
        _amountController = TextEditingController(text: formatAmountInput(expense.amount));
        _descriptionController = TextEditingController(text: expense.description ?? '');
      case EditableAllocation(:final allocation):
        _date = DateTime.parse(allocation.date);
        _amountController = TextEditingController(text: formatAmountInput(allocation.amount.abs()));
        _descriptionController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    final firestore = widget.ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      switch (widget.transaction) {
        case EditableIncome(:final income):
          await firestore.updateIncome(
            income.id,
            date: isoDateFrom(_date),
            amount: value,
            source: _source,
            description: description,
          );
        case EditableExpense(:final expense):
          await firestore.updateExpense(
            expense.id,
            date: isoDateFrom(_date),
            amount: value,
            categoryId: expense.categoryId,
            description: description,
          );
        case EditableAllocation(:final allocation):
          await firestore.updateAllocation(
            allocation.id,
            categoryId: allocation.categoryId,
            amount: value,
            date: isoDateFrom(_date),
          );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final friendly = friendlyErrorMessage(l10n, e);
      setState(() => _error = friendly);
      if (isGoneError(e) && !_closing) {
        _closing = true;
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _title(AppLocalizations l10n, EditableTransaction t) => switch (t) {
    EditableIncome() => l10n.editIncomeTitle,
    EditableExpense() => l10n.editExpenseTitle,
    EditableAllocation() => l10n.editAllocationTitle,
  };

  /// Non-null when [categoryId] is a spend caixinha that's currently in debt
  /// and doesn't allow it — the same "toggle off + already negative" state
  /// `GastosPage` blocks new gastos for (decision #3). Editing here can only
  /// ever REDUCE the amount in that case (which pays the debt down, always
  /// allowed); increasing it hits the same `FirestoreService`/rules check a
  /// new gasto would. `ref.read` (not `.watch`): a one-off snapshot read is
  /// enough for a short-lived edit sheet and avoids reading through the
  /// `WidgetRef` captured from the caller's build outside its own build scope.
  Category? _frozenDebtCategory(String categoryId) {
    final category = widget.categories.firstWhereOrNull((c) => c.id == categoryId);
    if (category == null || category.allowsNegativeBalance) return null;
    final balance = widget.ref.read(summaryProvider)?.balancesByCategory[categoryId] ?? 0;
    return balance < 0 ? category : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = widget.transaction;
    final categoryName = {for (final c in widget.categories) c.id: c.name};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_title(l10n, t), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ResponsiveFormRow(
          fields: [
            (
              width: 160.0,
              child: InkWell(
                onTap: _submitting
                    ? null
                    : () async {
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
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
              ),
            ),
            if (t is EditableIncome)
              (
                width: 160.0,
                child: DropdownButtonFormField<IncomeSource>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.incomeSourceFieldLabel),
                  items: [
                    for (final s in incomeSourceValues)
                      DropdownMenuItem(value: s, child: Text(incomeSourceLabel(l10n, s))),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _source = v ?? _source),
                ),
              ),
            if (t is EditableExpense)
              (
                width: 200.0,
                child: _ReadOnlyField(
                  label: l10n.expenseSourceLabel,
                  value: t.expense.categoryId == null
                      ? l10n.accountLabel
                      : (categoryName[t.expense.categoryId] ?? l10n.removedCategoryLabel),
                ),
              ),
            if (t is EditableAllocation)
              (
                width: 200.0,
                child: _ReadOnlyField(
                  label: l10n.caixinhaLabel,
                  value: categoryName[t.allocation.categoryId] ?? l10n.removedCategoryLabel,
                ),
              ),
            if (t is! EditableAllocation)
              (
                width: 220.0,
                child: TextField(
                  controller: _descriptionController,
                  enabled: !_submitting,
                  decoration: InputDecoration(labelText: l10n.descriptionOptionalLabel),
                ),
              ),
          ],
        ),
        if (t is EditableExpense || t is EditableAllocation)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.cannotChangeCaixinhaNote,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ),
        if (t is EditableExpense && t.expense.categoryId != null && _frozenDebtCategory(t.expense.categoryId!) != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.frozenDebtEditNote,
              style: TextStyle(fontSize: 12, color: context.tokens.statusCritical, fontWeight: FontWeight.w600),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }
}

/// A visually-disabled `InputDecorator` used for fields the backend contract
/// doesn't allow changing on edit (an expense/allocation's target caixinha —
/// `FirestoreService.updateExpense`/`updateAllocation` both reject moving
/// between targets, "delete and recreate" is the supported path). Shown as
/// context, not as an interactive dropdown, so the form doesn't imply an edit
/// that would just fail server-side.
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, filled: true),
      child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
