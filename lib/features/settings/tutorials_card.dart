import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/tutorial_progress.dart';
import '../../providers/providers.dart';
import '../../theme/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/saved_feedback.dart';

/// Ajustes -> "Tutoriais": how many onboarding tutorials the user has seen, one
/// row per page, and a way to see any of them again (`docs/onboarding-design.md`
/// §5). "Rever" forgets that page's outcome and opens the page, where the
/// tutorial starts on its own.
class TutorialsCard extends ConsumerWidget {
  const TutorialsCard({super.key});

  /// Pages in the order of the app menu, each with its route.
  static const _pages = <(TutorialPage, String)>[
    (TutorialPage.dashboard, '/'),
    (TutorialPage.receitas, '/receitas'),
    (TutorialPage.gastos, '/gastos'),
    (TutorialPage.assinaturas, '/assinaturas'),
    (TutorialPage.parcelamentos, '/parcelamentos'),
    (TutorialPage.categorias, '/categorias'),
    (TutorialPage.ajustes, '/ajustes'),
  ];

  static String _pageName(AppLocalizations l10n, TutorialPage page) => switch (page) {
    TutorialPage.dashboard => l10n.navDashboard,
    TutorialPage.receitas => l10n.navReceitas,
    TutorialPage.gastos => l10n.navGastos,
    TutorialPage.assinaturas => l10n.navAssinaturas,
    TutorialPage.parcelamentos => l10n.navParcelamentos,
    TutorialPage.categorias => l10n.navCategorias,
    TutorialPage.ajustes => l10n.navAjustes,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final primary = Theme.of(context).colorScheme.primary;
    // Until the saved progress has loaded the statuses would all read "Ainda
    // não", which is a lie: show nothing yet.
    final progress = ref.watch(tutorialProgressProvider).value;
    if (progress == null) return const SizedBox.shrink();

    final seen = {for (final (page, _) in _pages) page: ref.watch(tutorialSeenProvider(page)) == true};
    final seenCount = seen.values.where((v) => v).length;

    String statusOf(TutorialPage page) {
      if (!seen[page]!) return l10n.tutorialStatusNotYet;
      final entry = progress[page];
      return entry != null && entry.covers(page) && entry.state == TutorialState.skipped
          ? l10n.tutorialStatusSkipped
          : l10n.tutorialStatusSeen;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tutorialsSectionLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                l10n.tutorialsProgress(seenCount, _pages.length),
                style: TextStyle(fontSize: 12, color: tokens.subtle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fuller is better here (like a goal bar); the count above carries the
          // number, so the bar is never the only information.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: seenCount / _pages.length,
                minHeight: 6,
                backgroundColor: tokens.border,
                valueColor: AlwaysStoppedAnimation(primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final (page, route) in _pages)
            _TutorialRow(
              name: _pageName(l10n, page),
              status: statusOf(page),
              seen: seen[page]!,
              onTap: () async {
                // Forget it first, then go: the page's tutorial starts by itself.
                await resetTutorial(ref, page);
                if (context.mounted) context.go(route);
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              // No confirmation dialog: nothing is deleted, and "Desfazer"
              // covers an accidental tap.
              final before = {...progress};
              resetAllTutorials(ref);
              showSavedSnackBar(
                context,
                l10n.tutorialsResetMessage,
                actionLabel: l10n.undoAction,
                onAction: () => restoreTutorials(ref, before),
              );
            },
            child: Text(l10n.tutorialReviewAll),
          ),
        ],
      ),
    );
  }
}

class _TutorialRow extends StatelessWidget {
  final String name;
  final String status;
  final bool seen;
  final VoidCallback onTap;

  const _TutorialRow({required this.name, required this.status, required this.seen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final action = seen ? l10n.tutorialActionReview : l10n.tutorialActionView;
    final seenColor = Theme.of(context).colorScheme.primary;
    final isSeen = status == l10n.tutorialStatusSeen;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: l10n.tutorialRowSemantics(name, status, action),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Expanded(child: Text(name)), // wraps instead of cutting the name
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: isSeen ? seenColor : tokens.subtle,
                fontWeight: isSeen ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
