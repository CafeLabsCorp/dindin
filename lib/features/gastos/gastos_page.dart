import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/responsive_form_row.dart';
import '../receitas/receitas_page.dart' show todayIsoFrom;

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
      await firestore.createExpense(
        date: todayIsoFrom(_date),
        amount: value,
        categoryId: _selection == _accountOption ? null : _selection,
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

    final categoryName = {for (final c in categories) c.id: c.name};
    final availableBalance = _selection == _accountOption
        ? (summary?.accountBalance ?? 0)
        : (summary?.balancesByCategory[_selection] ?? 0);

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
                        child: Text(formatDate(todayIsoFrom(_date))),
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
                    width: 200.0,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selection,
                      decoration: const InputDecoration(labelText: 'De onde sai'),
                      items: [
                        const DropdownMenuItem(value: _accountOption, child: Text('Conta')),
                        for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _selection = v ?? _accountOption),
                    ),
                  ),
                  (
                    width: 220.0,
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
              FilledButton(onPressed: _submitting ? null : _submit, child: const Text('Lançar gasto')),
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
                                            text: ' · ${_originLabel(expenses[i].categoryId, categoryName)} · ${expenses[i].date}',
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

String _originLabel(String? categoryId, Map<String, String> categoryName) {
  if (categoryId == null) return 'Conta';
  return categoryName[categoryId] ?? 'categoria removida';
}
