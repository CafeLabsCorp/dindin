import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive_form_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/caixinha_budget_bar.dart';
import '../../widgets/caixinha_color_dot.dart';

class CategoriasPage extends ConsumerStatefulWidget {
  const CategoriasPage({super.key});

  @override
  ConsumerState<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends ConsumerState<CategoriasPage> {
  final _nameController = TextEditingController();
  final _monthlyBudgetController = TextEditingController();
  final _goalController = TextEditingController();
  bool _recurring = true;
  CategoryKind _kind = CategoryKind.save;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _monthlyBudgetController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    double? budget;
    double? goal;
    if (_kind == CategoryKind.spend) {
      final budgetText = _monthlyBudgetController.text.trim();
      if (budgetText.isNotEmpty) {
        budget = double.tryParse(budgetText.replaceAll(',', '.'));
        if (budget == null || budget <= 0) {
          setState(() => _error = 'Informe um limite válido ou deixe em branco.');
          return;
        }
      }
    } else {
      final goalText = _goalController.text.trim();
      if (goalText.isNotEmpty) {
        goal = double.tryParse(goalText.replaceAll(',', '.'));
        if (goal == null || goal <= 0) {
          setState(() => _error = 'Informe uma meta válida ou deixe em branco.');
          return;
        }
      }
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.createCategory(
        name: name,
        recurring: _recurring,
        monthlyBudget: budget,
        kind: _kind,
        goalAmount: goal,
      );
      _nameController.clear();
      _monthlyBudgetController.clear();
      _goalController.clear();
      setState(() => _recurring = true);
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
        title: const Text('Remover categoria?'),
        content: const Text('Isso também apaga alocações e gastos ligados a ela.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteCategory(id);
  }

  void _editCategory(Category category) {
    showAdaptiveFormSheet(
      context,
      contentBuilder: (ctx) => _EditCategoryForm(ref: ref, category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final summary = ref.watch(summaryProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      children: [
        Text('Categorias', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Cada categoria vira uma caixinha onde você guarda dinheiro todo mês.', style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nome da categoria', hintText: 'Ex: Aluguel, Mercado...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: _submitting ? null : _submit, child: const Text('Adicionar')),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(
                    value: CategoryKind.save,
                    label: Text('Guardar'),
                    icon: Icon(Icons.savings_outlined),
                  ),
                  ButtonSegment(
                    value: CategoryKind.spend,
                    label: Text('Gastar'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _submitting ? null : (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 4),
              Text(
                _kind == CategoryKind.save
                    ? 'Cofrinho: dinheiro que você junta (viagem, reserva, projeto).'
                    : 'Envelope: dinheiro que você separa pra gastar no mês.',
                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
              ),
              const SizedBox(height: 12),
              if (_kind == CategoryKind.spend)
                TextField(
                  controller: _monthlyBudgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Limite mensal de gasto (opcional)', hintText: '0,00'),
                )
              else
                TextField(
                  controller: _goalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Meta de valor (opcional)', hintText: 'Ex: 5000,00'),
                ),
              CheckboxListTile(
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v ?? true),
                title: const Text('Recorrente (repete todo mês)'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
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
          child: categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const EmptyState('Nenhuma categoria ainda. Crie a primeira acima.');
              }
              return Column(
                children: [
                  for (var i = 0; i < categories.length; i++)
                    InkWell(
                      onTap: () => _editCategory(categories[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: i > 0 ? Border(top: BorderSide(color: context.tokens.border)) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CaixinhaColorDot(
                                        color: caixinhaPaletteColor(i, dark: dark),
                                        label: categories[i].name,
                                        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      ),
                                      Text(
                                        '${categories[i].recurring ? 'Recorrente' : 'Pontual'} · desde ${formatDate(categories[i].createdAt)}',
                                        style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _delete(categories[i].id),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remover categoria',
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ],
                            ),
                            if (categories[i].effectiveKind == CategoryKind.save &&
                                categories[i].goalAmount != null) ...[
                              const SizedBox(height: 8),
                              CaixinhaGoalBar(
                                saved: summary?.balancesByCategory[categories[i].id] ?? 0,
                                goal: categories[i].goalAmount!,
                              ),
                            ] else if (categories[i].effectiveKind == CategoryKind.save) ...[
                              const SizedBox(height: 4),
                              CaixinhaSavedThisMonth(
                                savedThisMonth: summary?.savedThisMonthByCat[categories[i].id] ?? 0,
                              ),
                            ] else if (categories[i].monthlyBudget != null) ...[
                              const SizedBox(height: 8),
                              CaixinhaBudgetBar(
                                spent: summary?.currentMonth.expenseByCategory[categories[i].id] ?? 0,
                                limit: categories[i].monthlyBudget!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ),
      ],
    );
  }
}

/// Editing an existing category (§5.2: "reuse the same tap-row-to-edit sheet
/// ... one interaction pattern for 'change anything about a category,' not a
/// second bespoke UI just for limits").
class _EditCategoryForm extends StatefulWidget {
  final WidgetRef ref;
  final Category category;

  const _EditCategoryForm({required this.ref, required this.category});

  @override
  State<_EditCategoryForm> createState() => _EditCategoryFormState();
}

class _EditCategoryFormState extends State<_EditCategoryForm> {
  late final TextEditingController _nameController = TextEditingController(text: widget.category.name);
  late final TextEditingController _monthlyBudgetController = TextEditingController(
    text: widget.category.monthlyBudget != null ? formatAmountInput(widget.category.monthlyBudget!) : '',
  );
  late final TextEditingController _goalController = TextEditingController(
    text: widget.category.goalAmount != null ? formatAmountInput(widget.category.goalAmount!) : '',
  );
  late bool _recurring = widget.category.recurring;
  late CategoryKind _kind = widget.category.effectiveKind;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _monthlyBudgetController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }
    double? budget;
    double? goal;
    if (_kind == CategoryKind.spend) {
      final budgetText = _monthlyBudgetController.text.trim();
      if (budgetText.isNotEmpty) {
        budget = double.tryParse(budgetText.replaceAll(',', '.'));
        if (budget == null || budget <= 0) {
          setState(() => _error = 'Informe um limite válido ou deixe em branco.');
          return;
        }
      }
    } else {
      final goalText = _goalController.text.trim();
      if (goalText.isNotEmpty) {
        goal = double.tryParse(goalText.replaceAll(',', '.'));
        if (goal == null || goal <= 0) {
          setState(() => _error = 'Informe uma meta válida ou deixe em branco.');
          return;
        }
      }
    }
    final firestore = widget.ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.updateCategory(
        widget.category.id,
        name: name,
        recurring: _recurring,
        monthlyBudget: budget,
        clearMonthlyBudget: budget == null,
        kind: _kind,
        goalAmount: goal,
        clearGoalAmount: goal == null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Editar categoria', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          enabled: !_submitting,
          decoration: const InputDecoration(labelText: 'Nome da categoria'),
        ),
        const SizedBox(height: 12),
        SegmentedButton<CategoryKind>(
          segments: const [
            ButtonSegment(
              value: CategoryKind.save,
              label: Text('Guardar'),
              icon: Icon(Icons.savings_outlined),
            ),
            ButtonSegment(
              value: CategoryKind.spend,
              label: Text('Gastar'),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: _submitting ? null : (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 12),
        if (_kind == CategoryKind.spend)
          TextField(
            controller: _monthlyBudgetController,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Limite mensal de gasto (opcional)', hintText: '0,00'),
          )
        else
          TextField(
            controller: _goalController,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Meta de valor (opcional)', hintText: 'Ex: 5000,00'),
          ),
        CheckboxListTile(
          value: _recurring,
          onChanged: _submitting ? null : (v) => setState(() => _recurring = v ?? true),
          title: const Text('Recorrente (repete todo mês)'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
