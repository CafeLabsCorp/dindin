import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/income.dart';
import '../../models/income_source.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';

const _sources = [
  (value: IncomeSource.estagio, label: 'Estágio'),
  (value: IncomeSource.freela, label: 'Freela'),
  (value: IncomeSource.outro, label: 'Outro'),
];

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
        date: todayIsoFrom(_date),
        amount: value,
        source: _source,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      );
      _amountController.clear();
      _descriptionController.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover receita?'),
        content: const Text('As alocações feitas a partir dela também somem.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteIncome(id);
  }

  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(incomesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final unallocated = ref.watch(unallocatedByIncomeProvider);

    return ListView(
      children: [
        Text('Receitas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Lance o quanto entrou, de onde veio, e depois separe entre as caixinhas.',
          style: TextStyle(color: context.tokens.muted),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 160,
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
                        child: Text(formatDate(todayIsoFrom(_date))),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<IncomeSource>(
                      initialValue: _source,
                      decoration: const InputDecoration(labelText: 'Origem'),
                      items: [
                        for (final s in _sources) DropdownMenuItem(value: s.value, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() => _source = v ?? IncomeSource.estagio),
                    ),
                  ),
                  SizedBox(
                    width: 220,
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
              Text('Receitas lançadas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              incomesAsync.when(
                data: (incomes) {
                  if (incomes.isEmpty) return const EmptyState('Nenhuma receita lançada ainda.');
                  return Column(
                    children: [
                      for (final income in incomes)
                        _IncomeRow(
                          income: income,
                          categories: categories,
                          unallocated: unallocated[income.id] ?? 0,
                          onDelete: () => _delete(income.id),
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

class _IncomeRow extends ConsumerStatefulWidget {
  final Income income;
  final List<Category> categories;
  final double unallocated;
  final VoidCallback onDelete;

  const _IncomeRow({
    required this.income,
    required this.categories,
    required this.unallocated,
    required this.onDelete,
  });

  @override
  ConsumerState<_IncomeRow> createState() => _IncomeRowState();
}

class _IncomeRowState extends ConsumerState<_IncomeRow> {
  bool _open = false;
  String? _categoryId;
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _allocate() async {
    final categoryId = _categoryId ?? widget.categories.firstOrNull?.id;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (categoryId == null || value == null || value <= 0) {
      setState(() => _error = 'Escolha uma categoria e um valor válido.');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(firestoreServiceProvider)!.createAllocation(
        incomeId: widget.income.id,
        categoryId: categoryId,
        amount: value,
        date: widget.income.date,
      );
      _amountController.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullyAllocated = widget.unallocated <= 0.009;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.tokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: formatCurrency(widget.income.amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                          TextSpan(
                            text: ' · ${widget.income.source.value} · ${widget.income.date}',
                            style: TextStyle(color: context.tokens.subtle),
                          ),
                        ],
                      ),
                    ),
                    if (widget.income.description != null)
                      Text(widget.income.description!, style: TextStyle(fontSize: 12, color: context.tokens.subtle)),
                  ],
                ),
              ),
              Text(
                fullyAllocated ? 'Totalmente alocada' : '${formatCurrency(widget.unallocated)} a alocar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fullyAllocated ? const Color(0xFF0CA30C) : const Color(0xFFEDA100),
                ),
              ),
              TextButton(onPressed: () => setState(() => _open = !_open), child: Text(_open ? 'Fechar' : 'Alocar')),
              TextButton(
                onPressed: widget.onDelete,
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Remover'),
              ),
            ],
          ),
          if (_open) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryId ?? widget.categories.firstOrNull?.id,
                    decoration: const InputDecoration(labelText: 'Caixinha'),
                    items: widget.categories.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text('Nenhuma categoria criada'))]
                        : [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _amountController.text = widget.unallocated.toStringAsFixed(2)),
                  child: const Text('Preencher restante'),
                ),
                FilledButton(onPressed: _allocate, child: const Text('Confirmar')),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ],
      ),
    );
  }
}

String todayIsoFrom(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
