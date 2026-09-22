import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/page_header.dart';
import '../../widgets/app_shell.dart';
import '../../providers/locale_provider.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/app_card.dart';

/// dindin-landing's legal pages — no locale prefix needed, its middleware
/// redirects `/privacidade`/`/termos` to the visitor's locale
/// (`/pt/privacidade`, `/en/termos`, ...) on its own. Kept as MINUTA
/// (in-review) as of this writing — see `dindin/legal/*.md` and
/// `tarefas/empresa/dindin.md`'s decision 6; the app links to them
/// regardless, same as the Play Store listing does.
const _privacyPolicyUrl = 'https://dindin.cafelabs.net/privacidade';
const _termsOfUseUrl = 'https://dindin.cafelabs.net/termos';

/// The outcome of the "Excluir conta" confirmation dialog below.
enum _DeleteAccountDialogAction { cancel, export, delete }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;

  bool _deleteBusy = false;
  String? _deleteMessage;

  bool _verificationBusy = false;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `Ajustes` lives inside `StatefulShellRoute.indexedStack` (see app.dart)
    // — its state stays alive across tab switches, so `initState` only runs
    // once per app session, not every time this tab is revisited. Combined
    // with `didChangeAppLifecycleState` below, this covers the two moments
    // that actually matter: landing here fresh, and coming back from
    // wherever the user tapped the confirmation link (usually a mail app).
    _refreshEmailVerified();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshEmailVerified();
  }

  /// `User.emailVerified` is a snapshot taken at sign-in time and doesn't
  /// update on its own — see `AuthService.reloadCurrentUser`. Best-effort:
  /// failing silently (e.g. offline) just leaves the last-known status on
  /// screen instead of surfacing a spurious error for something that isn't
  /// user-initiated.
  Future<void> _refreshEmailVerified() async {
    try {
      await ref.read(authServiceProvider).reloadCurrentUser();
    } catch (_) {
      // Best-effort — see doc comment above.
    }
    if (mounted) setState(() {});
  }

  Future<void> _resendVerificationEmail() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _verificationBusy = true;
      _verificationMessage = null;
    });
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (!mounted) return;
      setState(() => _verificationMessage = l10n.verificationEmailSentMessage);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _verificationMessage = e.code == 'too-many-requests'
            ? l10n.verificationEmailRateLimitedMessage
            : l10n.verificationEmailErrorMessage(e.message ?? e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificationMessage = l10n.verificationEmailErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
    }
  }

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

  Future<void> _openLink(String url) async {
    final l10n = AppLocalizations.of(context)!;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.linkOpenErrorMessage)));
    }
  }

  /// The "Excluir conta" flow (B3, decision 3 — opção A: hard delete
  /// imediato, sem carência). A single confirmation dialog offers exporting
  /// a backup first (not required) alongside cancel/delete, matching the
  /// spec exactly: "export oferecido antes de confirmar (não obrigatório)".
  ///
  /// Choosing "Exportar backup" closes this dialog and runs the SAME export
  /// flow as the Backup card above, rather than keeping this dialog open
  /// through an async operation — reuses `_export()` as-is instead of making
  /// this dialog stateful. The user re-opens "Excluir conta" afterward to
  /// actually delete; a two-tap trade-off for a lot less code, and this
  /// action is rare enough that it doesn't need to be one tap.
  Future<void> _openDeleteAccountDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showDialog<_DeleteAccountDialogAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DeleteAccountDialogAction.cancel),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DeleteAccountDialogAction.export),
            child: Text(l10n.exportBackupButton),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, _DeleteAccountDialogAction.delete),
            child: Text(l10n.deleteAccountConfirmDeleteAction),
          ),
        ],
      ),
    );

    if (action == null || action == _DeleteAccountDialogAction.cancel) return;
    if (action == _DeleteAccountDialogAction.export) {
      await _export();
      return;
    }

    setState(() {
      _deleteBusy = true;
      _deleteMessage = null;
    });
    try {
      // Order matters (see AuthService.deleteAccount's doc comment): the
      // Firestore subtree is wiped FIRST, the Auth identity LAST — the
      // reverse order would strand `users/{uid}` unreachable forever (uids
      // are never reissued).
      final firestore = ref.read(firestoreServiceProvider);
      if (firestore != null) {
        await firestore.deleteAllUserData();
      }
      await ref.read(authServiceProvider).deleteAccount();
      // On success, `authStateProvider` emits null and the router redirect
      // (see app.dart) sends this screen away on its own — this widget may
      // already be disposed by the time we get here, hence every `mounted`
      // check below (and the lack of any navigation call here, mirroring
      // how `signOut()` is handled elsewhere in this file).
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleteMessage = e.code == 'requires-recent-login'
            ? l10n.deleteAccountReauthRequiredMessage
            : l10n.deleteAccountErrorMessage(e.message ?? e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleteMessage = l10n.deleteAccountErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).value;

    return ListView(
      children: [
        PageHeader(
          title: l10n.settingsTitle,
          subtitle: l10n.settingsSubtitle,
          onOpenMenu: AppNavigation.of(context)?.openMenu,
          menuLabel: l10n.navMenu,
        ),
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
              Text(l10n.languageSectionLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // localeProvider is null by default ("follow system") — see
              // lib/providers/locale_provider.dart. 'Português'/'English' are
              // language endonyms, kept as literal labels (not routed through
              // AppLocalizations) same as Domo's precedent for this control.
              SegmentedButton<Locale?>(
                segments: [
                  ButtonSegment(value: null, label: Text(l10n.languageSystemOption)),
                  const ButtonSegment(value: Locale('pt'), label: Text('Português')),
                  const ButtonSegment(value: Locale('en'), label: Text('English')),
                ],
                selected: {ref.watch(localeProvider)},
                onSelectionChanged: (set) => ref.read(localeProvider.notifier).state = set.first,
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
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.privacySectionLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // Defaults to `false` (collection ON) while the stream hasn't
              // resolved yet or the user is signed out — matches
              // FirestoreService.watchAnalyticsOptOut's own default.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.analyticsOptOutLabel),
                subtitle: Text(l10n.analyticsOptOutDescription, style: const TextStyle(fontSize: 12)),
                value: !(ref.watch(analyticsOptOutProvider).value ?? false),
                onChanged: (enabled) {
                  final firestore = ref.read(firestoreServiceProvider);
                  firestore?.setAnalyticsOptOut(!enabled);
                },
              ),
              // Security audit finding "Verificação de e-mail não
              // implementada" (2026-09-22) — non-blocking by design: this is
              // the only place the unverified state surfaces, nothing else
              // in the app gates on it. Reads `user` (from
              // `authStateProvider`, watched above) rather than constructing
              // `authServiceProvider` here — `reload()`'s effect on
              // `emailVerified` shows up on this SAME `User` object (see
              // `AuthService.reloadCurrentUser`'s doc comment), and every
              // other widget test in this file overrides only
              // `authStateProvider`, not `authServiceProvider`.
              if (AuthService.needsEmailVerification(user)) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.statusWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.tokens.statusWarning.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.emailNotVerifiedMessage, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _verificationBusy ? null : _resendVerificationEmail,
                        child: Text(l10n.resendVerificationEmailButton),
                      ),
                      if (_verificationMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_verificationMessage!, style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.legalSectionLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                l10n.legalDescription,
                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () => _openLink(_privacyPolicyUrl),
                    child: Text(l10n.privacyPolicyLinkLabel),
                  ),
                  OutlinedButton(
                    onPressed: () => _openLink(_termsOfUseUrl),
                    child: Text(l10n.termsOfUseLinkLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dangerZoneSectionLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.deleteAccountDescription,
                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: _deleteBusy ? null : _openDeleteAccountDialog,
                child: Text(l10n.deleteAccountButton),
              ),
              if (_deleteMessage != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_deleteMessage!)),
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
