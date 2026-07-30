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
/// The first [_bottomDestinationCount] are the bottom bar on narrow screens;
/// the rest open from the logo button. The split is by how often you go
/// there, not by importance: the five money screens are daily, while
/// Categorias (you create a caixinha once) and Ajustes are management.
List<({IconData icon, IconData selectedIcon, String label})> _destinations(AppLocalizations l10n) => [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: l10n.navDashboard),
  (icon: Icons.arrow_downward, selectedIcon: Icons.arrow_downward, label: l10n.navReceitas),
  (icon: Icons.arrow_upward, selectedIcon: Icons.arrow_upward, label: l10n.navGastos),
  (icon: Icons.autorenew, selectedIcon: Icons.autorenew, label: l10n.navAssinaturas),
  (icon: Icons.credit_card_outlined, selectedIcon: Icons.credit_card, label: l10n.navParcelamentos),
  (icon: Icons.category_outlined, selectedIcon: Icons.category, label: l10n.navCategorias),
  (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.navAjustes),
];

/// How many destinations fit the bottom bar. Five is Material's ceiling for a
/// `NavigationBar` — past it labels truncate and touch targets shrink — and
/// it's why the remaining destinations moved behind the logo instead of the
/// bar simply growing.
const _bottomDestinationCount = 5;

/// App-wide nav: bottom bar on narrow (mobile) screens, a side rail on wide
/// (web/desktop) screens — per §4 of FLUTTER_MIGRATION.md.
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

    return Scaffold(
      appBar: AppBar(title: SvgPicture.asset('assets/logo.svg', height: 28)),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: navigationShell),
      ),
      bottomNavigationBar: NavigationBar(
        // The logo occupies the last slot. When the user is on one of the
        // screens BEHIND it, that slot is what reads as selected — which is
        // honest: "you're in the section this button opens".
        selectedIndex: navigationShell.currentIndex < _bottomDestinationCount
            ? navigationShell.currentIndex
            : _bottomDestinationCount,
        onDestinationSelected: (i) {
          if (i == _bottomDestinationCount) {
            _openMoreMenu(context, l10n, destinations);
            return;
          }
          navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
        },
        destinations: [
          for (final d in destinations.take(_bottomDestinationCount))
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          NavigationDestination(
            icon: SvgPicture.asset('assets/logo.svg', height: 24),
            label: l10n.navMore,
          ),
        ],
      ),
    );
  }

  /// The overflow destinations, as a plain list in a bottom sheet.
  ///
  /// A sheet rather than the radial wheel that was floated: a wheel you
  /// rotate has no affordance saying so, is awkward with a mouse (this app's
  /// live platform is the web), and would need a lot of custom work to be
  /// reachable by a screen reader. A list is all three for free, and still
  /// opens from the logo — which was the point.
  void _openMoreMenu(
    BuildContext context,
    AppLocalizations l10n,
    List<({IconData icon, IconData selectedIcon, String label})> destinations,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = _bottomDestinationCount; i < destinations.length; i++)
              ListTile(
                leading: Icon(
                  navigationShell.currentIndex == i
                      ? destinations[i].selectedIcon
                      : destinations[i].icon,
                ),
                title: Text(destinations[i].label),
                selected: navigationShell.currentIndex == i,
                onTap: () {
                  Navigator.pop(sheetContext);
                  navigationShell.goBranch(
                    i,
                    initialLocation: i == navigationShell.currentIndex,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
