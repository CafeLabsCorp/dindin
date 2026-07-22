import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

List<({IconData icon, IconData selectedIcon, String label})> _destinations(AppLocalizations l10n) => [
  (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: l10n.navDashboard),
  (icon: Icons.arrow_downward, selectedIcon: Icons.arrow_downward, label: l10n.navReceitas),
  (icon: Icons.arrow_upward, selectedIcon: Icons.arrow_upward, label: l10n.navGastos),
  (icon: Icons.category_outlined, selectedIcon: Icons.category, label: l10n.navCategorias),
  (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.navAjustes),
];

/// App-wide nav: bottom bar on narrow (mobile) screens, a side rail on wide
/// (web/desktop) screens — per §4 of FLUTTER_MIGRATION.md.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
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
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
