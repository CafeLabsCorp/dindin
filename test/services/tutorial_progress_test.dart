// Onboarding progress: which pages' tutorials the user has seen.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/models/tutorial_progress.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  setUpAll(() {
    registerFallbackValue(TutorialPage.dashboard);
    registerFallbackValue(TutorialState.done);
  });

  group('modelo', () {
    test('lê um doc bem formado e descarta o que não conhece ou está malformado', () {
      final progress = parseTutorialProgress({
        'dashboard': {'state': 'done', 'v': 1},
        'gastos': {'state': 'skipped', 'v': 2},
        'receitas': {'state': 'maybe', 'v': 1}, // estado inválido
        'categorias': 'done', // não é mapa
        'ajustes': {'state': 'done'}, // sem versão
        'outraPagina': {'state': 'done', 'v': 1}, // página desconhecida
      });
      expect(progress.keys, {TutorialPage.dashboard, TutorialPage.gastos});
      expect(progress[TutorialPage.gastos]!.state, TutorialState.skipped);
      expect(parseTutorialProgress(null), isEmpty);
    });

    test('um resultado salvo numa versão antiga não cobre a versão atual', () {
      const old = TutorialEntry(state: TutorialState.done, version: 0);
      const current = TutorialEntry(state: TutorialState.done, version: 1);
      expect(old.covers(TutorialPage.dashboard), isFalse);
      expect(current.covers(TutorialPage.dashboard), isTrue);
    });

    test('o id de cada página bate com a lista fechada das rules', () {
      expect(TutorialPage.values.map((p) => p.id).toSet(), {
        'dashboard', 'receitas', 'gastos', 'assinaturas', 'parcelamentos', 'categorias', 'ajustes',
      });
      expect(tutorialVersions.keys.toSet(), TutorialPage.values.toSet());
    });
  });

  group('FirestoreService', () {
    late FakeFirebaseFirestore fake;
    late FirestoreService svc;

    setUp(() {
      fake = FakeFirebaseFirestore();
      svc = FirestoreService(uid: 'u1', firestore: fake);
    });

    test('sem doc, o progresso é vazio', () async {
      expect(await svc.watchTutorialProgress().first, isEmpty);
    });

    test('setTutorialProgress grava e mantém as outras páginas (merge)', () async {
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done);
      await svc.setTutorialProgress(TutorialPage.gastos, TutorialState.skipped);

      final progress = await svc.watchTutorialProgress().first;
      expect(progress[TutorialPage.dashboard]!.state, TutorialState.done);
      expect(progress[TutorialPage.gastos]!.state, TutorialState.skipped);
      expect(progress[TutorialPage.gastos]!.version, tutorialVersions[TutorialPage.gastos]);
    });

    test('resetTutorial esquece só aquela página', () async {
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done);
      await svc.setTutorialProgress(TutorialPage.gastos, TutorialState.done);

      await svc.resetTutorial(TutorialPage.dashboard);

      final progress = await svc.watchTutorialProgress().first;
      expect(progress.keys, {TutorialPage.gastos});
    });

    test('resetAllTutorials apaga tudo', () async {
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done);
      await svc.resetAllTutorials();
      expect(await svc.watchTutorialProgress().first, isEmpty);
    });

    test('excluir a conta também apaga o progresso dos tutoriais', () async {
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done);

      await svc.deleteAllUserData();

      final snap = await fake.doc('users/u1/meta/tutorials').get();
      expect(snap.exists, isFalse);
    });
  });

  group('tutorialSeenProvider', () {
    ProviderContainer container(FirestoreService? firestore) {
      final c = ProviderContainer(overrides: [firestoreServiceProvider.overrideWithValue(firestore)]);
      addTearDown(c.dispose);
      // Providers pause without a listener; keep the progress stream alive.
      c.listen(tutorialProgressProvider, (_, _) {});
      return c;
    }

    test('antes de carregar o progresso, não sabe (null): nada aparece', () {
      final c = container(null);
      expect(c.read(tutorialSeenProvider(TutorialPage.dashboard)), isNull);
    });

    test('carregado: visto só quem está salvo na versão atual', () async {
      final fake = FakeFirebaseFirestore();
      final svc = FirestoreService(uid: 'u1', firestore: fake);
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done);
      final c = container(svc);
      await c.read(tutorialProgressProvider.future);

      expect(c.read(tutorialSeenProvider(TutorialPage.dashboard)), isTrue);
      expect(c.read(tutorialSeenProvider(TutorialPage.gastos)), isFalse);
    });

    test('uma versão salva mais antiga volta a mostrar o tutorial', () async {
      final fake = FakeFirebaseFirestore();
      final svc = FirestoreService(uid: 'u1', firestore: fake);
      await svc.setTutorialProgress(TutorialPage.dashboard, TutorialState.done, version: 0);
      final c = container(svc);
      await c.read(tutorialProgressProvider.future);

      expect(c.read(tutorialSeenProvider(TutorialPage.dashboard)), isFalse);
    });
  });

  group('markTutorialEnded / reset (via WidgetRef)', () {
    testWidgets('a página fica vista na sessão mesmo se salvar no perfil falhar', (tester) async {
      final firestore = _MockFirestoreService();
      when(() => firestore.watchTutorialProgress()).thenAnswer((_) => Stream.value({}));
      when(() => firestore.setTutorialProgress(any(), any()))
          .thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      late WidgetRef ref;
      bool? seen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [firestoreServiceProvider.overrideWithValue(firestore)],
          child: Consumer(
            builder: (context, r, _) {
              ref = r;
              seen = r.watch(tutorialSeenProvider(TutorialPage.receitas));
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(seen, isFalse, reason: 'progresso carregado e vazio: ainda não visto');

      await markTutorialEnded(ref, TutorialPage.receitas, TutorialState.skipped);
      await tester.pump();

      expect(seen, isTrue);
    });
  });
}
