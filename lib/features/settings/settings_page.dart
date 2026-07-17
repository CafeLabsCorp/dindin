import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(importExportServiceProvider)!.exportToFile();
      if (!mounted) return;
      setState(() => _message = l10n.exportSuccessMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = l10n.exportErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(l10n.importConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.importAction)),
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
        if (mounted) setState(() => _busy = false);
        return;
      }
      await service.importFromFile(db);
      if (!mounted) return;
      setState(() => _message = l10n.importSuccessMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = l10n.importErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;

    return ListView(
      children: [
        Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.settingsSubtitle, style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.accountLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(user?.email ?? user?.displayName ?? '—'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: Text(l10n.signOutButton),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.backupSectionLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                l10n.backupDescription,
                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: _busy ? null : _export, child: Text(l10n.exportBackupButton)),
                  OutlinedButton(onPressed: _busy ? null : _import, child: Text(l10n.importBackupButton)),
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
            l10n.footerBrand,
            style: TextStyle(fontSize: 12, color: context.tokens.subtle),
          ),
        ),
      ],
    );
  }
}
