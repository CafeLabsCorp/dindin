import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_card.dart';

void main() {
  testWidgets('EmptyState sem action não renderiza nenhum botão extra', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: EmptyState('Nada por aqui.')),
      ),
    );

    expect(find.text('Nada por aqui.'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('EmptyState com action renderiza a ação logo abaixo da mensagem (§5.4)', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EmptyState(
            'Nenhuma receita entre 01/07/2026 e 10/07/2026.',
            action: TextButton(onPressed: () => cleared = true, child: const Text('Limpar filtro')),
          ),
        ),
      ),
    );

    expect(find.text('Nenhuma receita entre 01/07/2026 e 10/07/2026.'), findsOneWidget);
    expect(find.text('Limpar filtro'), findsOneWidget);

    await tester.tap(find.text('Limpar filtro'));
    expect(cleared, isTrue);
  });
}
