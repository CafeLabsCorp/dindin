# Arquitetura

Como o Dindin funciona por dentro. Para o que o app é e como rodar localmente,
ver `README.md`; para a modelagem de integridade de dinheiro (Firestore rules,
saldos denormalizados) ver `docs/BACKEND.md`; para a identidade visual ver
`docs/DESIGN.md`.

## Camadas

```
lib/
  main.dart            bootstrap: Firebase.initializeApp, intl pt_BR, runApp
  app.dart              MaterialApp.router: tema (light/dark) + go_router
  theme/                identidade visual ("Envelope caloroso", ver docs/DESIGN.md)
    colors.dart         AppPalette — tokens de cor hardcoded (light/dark)
    theme.dart          ColorScheme + TextTheme + AppTokens (ThemeExtension)
  models/               classes de dado puras (sem lógica de Firestore)
  services/
    auth_service.dart          login email/senha + Google (web e nativo divergem)
    firestore_service.dart     CRUD + integridade de dinheiro (transactions)
    aggregation_service.dart   funções puras: saldos, resumos mensais
    import_export_service.dart backup/restore em JSON
  providers/providers.dart     providers Riverpod, ligam services -> UI
  features/<nome>/<nome>_page.dart   uma pasta por tela
  widgets/              componentes compartilhados entre telas
```

## Fluxo de dados / gerenciamento de estado

Riverpod (`flutter_riverpod`) é a única fonte de estado — não há um segundo
mecanismo (nem `setState` global, nem um store separado). O caminho dos dados:

1. `FirestoreService` expõe um `Stream` por coleção (`watchCategories`,
   `watchIncomes`, `watchAllocations`, `watchExpenses`), cada um um
   `snapshots()` do Firestore mapeado para o model Dart correspondente.
2. `providers.dart` embrulha cada stream num `StreamProvider`
   (`categoriesProvider`, `incomesProvider`, etc.), condicionado a
   `firestoreServiceProvider` (que é `null` enquanto deslogado —
   `authStateProvider` decide isso).
3. `summaryProvider` (um `Provider` comum, não um stream) combina os quatro
   streams num `AppDb` e chama `aggregation_service.buildSummary(db)` —
   funções **puras** (sem I/O, fáceis de testar isoladamente; ver
   `test/services/aggregation_service_test.dart`) que calculam saldo da
   conta, saldo por caixinha, resumo do mês corrente e histórico mensal.
4. As telas (`features/**`) só fazem `ref.watch(summaryProvider)` /
   `ref.watch(categoriesProvider)` etc. — nunca leem o Firestore diretamente.

Ou seja: **Firestore stream → provider → agregação pura → UI**, sempre nessa
direção. Isso é o equivalente ao antigo endpoint `/api/summary` de uma versão
Next.js anterior do app (removida do repo — commits `d774ffb`/`135d006`);
`aggregation_service.dart` e vários models ainda citam esse histórico em
comentários ("mirrors X in the Next.js app's..."), mantidos porque explicam
*por que* o schema tem o formato que tem, não porque o Next.js app ainda
exista em algum lugar do repo.

## Modelo de dados (Firestore)

Particionado por usuário sob `users/{uid}`:

```
users/{uid}
  categories/{categoryId}
    name: string
    recurring: bool
    createdAt: string (ISO date)
    monthlyBudget: number?     # limite mensal de gasto (caixinha "gastar")
    kind: 'spend' | 'save'?    # null/ausente = legado, tratado como 'spend'
    goalAmount: number?        # meta de poupança (caixinha "guardar")

  incomes/{incomeId}
    date: string (ISO), amount: number, source: string, description: string?

  allocations/{allocationId}
    categoryId: string, amount: number, date: string (ISO)
    transferId: string?        # não-nulo = uma perna de uma transferência
                                # caixinha-a-caixinha (ver abaixo)

  expenses/{expenseId}
    date: string (ISO), amount: number
    categoryId: string?        # null = gasto direto da conta, não de uma caixinha
    description: string?

  meta/account            { balance: number }   # saldo geral da conta (derivado)
  balances/{categoryId}   { balance: number }   # saldo de cada caixinha (derivado)
```

`meta/account` e `balances/{categoryId}` são um **cache derivado**, não fonte
de verdade: não fazem parte do backup JSON e são recalculados a partir do
ledger (as quatro coleções acima) tanto no restore (`FirestoreService.
replaceAll`) quanto pelo script de backfill. Os saldos exibidos na tela
sempre são somados do ledger por `aggregation_service.dart` — mesmo que o
cache divergisse, a UI mostraria a verdade. Eles existem só para que as
Security Rules consigam validar em O(1) (rules não conseguem somar uma
coleção inteira). Ver `docs/BACKEND.md` para o racional completo, os
invariantes garantidos e as limitações conhecidas desse desenho.

`Category.kind`, `monthlyBudget`, `goalAmount` e `Allocation.transferId` são
todos campos opcionais adicionados depois do schema original — um backup
JSON antigo, sem eles, continua importável sem alterações.

## Decisões técnicas e por quê

- **Escritas direto do cliente pro Firestore, sem backend próprio.** Não há
  API intermediária — `FirestoreService` escreve direto, e a integridade de
  dinheiro é garantida por Firestore Security Rules (`firestore.rules`), não
  por um servidor confiável. Essa é a opção "Option B" documentada em
  `docs/BACKEND.md`, escolhida para ficar no tier gratuito (Spark) do
  Firebase — a alternativa com Cloud Functions (`functions/`, tier pago
  Blaze) existe como referência inativa, não implantada.

- **Transferência entre caixinhas = duas `Allocation`s pareadas por
  `transferId`, não uma coleção nova.** Uma perna negativa na caixinha de
  origem, uma perna positiva na de destino, somando zero contra o saldo da
  conta. Isso evita qualquer mudança em `aggregation_service.dart` (que já
  soma allocations por categoria) e mantém o backup JSON compatível (a
  transferência já vive dentro do array `allocations` existente).

- **Propósito da caixinha (`CategoryKind`: `spend` vs. `save`) muda o widget
  de progresso, não o modelo de dinheiro.** Uma caixinha "gastar" mostra
  `CaixinhaBudgetBar` (consumo de um limite mensal, vira alerta ao se
  aproximar/passar do limite). Uma caixinha "guardar" mostra `CaixinhaGoalBar`
  (progresso rumo a uma meta) quando tem `goalAmount`, ou `CaixinhaSavedThisMonth`
  (quanto entrou/saiu líquido no mês) quando não tem meta definida — ver
  `lib/widgets/caixinha_budget_bar.dart`. `kind` nulo (documento anterior a
  este campo) se comporta como `spend`, preservando a única semântica que
  existia antes.

- **Um único breakpoint (720px) reaproveitado em toda a navegação/formulários
  responsivos**, em vez de um valor por tela: `AppShell` (rail lateral vs.
  bottom nav), `showAdaptiveFormSheet` (dialog vs. bottom sheet pros
  formulários de edição/transferência) e `ResponsiveFormRow` (campos lado a
  lado vs. empilhados) todos usam a mesma constante. Um usuário aprende o
  padrão uma vez.

- **`ColorScheme` construído explicitamente (não `ColorScheme.fromSeed`).**
  Ver `docs/DESIGN.md` — os tokens de cor foram calibrados a mão (contraste
  WCAG verificado por par foreground/background), então derivar de uma única
  seed color perderia esse controle.

- **Arredondamento pra centavo (`round2`) em toda soma de dinheiro
  (`aggregation_service.dart`).** Somar muitos valores em ponto flutuante
  acumula erro binário (uma conta que deveria ser exatamente R$0 pode somar
  `-1.7e-13`); toda agregação passa por `round2` antes de chegar a uma
  comparação ou à tela.

- **Login diverge entre Web e nativo.** No Web, Google Sign-In usa
  `signInWithPopup` do próprio Firebase Auth (usa os domínios autorizados do
  projeto, sem configurar OAuth client à parte). No Android/Windows, usa o
  pacote `google_sign_in` com um `serverClientId` fixo (o client OAuth "Web"
  do projeto Firebase) — depende do SHA-1 do app Android estar registrado no
  Firebase. Ver `lib/services/auth_service.dart`.

## Restrições / pendências conhecidas (não inventadas — verificadas no código)

- **Edição de allocation individual existe no código mas não é alcançável
  pela UI.** `EditableAllocation` (`lib/widgets/edit_transaction_sheet.dart`)
  só pode ser construída para uma allocation não-transferência, mas hoje não
  há nenhuma lista de allocations na UI que a invoque — o comentário no
  próprio arquivo já sinaliza que isso existe pronto "pra quando uma lista de
  allocations for adicionada". Não é uma lacuna acidental.

- **`deleteCategory` não trata caixinhas com pernas de transferência.**
  Apagar uma categoria que tem pernas de `transferId` deixaria a perna
  pareada em outra caixinha órfã e desalinharia aquele saldo. Não é
  alcançável pela UI hoje (nenhuma categoria de produção tem pernas de
  transferência) — ver `docs/BACKEND.md`, "Option B residual limitations".

- **`lib/widgets/app_shell.dart` cita `FLUTTER_MIGRATION.md` num comentário**
  ("per §4 of FLUTTER_MIGRATION.md") — esse arquivo não existe mais no repo
  (a migração do Next.js foi concluída e seus docs removidos, ver histórico
  de `git log` em torno de `d774ffb`/`135d006`). TODO: confirmar se esse
  comentário deveria ser atualizado/removido do código, ou se foi deixado
  como referência histórica intencional — não é algo que este documento
  decide sozinho.

## Testes

`test/` espelha a estrutura de `lib/`: `features/*_test.dart` (widget tests
por tela), `services/*_test.dart` (incl. `aggregation_service_test.dart` para
a matemática de dinheiro, que é pura e fácil de testar isoladamente),
`models/db_json_test.dart` (round-trip do backup JSON), `utils/*_test.dart`,
`widgets/*_test.dart`, e `test/rules/rules.test.mjs` (as regras do Firestore
contra o emulador — o único jeito de exercitar os caminhos `getAfter()`/
genesis-teardown, que não rodam a partir do Dart). Ver `docs/DEPLOY.md` para
como isso roda em CI.
