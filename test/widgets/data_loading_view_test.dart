import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/data_loading_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Object? error, VoidCallback? onRetry}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DataLoadingView(error: error, onRetry: onRetry ?? () {})),
      ),
    );
  }

  testWidgets('carregando: só o spinner, sem botão', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('demorando: aparece o aviso de conexão e o botão de tentar de novo', (tester) async {
    var retries = 0;
    await pump(tester, onRetry: () => retries++);
    await tester.pump(const Duration(seconds: 9));

    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'ainda tentando');
    expect(find.text('Está demorando mais que o normal. Verifique sua conexão.'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    expect(retries, 1);
  });

  testWidgets('erro de rede: mensagem de conexão no lugar do spinner', (tester) async {
    await pump(tester, error: FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sem conexão com a internet. Verifique e tente de novo.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('outro erro: mensagem simples, nunca o texto cru da exceção', (tester) async {
    await pump(tester, error: StateError('internal detail xyz'));

    expect(find.text('Não foi possível carregar seus dados.'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });
}
