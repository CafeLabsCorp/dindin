import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/income.dart';
import '../../models/income_source.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/date_range.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../utils/income_source_labels.dart';
import '../../widgets/app_card.dart';
import '../../widgets/edit_transaction_sheet.dart';
import '../../widgets/responsive_form_row.dart';

class ReceitasPage extends ConsumerStatefulWidget {
  const ReceitasPage({super.key});

  @override
  ConsumerState<ReceitasPage> createState() => _ReceitasPageState();
}

class _ReceitasPageState extends ConsumerState<ReceitasPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  IncomeSource _source = IncomeSource.estagio;
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.createIncome(
        date: isoDateFrom(_date),
        amount: value,
        source: _source,
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
        title: Text(l10n.removeIncomeConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteIncome(id);
  }

  void _editIncome(Income income) {
    showEditTransactionSheet(context, ref: ref, transaction: EditableIncome(income));
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
    final incomesAsync = ref.watch(incomesProvider);
    final filterActive = _filterFrom != null || _filterTo != null;

    return ListView(
      children: [
        Text(l10n.receitasTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          l10n.receitasSubtitle,
          style: TextStyle(color: context.tokens.muted),
        ),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
                    ),
                  ),
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
                      onChanged: (v) => setState(() => _source = v ?? IncomeSource.estagio),
                    ),
                  ),
                  (
                    width: 220.0,
                    child: TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: l10n.descriptionOptionalLabel, hintText: l10n.incomeDescriptionHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submitting ? null : _submit, child: Text(l10n.submitIncomeButton)),
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
              Text(l10n.incomesListTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              incomesAsync.when(
                data: (incomes) {
                  if (incomes.isEmpty) return EmptyState(l10n.incomesEmptyState);
                  final filtered = incomes.where((i) => isDateWithinRange(i.date, _filterFrom, _filterTo)).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      _filteredEmptyMessage(l10n, _filterFrom, _filterTo),
                      action: TextButton(onPressed: _clearFilter, child: Text(l10n.clearFilterButton)),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++)
                        _IncomeRow(
                          income: filtered[i],
                          onTap: () => _editIncome(filtered[i]),
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
      ],
    );
  }
}

String _filteredEmptyMessage(AppLocalizations l10n, DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return l10n.incomesEmptyFilteredRange(formatDate(isoDateFrom(from)), formatDate(isoDateFrom(to)));
  }
  if (from != null) {
    return l10n.incomesEmptyFilteredFrom(formatDate(isoDateFrom(from)));
  }
  if (to != null) {
    return l10n.incomesEmptyFilteredTo(formatDate(isoDateFrom(to)));
  }
  return l10n.incomesEmptyState;
}

class _IncomeRow extends StatelessWidget {
  final Income income;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool divider;

  const _IncomeRow({required this.income, required this.onTap, required this.onDelete, required this.divider});

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
                          text: formatCurrency(income.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' · ${incomeSourceLabel(l10n, income.source)} · ${income.date}',
                          style: TextStyle(color: context.tokens.subtle),
                        ),
                      ],
                    ),
                  ),
                  if (income.description != null)
                    Text(income.description!, style: TextStyle(fontSize: 12, color: context.tokens.subtle)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.removeIncomeTooltip,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}
