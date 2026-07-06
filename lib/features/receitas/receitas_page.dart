import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                      for (var i = 0; i < incomes.length; i++) _IncomeRow(income: incomes[i], onDelete: () => _delete(incomes[i].id), divider: i > 0),
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

class _IncomeRow extends StatelessWidget {
  final Income income;
  final VoidCallback onDelete;
  final bool divider;

  const _IncomeRow({required this.income, required this.onDelete, required this.divider});

  @override
  Widget build(BuildContext context) {
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
                      TextSpan(text: formatCurrency(income.amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: ' · ${income.source.value} · ${income.date}', style: TextStyle(color: context.tokens.subtle)),
                    ],
                  ),
                ),
                if (income.description != null)
                  Text(income.description!, style: TextStyle(fontSize: 12, color: context.tokens.subtle)),
              ],
            ),
          ),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

String todayIsoFrom(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
