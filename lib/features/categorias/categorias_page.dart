import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';

class CategoriasPage extends ConsumerStatefulWidget {
  const CategoriasPage({super.key});

  @override
  ConsumerState<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends ConsumerState<CategoriasPage> {
  final _nameController = TextEditingController();
  bool _recurring = true;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.createCategory(name: name, recurring: _recurring);
      _nameController.clear();
      setState(() => _recurring = true);
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

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
                                Text(categories[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  '${categories[i].recurring ? 'Recorrente' : 'Pontual'} · desde ${formatDate(categories[i].createdAt)}',
                                  style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _delete(categories[i].id),
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
        ),
      ],
    );
  }
}
