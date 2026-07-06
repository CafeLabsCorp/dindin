import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../receitas/receitas_page.dart' show todayIsoFrom;

class GastosPage extends ConsumerStatefulWidget {
  const GastosPage({super.key});

  @override
  ConsumerState<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends ConsumerState<GastosPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(String effectiveCategoryId) async {
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Escolha uma categoria e um valor válido.');
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
        date: todayIsoFrom(_date),
        amount: value,
        categoryId: effectiveCategoryId,
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

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final summary = ref.watch(summaryProvider);

    final effectiveCategoryId = _categoryId ?? (categories.isNotEmpty ? categories.first.id : null);
    final categoryName = {for (final c in categories) c.id: c.name};
    final availableBalance = effectiveCategoryId != null ? (summary?.balancesByCategory[effectiveCategoryId] ?? 0) : 0.0;

    return ListView(
      children: [
        Text('Gastos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Registre saídas de dinheiro de uma caixinha específica.', style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: categories.isEmpty
              ? const EmptyState('Crie uma categoria antes de lançar gastos.')
              : Column(
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
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: effectiveCategoryId,
                            decoration: const InputDecoration(labelText: 'Caixinha'),
                            items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Descrição (opcional)', hintText: 'Ex: supermercado'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Disponível: ${formatCurrency(availableBalance)}', style: TextStyle(fontSize: 12, color: context.tokens.subtle)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting || effectiveCategoryId == null ? null : () => _submit(effectiveCategoryId),
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
              Text('Gastos lançados', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) return const EmptyState('Nenhum gasto lançado ainda.');
                  return Column(
                    children: [
                      for (var i = 0; i < expenses.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: i > 0 ? Border(top: BorderSide(color: context.tokens.border)) : null,
                          ),
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
                                            text: formatCurrency(expenses[i].amount),
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          TextSpan(
                                            text:
                                                ' · ${categoryName[expenses[i].categoryId] ?? 'categoria removida'} · ${expenses[i].date}',
                                            style: TextStyle(color: context.tokens.subtle),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (expenses[i].description != null)
                                      Text(
                                        expenses[i].description!,
                                        style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _delete(expenses[i].id),
                                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                                child: const Text('Remover'),
                              ),
                            ],
                          ),
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
