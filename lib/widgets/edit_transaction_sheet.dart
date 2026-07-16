import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/allocation.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_source.dart';
import '../providers/providers.dart';
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
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Informe um valor válido.');
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
      final friendly = friendlyErrorMessage(e);
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

  String _title(EditableTransaction t) => switch (t) {
    EditableIncome() => 'Editar receita',
    EditableExpense() => 'Editar gasto',
    EditableAllocation() => 'Editar alocação',
  };

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final categoryName = {for (final c in widget.categories) c.id: c.name};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_title(t), style: Theme.of(context).textTheme.titleMedium),
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
                  decoration: const InputDecoration(labelText: 'Data'),
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
                decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
              ),
            ),
            if (t is EditableIncome)
              (
                width: 160.0,
                child: DropdownButtonFormField<IncomeSource>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Origem'),
                  items: [
                    for (final s in incomeSourceOptions) DropdownMenuItem(value: s.value, child: Text(s.label)),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _source = v ?? _source),
                ),
              ),
            if (t is EditableExpense)
              (
                width: 200.0,
                child: _ReadOnlyField(
                  label: 'De onde sai',
                  value: t.expense.categoryId == null
                      ? 'Conta'
                      : (categoryName[t.expense.categoryId] ?? 'categoria removida'),
                ),
              ),
            if (t is EditableAllocation)
              (
                width: 200.0,
                child: _ReadOnlyField(
                  label: 'Caixinha',
                  value: categoryName[t.allocation.categoryId] ?? 'categoria removida',
                ),
              ),
            if (t is! EditableAllocation)
              (
                width: 220.0,
                child: TextField(
                  controller: _descriptionController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                ),
              ),
          ],
        ),
        if (t is EditableExpense || t is EditableAllocation)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Não é possível mudar a caixinha por aqui — remova e lance de novo.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
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
            TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
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
                  : const Text('Salvar'),
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
