import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/categorias/categorias_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/gastos/gastos_page.dart';
import 'features/receitas/receitas_page.dart';
import 'features/settings/settings_page.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/providers.dart';
import 'theme/theme.dart';
import 'widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class DindinApp extends ConsumerStatefulWidget {
  const DindinApp({super.key});

  @override
  ConsumerState<DindinApp> createState() => _DindinAppState();
}

class _DindinAppState extends ConsumerState<DindinApp> {
  late final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final signedIn = ref.read(authStateProvider).value != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!signedIn && !loggingIn) return '/login';
      if (signedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const DashboardPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/receitas', builder: (context, state) => const ReceitasPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/gastos', builder: (context, state) => const GastosPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/categorias', builder: (context, state) => const CategoriasPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/ajustes', builder: (context, state) => const SettingsPage())]),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'dindin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // localeProvider is null by default ("follow system") — pt is what
      // AppLocalizations falls back to when the system locale isn't
      // supported (see l10n.yaml), matching the product's Portuguese-first
      // copy. An explicit choice from Ajustes overrides this.
      locale: ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}

/// Bridges Riverpod's [authStateProvider] stream into a [Listenable] so
/// go_router re-evaluates `redirect` whenever the auth state changes.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(WidgetRef ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
