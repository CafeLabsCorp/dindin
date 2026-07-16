import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Informe um valor válido.');
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
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover receita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
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
    final incomesAsync = ref.watch(incomesProvider);
    final filterActive = _filterFrom != null || _filterTo != null;

    return ListView(
      children: [
        Text('Receitas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Lance o quanto entrou e de onde veio. O valor cai direto na sua conta —\n'
          'aloque em caixinhas quando quiser, no Dashboard.',
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
                        decoration: const InputDecoration(labelText: 'Data'),
                        child: Text(formatDate(isoDateFrom(_date))),
                      ),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: DropdownButtonFormField<IncomeSource>(
                      initialValue: _source,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Origem'),
                      items: [
                        for (final s in incomeSourceOptions) DropdownMenuItem(value: s.value, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() => _source = v ?? IncomeSource.estagio),
                    ),
                  ),
                  (
                    width: 220.0,
                    child: TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)', hintText: 'Ex: salário julho'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submitting ? null : _submit, child: const Text('Lançar receita')),
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
              Text('Receitas lançadas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              incomesAsync.when(
                data: (incomes) {
                  if (incomes.isEmpty) return const EmptyState('Nenhuma receita lançada ainda.');
                  final filtered = incomes.where((i) => isDateWithinRange(i.date, _filterFrom, _filterTo)).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      _filteredEmptyMessage(_filterFrom, _filterTo),
                      action: TextButton(onPressed: _clearFilter, child: const Text('Limpar filtro')),
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
    return 'Nenhuma receita entre ${formatDate(isoDateFrom(from))} e ${formatDate(isoDateFrom(to))}.';
  }
  if (from != null) {
    return 'Nenhuma receita a partir de ${formatDate(isoDateFrom(from))}.';
  }
  if (to != null) {
    return 'Nenhuma receita até ${formatDate(isoDateFrom(to))}.';
  }
  return 'Nenhuma receita lançada ainda.';
}

class _IncomeRow extends StatelessWidget {
  final Income income;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool divider;

  const _IncomeRow({required this.income, required this.onTap, required this.onDelete, required this.divider});

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
                          text: formatCurrency(income.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(text: ' · ${income.source.value} · ${income.date}', style: TextStyle(color: context.tokens.subtle)),
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
              tooltip: 'Remover receita',
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}
