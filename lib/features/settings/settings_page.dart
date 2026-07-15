import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/app_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;
  String? _message;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(importExportServiceProvider)!.exportToFile();
      setState(() => _message = 'Backup exportado.');
    } catch (e) {
      setState(() => _message = 'Erro ao exportar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar backup?'),
        content: const Text('Isso substitui todos os dados atuais pelos dados do arquivo escolhido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(importExportServiceProvider)!;
      final db = await service.pickAndParseFile();
      if (db == null) {
        setState(() => _busy = false);
        return;
      }
      await service.importFromFile(db);
      setState(() => _message = 'Backup importado.');
    } catch (e) {
      setState(() => _message = 'Erro ao importar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return ListView(
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Conta, backup e restauração de dados.', style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conta', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(user?.email ?? user?.displayName ?? '—'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Exporte seus dados para um arquivo .json, ou importe um backup (substitui os dados atuais).',
                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: _busy ? null : _export, child: const Text('Exportar backup')),
                  OutlinedButton(onPressed: _busy ? null : _import, child: const Text('Importar backup')),
                ],
              ),
              if (_message != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Dindin — um produto Café Labs',
            style: TextStyle(fontSize: 12, color: context.tokens.subtle),
          ),
        ),
      ],
    );
  }
}
