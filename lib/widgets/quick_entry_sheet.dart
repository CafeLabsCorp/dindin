import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/income_source.dart';
import '../providers/providers.dart';
import '../theme/theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/income_source_labels.dart';
import '../utils/money_input_formatter.dart';
import 'adaptive_form_sheet.dart';
import 'responsive_form_row.dart';
import 'saved_feedback.dart';

/// "Lançar receita" / "Lançar gasto" from the Dashboard: the same form as the
/// Receitas and Gastos pages, in a sheet (dialog on wide screens) with the
/// cursor already in the amount, so a new entry doesn't mean leaving the
/// Dashboard. Closes itself once the entry is saved.
Future<void> showQuickEntrySheet(BuildContext context, {required bool income}) {
  return showAdaptiveFormSheet<void>(
    context,
    contentBuilder: (_) => _QuickEntryForm(income: income),
  );
}

class _QuickEntryForm extends ConsumerStatefulWidget {
  final bool income;
  const _QuickEntryForm({required this.income});

  @override
  ConsumerState<_QuickEntryForm> createState() => _QuickEntryFormState();
}

class _QuickEntryFormState extends ConsumerState<_QuickEntryForm> {
  static const _accountOption = '__account__';

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  IncomeSource _source = IncomeSource.estagio;
  String _selection = _accountOption;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool blocked}) async {
    final l10n = AppLocalizations.of(context)!;
    final value = parseAmountInput(_amountController.text);
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    if (blocked) {
      setState(() => _error = l10n.frozenDebtBlockShort);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    // Same rule as the Gastos page: whether this is the account's first
    // expense ever, read before the write (see its `_submit`).
    final wasFirstExpense = !widget.income && (ref.read(expensesProvider).value?.isEmpty ?? false);
    try {
      if (widget.income) {
        await firestore.createIncome(date: isoDateFrom(_date), amount: value, source: _source, description: description);
      } else {
        await firestore.createExpense(
          date: isoDateFrom(_date),
          amount: value,
          categoryId: _selection == _accountOption ? null : _selection,
          description: description,
        );
        if (wasFirstExpense) ref.read(analyticsServiceProvider).logFirstExpenseLogged();
      }
      if (!mounted) return;
      showSavedSnackBar(context, widget.income ? l10n.savedIncome : l10n.savedExpense);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = widget.income ? const [] : (ref.watch(categoriesProvider).value ?? const []);
    final summary = widget.income ? null : ref.watch(summaryProvider);
    final available = _selection == _accountOption
        ? (summary?.accountBalance ?? 0)
        : (summary?.balancesByCategory[_selection] ?? 0);
    final category = categories.firstWhereOrNull((c) => c.id == _selection);
    // A caixinha already in debt that doesn't allow it refuses new gastos.
    final blocked = !widget.income && category != null && available < 0 && !category.allowsNegativeBalance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.income ? l10n.dashboardQuickIncome : l10n.dashboardQuickExpense,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                autofocus: true,
                enabled: !_submitting && !blocked,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
              ),
            ),
            if (widget.income)
              (
                width: 160.0,
                child: DropdownButtonFormField<IncomeSource>(
                  initialValue: _source,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.incomeSourceFieldLabel),
                  items: [
                    for (final s in incomeSourceValues) DropdownMenuItem(value: s, child: Text(incomeSourceLabel(l10n, s))),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _source = v ?? IncomeSource.estagio),
                ),
              )
            else
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
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() {
                          _selection = v ?? _accountOption;
                          _error = null;
                        }),
                ),
              ),
            (
              width: 220.0,
              child: TextField(
                controller: _descriptionController,
                enabled: !_submitting && !blocked,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptionalLabel,
                  hintText: widget.income ? l10n.incomeDescriptionHint : l10n.expenseDescriptionHint,
                ),
              ),
            ),
          ],
        ),
        if (!widget.income) ...[
          const SizedBox(height: 4),
          Text(
            l10n.availableLabel(formatCurrency(available)),
            style: TextStyle(
              fontSize: 12,
              color: available < 0 ? context.tokens.statusCritical : context.tokens.subtle,
              fontWeight: available < 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
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
          onPressed: _submitting || blocked ? null : () => _submit(blocked: blocked),
          child: Text(widget.income ? l10n.submitIncomeButton : l10n.submitExpenseButton),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}
