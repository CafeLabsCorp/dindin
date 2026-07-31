import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/firestore_service.dart';
import '../utils/format.dart';

/// Every top-level destination, in the SAME order as the branches in
/// `app.dart` — the index is what `goBranch` takes, so the two lists are one
/// contract, not two coincidences.
///
/// On narrow screens all of them live in one menu behind the logo; on wide
/// screens they're the side rail. Either way it's this one list — no subset
/// is treated specially.
List<({IconData icon, IconData selectedIcon, String label})> _destinations(AppLocalizations l10n) => [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: l10n.navDashboard),
  (icon: Icons.arrow_downward, selectedIcon: Icons.arrow_downward, label: l10n.navReceitas),
  (icon: Icons.arrow_upward, selectedIcon: Icons.arrow_upward, label: l10n.navGastos),
  (icon: Icons.autorenew, selectedIcon: Icons.autorenew, label: l10n.navAssinaturas),
  (icon: Icons.credit_card_outlined, selectedIcon: Icons.credit_card, label: l10n.navParcelamentos),
  (icon: Icons.category_outlined, selectedIcon: Icons.category, label: l10n.navCategorias),
  (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.navAjustes),
];

/// App-wide nav: a single menu behind the logo on narrow (mobile) screens, a
/// side rail on wide (web/desktop) screens. The 720px breakpoint is the same
/// one the responsive forms use — see §4 of FLUTTER_MIGRATION.md.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fires recurring-charge catch-up (subscriptions + installment purchases)
    // once per signed-in session — see recurringChargesCatchUpProvider.
    // Watched (not read) so it re-runs if the user signs out and back in as
    // someone else.
    ref.watch(recurringChargesCatchUpProvider);

    // Tell the user money just left their account. These charges are posted
    // with no interaction at all, so without this the only trace is rows
    // quietly appearing in a list they may not open. Listened from the shell
    // (not a single screen) because the charge happens on app open, whichever
    // tab that lands on.
    ref.listen<AsyncValue<RecurringChargeReport>>(recurringChargesCatchUpProvider, (
      previous,
      next,
    ) {
      final report = next.value;
      if (report == null || report.isEmpty) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.recurringChargesPosted(report.count, formatCurrency(report.total)),
          ),
        ),
      );
    });

    final l10n = AppLocalizations.of(context)!;
    final destinations = _destinations(l10n);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SvgPicture.asset('assets/logo.svg', height: 32),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SafeArea(
                child: Padding(padding: const EdgeInsets.all(24), child: navigationShell),
              ),
            ),
          ],
        ),
      );
    }

    // No app bar and no bottom bar on narrow screens. The app bar showed the
    // current screen's name, which every page ALSO prints as its own title —
    // the same word twice, one line apart. Instead of dropping one of them,
    // the page title took the app bar's job: PageHeader grows a chevron and
    // opens this menu. One name on screen, and what you tap is what you read.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppNavigation(
            openMenu: () => _openMenu(context, destinations),
            child: navigationShell,
          ),
        ),
      ),
    );
  }

  /// Every destination, as a list that drops down from the top over a dimmed
  /// background.
  ///
  /// It descends from where you tapped (the title, at the top of the screen)
  /// rather than rising from the bottom, so the motion points back at its
  /// trigger. The scrim is what says "this is modal — the page is still
  /// there, behind".
  ///
  /// A list, and not the radial wheel that was floated: a wheel you rotate
  /// has no affordance saying so, is awkward with a mouse (this app's live
  /// platform is the web), and would need a lot of custom work to be
  /// reachable by a screen reader. A list is all three for free.
  void _openMenu(
    BuildContext context,
    List<({IconData icon, IconData selectedIcon, String label})> destinations,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) {
        final theme = Theme.of(dialogContext);
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    ListTile(
                      leading: Icon(
                        navigationShell.currentIndex == i
                            ? destinations[i].selectedIcon
                            : destinations[i].icon,
                      ),
                      title: Text(destinations[i].label),
                      selected: navigationShell.currentIndex == i,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        navigationShell.goBranch(
                          i,
                          initialLocation: i == navigationShell.currentIndex,
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

/// Hands the navigation menu down to the screens, so a page's own title can
/// be what opens it (see [PageHeader]).
///
/// [openMenu] is null on wide screens — the side rail is the navigation
/// there, and a title that opened a redundant menu would just be noise.
class AppNavigation extends InheritedWidget {
  final VoidCallback? openMenu;

  const AppNavigation({super.key, required this.openMenu, required super.child});

  static AppNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigation>();

  // Compares only whether a menu EXISTS: `openMenu` is a fresh closure on
  // every build, so comparing it directly would rebuild every screen on every
  // frame for no reason.
  @override
  bool updateShouldNotify(AppNavigation oldWidget) =>
      (openMenu == null) != (oldWidget.openMenu == null);
}
