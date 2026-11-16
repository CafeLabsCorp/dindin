# Arquitetura

**[Read in English](ARQUITETURA.md)**

Como o Dindin funciona por dentro. Para o que o app é e como rodar localmente,
ver `README.md`; para a modelagem de integridade de dinheiro (Firestore rules,
saldos denormalizados) ver `docs/BACKEND.pt-br.md`; para a identidade visual ver
`docs/DESIGN.pt-br.md`; para pendências e o que ainda não foi verificado em
aparelho real ver `docs/PENDENCIAS.pt-br.md`.

Descreve a versão **1.2.1+7** (enviada à Google Play em 2026-11-16, aguardando
análise no momento da escrita). Tudo abaixo foi conferido no código e na suíte
de testes (715 testes Flutter passam; o harness das rules tem 128 + 9 testes,
ver "Testes"). O que só foi exercitado em teste ou emulador, nunca em aparelho
real, está marcado como tal.

## Camadas

```
lib/
  main.dart            bootstrap: Firebase.initializeApp, App Check, intl pt_BR,
                       carrega idioma e tema salvos, runApp(SplashGate(DindinApp))
  app.dart              MaterialApp.router: tema (claro/escuro, themeMode vindo
                        do themeModeProvider) + go_router (7 ramos do shell)
  theme/                identidade visual ("Envelope caloroso", ver docs/DESIGN.pt-br.md)
    colors.dart         AppPalette — tokens de cor fixos (claro/escuro)
    theme.dart          ColorScheme + TextTheme + AppTokens (ThemeExtension)
  models/               classes de dados simples (sem lógica de Firestore); também
                        tutorial_progress.dart (TutorialPage/State/Entry + versões)
  services/
    auth_service.dart          login e-mail/senha + Google (Web e nativo divergem),
                               exclusão de conta, hasRecentLogin
    firestore_service.dart     CRUD + integridade de dinheiro (transações), catch-ups,
                               restore/apagar tudo, progresso dos tutoriais
    aggregation_service.dart   funções puras: saldos, resumos mensais
    recurring_schedule.dart    funções puras: quais cobranças de assinatura/
                               parcelamento estão vencidas (usadas pelo catch-up
                               e pela tela, pra os dois nunca divergirem)
    import_export_service.dart backup/restore JSON (+ backup_validation.dart,
                               restore_chunking.dart)
    analytics_service.dart     wrapper do Firebase Analytics (opt-out, sem dado financeiro)
    app_update_service.dart    atualização in-app (flexible) da Google Play
  providers/
    providers.dart       providers Riverpod, ligam services -> UI (inclui os
                         providers do progresso dos tutoriais e o todayProvider)
    locale_provider.dart / theme_provider.dart   escolha de idioma e de tema,
                         persistidas em shared_preferences
  features/<nome>/<nome>_page.dart   uma pasta por tela
                       (assinaturas/ e parcelamentos/ são destinos de topo —
                        ver a decisão de navegação abaixo;
                        settings/ também guarda tutorials_card.dart)
  widgets/              componentes compartilhados: app_shell.dart (navegação),
                        splash_gate.dart (animação de abertura),
                        quick_entry_sheet.dart, guided_empty_state.dart,
                        nav_menu_state.dart, menu_chevron.dart,
                        catch_up_refresh.dart, tutorial/ (motor do onboarding)
```

## Fluxo de dados / gerenciamento de estado

Riverpod (`flutter_riverpod`) é a única fonte de estado — não há um segundo
mecanismo (nem `setState` global, nem um store separado). O caminho dos dados:

1. `FirestoreService` expõe streams por coleção. As três coleções do ledger
   têm dois sabores: **com janela** (`watchIncomes`, `watchAllocations`,
   `watchExpenses`: ordenadas por `date` decrescente, `.limit(2000)`,
   alimentam as listas de Receitas/Gastos/Parcelamentos) e **completos**
   (`watchAllIncomes`, `watchAllAllocations`, `watchAllExpenses`: sem limite,
   alimentam só o resumo do Dashboard). Categorias, assinaturas e parcelamentos
   têm teto de 500 docs. Cada um é um `snapshots()` do Firestore mapeado para
   o model Dart correspondente.
2. `providers.dart` embrulha cada stream num `StreamProvider`
   (`categoriesProvider`, `incomesProvider`, `allIncomesProvider`, etc.),
   condicionado a `firestoreServiceProvider` (que é `null` enquanto deslogado
   — `authStateProvider` decide isso).
3. `summaryProvider` (um `Provider` comum, não um stream) combina categorias +
   os três streams **completos** do ledger num `AppDb` e chama `aggregation_service.buildSummary(db)` —
   funções **puras** (sem I/O, fáceis de testar isoladamente; ver
   `test/services/aggregation_service_test.dart`) que calculam saldo da
   conta, saldo por caixinha, resumo do mês corrente e histórico mensal.
4. As telas (`features/**`) só fazem `ref.watch(summaryProvider)` /
   `ref.watch(categoriesProvider)` etc. — nunca leem o Firestore diretamente.

Ou seja: **Firestore stream → provider → agregação pura → UI**, sempre nessa
direção. O saldo do Dashboard, portanto, é **re-somado do ledger inteiro a cada
mudança**, não lido dos docs de saldo denormalizados (esses existem só para as
rules, ver `docs/BACKEND.pt-br.md`, "O saldo do Dashboard re-soma o ledger"):
correto por construção, ao custo de ler todo o histórico da conta a cada
sessão. Isso é o equivalente ao antigo endpoint `/api/summary` de uma versão
Next.js anterior do app (removida do repo — commits `d774ffb`/`135d006`);
`aggregation_service.dart` e vários models ainda citam esse histórico em
comentários ("mirrors X in the Next.js app's..."), mantidos porque explicam
*por que* o schema tem o formato que tem, não porque o Next.js app ainda
exista em algum lugar do repo.

## Rastros ponta a ponta

Três operações, rastreadas por toda camada que atravessam, nomeando os
arquivos e funções reais em cada salto. Escolhidas porque disparam de formas
genuinamente diferentes — uma a partir de um toque explícito, outra só de
abrir o app, e outra da primeira visita a uma página (Rastro C, que só lê e
escreve estado de interface) — mas as duas primeiras convergem no mesmíssimo
mecanismo de leitura/atualização assim que a escrita acontece, o que vale a pena ver escrito uma vez em vez de
presumido como generalizável.

### Rastro A — criar um gasto (de caixinha), escrita iniciada pelo usuário

1. **Toque.** Na tela de Gastos (`lib/features/gastos/gastos_page.dart`), o
   usuário escolhe uma caixinha (ou "Conta"), digita um valor e toca em
   enviar — `_GastosPageState._submit()`.
2. **Pré-checagem do lado do cliente.** `_submit` primeiro chama
   `_blockedByFrozenDebt(categories, availableBalance)` pra desabilitar o
   botão cedo com uma mensagem amigável se a caixinha escolhida é uma
   dívida congelada que não pode receber mais gasto — um atalho de UX, não
   o guard de verdade.
3. **Provider → serviço.** Ele lê `ref.read(firestoreServiceProvider)`
   (`null` enquanto deslogado) e chama
   `FirestoreService.createExpense(date:, amount:, categoryId:, description:)`
   (`lib/services/firestore_service.dart`).
4. **Transação.** `createExpense` roda um `runTransaction` do Firestore: lê
   o doc de saldo alvo (`users/{uid}/meta/account` se `categoryId` é nulo,
   senão `users/{uid}/balances/{categoryId}`), lança `StateError` do lado
   do cliente se o valor estourasse esse saldo (espelhando `_catDeltaOk`),
   e então escreve TANTO o novo doc `users/{uid}/expenses/{id}` QUANTO o
   doc de saldo decrementado, na mesma transação.
5. **Validação do servidor.** A rule `allow create` de `expenses` em
   `firestore.rules` rechecka `validExpense(...)` e, via `getAfter()`, que
   o doc de saldo vinculado moveu por exatamente o valor do gasto e ficou
   dentro do seu piso (`catDeltaOk`) — ver `docs/BACKEND.pt-br.md`, "Option
   B — o que está implementado". Essa é a fronteira de segurança de
   verdade; a checagem do passo 4 é só uma mensagem de erro mais rápida pro
   cliente honesto.
6. **Caminho de erro.** Qualquer `StateError` do passo 4, ou uma
   `FirebaseException` de `permission-denied` do passo 5, é capturada no
   `catch` do `_submit` e convertida numa string localizada por
   `friendlyErrorMessage` (`lib/utils/errors.dart`), mostrada inline sob o
   formulário. Nada é escrito em caso de falha.
7. **O lado da leitura reage automaticamente.** O commit dispara os
   listeners de `users/{uid}/expenses` e `users/{uid}/balances/{categoryId}`
   (ou `meta/account`) nos quais `FirestoreService.watchExpenses()` (e os
   streams de categories/allocations/incomes já abertos) estão inscritos. O
   `StreamProvider` `expensesProvider` de `providers.dart` reemite.
8. **Agregação.** `summaryProvider` (`providers.dart`), observando as
   categorias e os três streams completos (sem janela) do ledger, recombina em um `AppDb` e chama
   `aggregation_service.buildSummary(db)` — pura, sem I/O — pra recalcular
   o saldo da conta, o saldo da caixinha e o resumo do mês corrente.
9. **A UI atualiza.** Tanto `GastosPage` (o gasto agora na lista, o saldo
   restante da caixinha) quanto `DashboardPage`
   (`lib/features/dashboard/dashboard_page.dart`, `ref.watch(summaryProvider)`)
   reconstroem com os novos números — sem nenhuma chamada explícita de
   "atualizar"; `ref.watch` é o que faz a emissão do stream do passo 7
   alcançar as duas telas.

### Rastro B — cobrança automática de assinatura, escrita disparada pela sessão (não um toque)

Ponto de partida genuinamente diferente: nada aqui é disparado por um toque
do usuário nesta tela — roda uma vez sempre que uma sessão logada começa, a
partir de qualquer tela em que isso aconteça.

1. **Abrir o app, não um toque.** `AppShell` (`lib/widgets/app_shell.dart`)
   chama `ref.watch(recurringChargesCatchUpProvider)` a cada build — como um
   `Provider` só reroda o corpo quando as próprias dependências mudam, isso
   dispara exatamente uma vez por login, independente de qual tela o
   `AppShell` estiver mostrando.
2. **Provider → serviço.** `recurringChargesCatchUpProvider`
   (`lib/providers/providers.dart`) lê `firestoreServiceProvider` e chama
   `FirestoreService.catchUpSubscriptions()` e depois
   `.catchUpInstallmentPurchases()`, nessa ordem.
3. **Matemática de datas, fora do serviço.** `catchUpSubscriptions` pergunta
   a `lib/services/recurring_schedule.dart` quais datas de vencimento cada
   assinatura perdeu desde `lastChargedDate` — funções puras, as mesmas que
   a tela de Gastos usa pra mostrar o que ainda está pendente, pra que as
   duas nunca possam discordar (ver `docs/BACKEND.pt-br.md`, "Cobrança
   pendente é mostrada, não escondida").
4. **Uma transação por data de vencimento.** Pra cada mês perdido, do mais
   antigo pro mais novo, `_chargePendingDueDates` roda uma transação que
   RELÊ o doc da assinatura (proteção contra uma segunda sessão concorrente
   cobrando duas vezes — ver `docs/BACKEND.pt-br.md`, "Duas sessões ao
   mesmo tempo não cobram duas vezes"), e então escreve um novo doc
   `users/{uid}/expenses/{id}` (marcado `sourceType: 'subscription'`,
   `sourceId`) mais a mesma atualização de conta/`balances/{categoryId}` do
   passo 4 do Rastro A — o mesmíssimo portão de saldo, já que uma cobrança
   gerada precisa ser permitida se e somente se o mesmo gasto digitado à
   mão seria. Uma ocorrência que não cabe no saldo é pulada, não lançada —
   tentada de novo na próxima sessão.
5. **Validação do servidor.** Mesmo caminho de `firestore.rules` do passo 5
   do Rastro A — não existe rule separada pra um gasto gerado;
   `sourceType`/`sourceId` são checados adicionalmente como imutáveis uma
   vez definidos (`sameExpenseSource`).
6. **O lado da leitura reage — mesmo mecanismo do Rastro A.** Cada cobrança
   commitada é só mais uma escrita em `users/{uid}/expenses` e num doc de
   saldo, então alcança `watchExpenses()` → `expensesProvider` →
   `summaryProvider` → `DashboardPage`/`GastosPage` exatamente como no
   Rastro A, passos 7-9 — sem tratamento especial pra uma cobrança gerada
   em nenhum lugar do caminho de leitura.
7. **Uma segunda reação de UI, independente — não pelo Firestore.** De
   volta no `AppShell`, `ref.listen<AsyncValue<RecurringChargeReport>>(...)`
   (não `ref.watch`) dispara assim que o próprio `FutureProvider` resolve, e
   mostra um `SnackBar` nomeando o que acabou de ser cobrado. Essa é a
   única parte do rastro que NÃO passa por um stream do Firestore — o app
   avisa o usuário proativamente, a partir do próprio resultado do
   provider, porque essas cobranças acontecem sem nenhuma interação e uma
   linha aparecendo silenciosamente numa lista que o usuário pode nem abrir
   seria, do contrário, o único rastro disso.
8. **Falha é visível, não engolida.** Se o próprio passo 4 lançar erro (não
   uma data que não cabe no saldo, uma falha de verdade),
   `recurringChargesCatchUpProvider` loga e relança, virando um
   `AsyncError` no provider em vez de ser silenciosamente engolido — a tela
   de Gastos distingue "catch-up ainda não rodou" de "catch-up rodou e isso
   genuinamente não cabe" usando esse estado de erro (ver
   `docs/BACKEND.pt-br.md`, "Cobrança pendente é mostrada, não escondida").

### Rastro C — primeira visita a uma página: o tutorial do onboarding

Um terceiro tipo de início: ninguém toca em nada e o usuário não escreve nada,
mas um documento do Firestore é lido e, depois, escrito. Rastreado para o
Dashboard em tela estreita (a única página com o passo "guiado pela ação").

1. **A página está pronta.** `DashboardPage.build`
   (`lib/features/dashboard/dashboard_page.dart`) mostra um spinner até
   `summaryProvider` e `categoriesProvider` terem dados e então embrulha o
   conteúdo em `TutorialHost(page: TutorialPage.dashboard, steps: _tutorialSteps, ...)`
   (`lib/widgets/tutorial/tutorial_host.dart`). O host só é construído depois
   que os dados chegam, então o tutorial nunca começa sobre um spinner ou erro.
2. **Já foi visto?** `TutorialHost.build` observa
   `tutorialSeenProvider(page)` (`providers.dart`). Esse provider é `null`
   até `tutorialProgressProvider` carregar (um `StreamProvider` sobre
   `FirestoreService.watchTutorialProgress()`, ou seja, os snapshots de
   `users/{uid}/meta/tutorials`, lidos por `parseTutorialProgress`); `true` se
   a página está em `tutorialSessionSeenProvider` (o que terminou NESTA sessão)
   ou se a versão salva cobre `tutorialVersions[page]` (`TutorialEntry.covers`);
   `false` caso contrário. `null` significa "ainda não sei" e não inicia nada —
   senão o tutorial piscaria antes de o estado salvo chegar.
3. **Esperar um momento calmo.** Com `false`, o host agenda `_tryStart` após
   400 ms. `_calm` exige: esta aba é a visível (`TickerMode`), nenhum diálogo ou
   sheet por cima (`ModalRoute.isCurrent`), o menu de páginas fechado
   (`navMenuOpen`, um `ValueNotifier` ligado por `AppShell._openMenu`, porque
   esse menu é um diálogo no navigator RAIZ e a rota da própria página não o
   enxerga) e o teclado fechado. Se não estiver calmo: tenta de novo a cada
   600 ms, no máximo 30 vezes, e desiste em silêncio. Quando o menu fecha, o
   listener do host recomeça as tentativas do zero.
4. **Mostrar.** `showTutorial` (`tutorial.dart`) empurra uma `PopupRoute` no
   navigator raiz. `_TutorialScreen` acha o widget de cada passo pela
   `GlobalKey` (`TutorialStep.target`), rola até ele, pinta o véu com recorte e
   o balão (abaixo, acima, ou no rodapé sem seta) e mede de novo em rotação/
   redimensionamento/teclado. O passo 1 do Dashboard mira o título da página
   (estreita) ou a barra lateral (larga, via `AppNavigation.railKey`); em tela
   estreita seu `onTargetTap` é o `openMenu` de verdade, então tocar no título
   iluminado abre o menu real e encerra o tutorial como concluído.
5. **Desfecho.** Próximo/Concluir → `TutorialResult.done`; Pular, Esc ou o
   voltar do sistema → `skipped`; um alvo que não está montado (lista
   construída sob demanda, bem abaixo da dobra) → `unavailable`.
6. **Gravar.** `done`/`skipped` chamam `markTutorialEnded` (`providers.dart`),
   que primeiro põe a página em `tutorialSessionSeenProvider` (pra ela não voltar
   nesta sessão mesmo se a escrita falhar) e depois
   `FirestoreService.setTutorialProgress` faz
   `meta/tutorials.set({pagina: {state, v}}, merge: true)`. `unavailable` não
   grava nada, então tenta de novo na próxima abertura. Escrita que falha só vai
   pro log (`dindin.tutorials`).
7. **Validação do servidor.** A rule `meta/{docId}` de `firestore.rules` só
   aceita `tutorials` por `validTutorials`: lista fechada dos sete ids de página,
   cada um `{state: 'done'|'skipped', v: int 1..1000}` — ver `docs/BACKEND.pt-br.md`.
8. **Os outros leitores reagem.** O listener de `meta/tutorials` emite nos outros
   aparelhos e em Ajustes, então `tutorialSeenProvider` vira `true` lá sem
   nenhuma chamada extra.
9. **Rever.** Ajustes → Tutoriais (`lib/features/settings/tutorials_card.dart`)
   lê os mesmos providers. "Rever" chama `resetTutorial` (tira a página do
   conjunto da sessão e grava `FieldValue.delete()` naquela chave) e
   `context.go(rota)`; o host da página vê `seen == false` e roda a partir do
   passo 2. "Rever todos" chama `resetAllTutorials` (`meta/tutorials.delete()`),
   com um snackbar "Desfazer" que chama `restoreTutorials` (regrava cada
   entrada anterior, com a versão original).

Situação da verificação: tudo isso é coberto por widget tests e por 6 testes das
rules no emulador; **não foi visto em aparelho real** (ver `docs/PENDENCIAS.pt-br.md`).

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
    allowNegative: bool?       # só relevante p/ kind == 'spend'; permite a
                                # caixinha ficar com saldo negativo ("dívida")

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
    sourceType: string?        # 'subscription' | 'installment' — ausente = digitado à mão
    sourceId: string?          # id do doc que gerou esse gasto; anda junto com
                                # sourceType (os dois presentes ou os dois ausentes)

  subscriptions/{subscriptionId}
    name: string, amount: number, dueDay: int (1-31)
    createdAt: string (ISO date)
    lastChargedDate: string?   # data ISO da última cobrança já virada gasto
                                # por catchUpSubscriptions
    categoryId: string?        # caixinha de onde a cobrança sai; ausente = conta
    autoChargeEnabled: bool?   # só gravado quando false; ausente = true. Com false,
                                # o catch-up pula e a cobrança é lançada à mão
                                # ("Cobrar agora", chargeSubscriptionNow)

  installmentPurchases/{purchaseId}
    name: string, totalAmount: number, installments: int (2-36)
    purchaseDate: string (ISO date)     # só informativo
    firstChargeDate: string (ISO date)  # âncora de toda ocorrência mensal
    createdAt: string (ISO date)
    chargedInstallments: int  # 0..installments; quantas já viraram gasto
                                # por catchUpInstallmentPurchases
    categoryId: string?        # caixinha de onde as parcelas saem; ausente = conta
    amortizedAmount: number?   # pago adiantado, além das parcelas agendadas;
                                # ausente = 0. Encurta o PRAZO, não a parcela
    dueDayOverride: int?       # dia (1-31) em que as parcelas RESTANTES vencem;
                                # ausente = o dia de firstChargeDate

  meta/account            { balance: number }   # saldo geral da conta (derivado)
  balances/{categoryId}   { balance: number }   # saldo de cada caixinha (derivado)
  meta/settings           { analyticsOptOut: bool }   # Ajustes -> Privacidade
  meta/tutorials          { <pagina>: { state: 'done'|'skipped', v: int } }
                          # <pagina> em dashboard|receitas|gastos|assinaturas|
                          # parcelamentos|categorias|ajustes. Estado de UI, não dinheiro

accountDeletionLog/{autoId}   # coleção de TOPO, fora de users/{uid}; só create
  { deletedAt: serverTimestamp, origin: 'self-service'|'admin-sweep' }
```

`Income` e `Expense` também têm um `createdAt` opcional (timestamp ISO), usado
só pra desempatar linhas da mesma `date` (`_sortByDateThenCreatedAt`).
`meta/settings` e `meta/tutorials` também não entram no backup JSON (são estado
do app por conta) e `deleteAllUserData` apaga os dois junto com os docs de saldo.

`meta/account` e `balances/{categoryId}` são um **cache derivado**, não fonte
de verdade: não fazem parte do backup JSON e são recalculados a partir do
ledger (as seis coleções acima) tanto no restore (`FirestoreService.
replaceAll`) quanto pelo script de backfill. Os saldos exibidos na tela
sempre são somados do ledger por `aggregation_service.dart` — mesmo que o
cache divergisse, a UI mostraria a verdade. Eles existem só para que as
Security Rules consigam validar em O(1) (rules não conseguem somar uma
coleção inteira). Ver `docs/BACKEND.pt-br.md` para o racional completo, os
invariantes garantidos e as limitações conhecidas desse desenho.

`Category.kind`, `monthlyBudget`, `goalAmount`, `allowNegative` e
`Allocation.transferId` são todos campos opcionais adicionados depois do
schema original — um backup JSON antigo, sem eles, continua importável sem
alterações. `subscriptions` é uma coleção inteira nova adicionada do mesmo
jeito — um backup antigo sem a chave `subscriptions` importa como lista
vazia. `installmentPurchases` é uma segunda adição assim, logo em seguida.
`Expense.sourceType`/`sourceId` seguem a mesma regra: um gasto exportado
antes deles importa como gasto manual, sem os campos serem inventados na
volta. `categoryId` (nas duas coleções novas) e `amortizedAmount` são as
adições mais recentes, com o mesmo desenho: ausentes valem "sai da conta" e
"nada adiantado", que é exatamente como os docs antigos já se comportavam.

## Decisões técnicas e por quê

- **Escritas direto do cliente pro Firestore, sem backend próprio.** Não há
  API intermediária — `FirestoreService` escreve direto, e a integridade de
  dinheiro é garantida por Firestore Security Rules (`firestore.rules`), não
  por um servidor confiável. Essa é a opção "Option B" documentada em
  `docs/BACKEND.pt-br.md`, escolhida para ficar no tier gratuito (Spark) do
  Firebase — a alternativa com Cloud Functions (`functions/`, tier pago
  Blaze) existe como referência inativa, não implantada.

- **Uma assinatura só cobra quando o app é aberto, nunca num agendamento de
  servidor.** `FirestoreService.catchUpSubscriptions` roda uma vez por sessão
  logada e recupera toda data de cobrança que uma assinatura perdeu, do mais
  antigo pro mais novo, direto da conta — mas nada roda com o app fechado. A
  alternativa (Cloud Scheduler + Cloud Function cobrando exatamente no dia
  certo) exigiria o mesmo plano pago Blaze recusado pra Option A acima, pelo
  mesmo motivo. Ver `docs/BACKEND.pt-br.md`, "Assinaturas (gastos
  recorrentes)".

- **Um parcelamento reaproveita exatamente o mesmo mecanismo de catch-up de
  uma assinatura, só que limitado.** `catchUpInstallmentPurchases` compartilha
  o clamp de mês do `dueDateFor` com `catchUpSubscriptions` e segue o mesmo
  modelo disparado-pelo-cliente-ao-abrir-o-app — a única diferença estrutural
  é que ele para quando `chargedInstallments` chega em `installments`, em vez
  de rodar pra sempre. O resto do arredondamento ao dividir `totalAmount` em
  parcelas iguais sempre cai na ÚLTIMA parcela (igual fatura de cartão de
  verdade), calculado uma vez por parcelamento via `installmentAmounts`,
  nunca recalculado por cobrança (pra nunca divergir entre execuções do
  catch-up).

- **Toda a matemática de datas do catch-up mora fora do `FirestoreService`,
  em `lib/services/recurring_schedule.dart`.** São funções puras (sem
  Firestore, sem I/O), como `aggregation_service.dart`. Motivo: existem dois
  consumidores da mesma resposta e eles não podem divergir — o catch-up, que
  transforma cada ocorrência vencida em `Expense`, e a tela de Gastos, que
  mostra quantas ocorrências continuam PENDENTES. Se a tela recalculasse
  "pendente" com uma cópia própria dessa conta, o aviso poderia afirmar algo
  que o catch-up não faria.

- **O catch-up relê o doc DENTRO da transação antes de cobrar.** Sem isso,
  duas sessões simultâneas (celular + web, ou duas abas) cobram a mesma
  ocorrência duas vezes: o `get()` que lista as assinaturas acontece fora da
  transação, e um retry do Firestore só reexecuta o corpo com os dados que a
  própria transação leu — o objeto capturado de fora continua velho, então o
  retry rebilla o mês que o outro dispositivo acabou de billar. Reler ali
  dentro resolve os dois lados: põe o doc no read set (a corrida vira
  conflito detectado) e o retry enxerga `lastChargedDate`/
  `chargedInstallments` já atualizados e desiste. O resultado da tentativa é
  devolvido como `_ChargeOutcome` em vez de exceção, pra que "já foi cobrado"
  e "não coube no saldo" sejam transações no-op em vez de controle de fluxo
  por `StateError` — o mesmo tipo que as validações de verdade usam.

- **Uma cobrança que não coube no saldo é visível na tela, não silenciosa.**
  O catch-up para naquela ocorrência e tenta de novo depois (nunca deixa a
  conta negativa), mas até isso existir, uma assinatura que não cobrava por
  meses era indistinguível de uma paga. A tela de Gastos conta as pendências
  com as funções de `recurring_schedule.dart` e mostra por linha e por card —
  e só depois do catch-up ter terminado, porque antes disso "pendente" ainda
  não significa nada (ver `recurringChargesCatchUpProvider`, que agora
  propaga a falha como `AsyncError` em vez de engolir).

- **Assinaturas e parcelamentos são destinos de topo, e no mobile TODA a
  navegação mora num menu só.** Eram dois cards no fim da `GastosPage`,
  DEPOIS da lista de gastos — que é ilimitada, então na prática eram
  inalcançáveis.

  Promovê-los levou a sete destinos, e sete não cabem numa `NavigationBar`
  (cinco é o teto: passando disso os rótulos truncam e os alvos encolhem).
  Duas tentativas antes da atual, ambas registradas porque explicam a forma
  final:

  1. Barra com cinco + logo num sexto slot. Seis slots deram ~63px cada e
     "Assinaturas" quebrou no meio da palavra num celular real.
  2. Barra com cinco + logo na app bar. Coube, mas criava uma linha
     arbitrária entre telas "do dia a dia" e "de gerenciamento", e o usuário
     tinha que aprender de que lado cada uma estava.

  3. Sem barra, com o menu na app bar. Resolvia a costura, mas a app bar
     mostrava o nome da tela e o corpo da página mostrava o MESMO nome uma
     linha abaixo — "Dashboard" duas vezes.

  A forma atual não tem nem costura nem repetição: em tela estreita não
  existe barra inferior NEM app bar. O próprio título da página (`PageHeader`)
  ganha um chevron e abre um menu com os SETE destinos, que desce do topo
  sobre um fundo escurecido — a direção aponta de volta pro que você tocou.
  O que você lê é o que você toca, e o nome da tela aparece uma vez só. Como bônus, acaba de vez o problema de rótulo — uma lista
  vertical dá largura cheia pra cada nome, então nada trunca nem precisa de
  abreviação ("Assinaturas" e "Parcelamentos" voltaram por inteiro). O custo é
  honesto: navegar vira dois toques.

  O `AppShell` entrega o menu às telas por um `InheritedWidget`
  (`AppNavigation`), pra que o título de cada página seja o gatilho sem que
  cada página precise saber como a navegação funciona. Em tela larga esse
  callback é nulo e o mesmo `PageHeader` vira um título comum.

  Uma roleta girando a partir do logo foi cogitada e recusada: nada nela diz
  que gira, é estranha no mouse (a plataforma no ar é a web), e precisaria de
  bastante trabalho pra ser alcançável por leitor de tela. Uma lista numa
  folha é as três coisas de graça, e ainda abre do logo.

  Em tela larga nada disso se aplica: o `NavigationRail` é uma lista vertical
  e comporta os sete. O topo de Gastos manteve o número de **quanto do mês já
  está comprometido** (`committedThisMonth`), agora só como informação.

- **A cobrança pode sair da conta ou de uma caixinha (`categoryId`).**
  `_readChargeSource` espelha exatamente os dois ramos do `createExpense`,
  inclusive o `allowNegative` via `_catDeltaOk`: uma cobrança gerada só é
  aceita se o mesmo gasto digitado à mão também fosse. Só caixinha do tipo
  `spend` é oferecida — uma `save` é meta de poupança, e drená-la todo mês
  contraria o motivo dela existir (além de não poder ficar negativa, então
  falharia na hora de cobrar). Se a caixinha for apagada, a cobrança fica
  pendente com aviso e **nunca** cai de volta pra conta em silêncio: tirar
  dinheiro de um lugar que o usuário não escolheu seria pior que não cobrar.

- **Pagar adiantado encurta o PRAZO, não a parcela (`amortizedAmount`).**
  Pagar mais num mês, ou quitar de uma vez, abate o saldo devedor e o
  parcelamento simplesmente acaba antes — a parcela continua do mesmo
  tamanho. O valor pago adiantado é um total próprio em vez de reescrever
  `totalAmount`/`installments`, que são imutáveis nas rules de propósito
  (são contra eles que `chargedInstallments` é contado; reescrevê-los
  dessincronizaria o progresso do que foi cobrado de verdade). O saldo
  devedor — não o contador de parcelas — é o que diz se acabou, e a última
  cobrança é limitada ao que resta pra nunca cobrar além da dívida.

- **Um gasto gerado sabe de onde veio (`sourceType`/`sourceId`).** Mesma
  ideia do `Allocation.transferId`: parear as linhas por um id em vez de
  criar uma coleção nova. Sem isso, um gasto gerado por assinatura é
  indistinguível de um manual com a mesma descrição — o app não consegue
  dizer quanto uma assinatura já custou, nem perceber que o usuário apagou
  uma cobrança na mão. Os dois campos são imutáveis nas rules depois de
  criados: uma edição não pode plantar, remover nem repontar o vínculo.

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

- **`recurring` (o checkbox "Recorrente (repete todo mês)") era só uma
  etiqueta visual até virar, também, o interruptor que decide o que
  `goalAmount` significa numa caixinha `save`.** Sem meta ou com `recurring:
  false`, nada muda — meta é alvo acumulado (comportamento original), e sem
  meta a caixinha continua mostrando `CaixinhaSavedThisMonth`. Com meta E
  `recurring: true` (`Category.hasMonthlyGoal`), a mesma `goalAmount` passa a
  ser lida como alvo MENSAL: a barra (`CaixinhaGoalBar` com `monthly: true`)
  passa a usar `savedThisMonthByCategory` em vez do saldo total da caixinha.

  Não existe reset explícito — nenhum job, nenhum campo "zerado em X" gravado
  no Firestore. `savedThisMonthByCategory` já era uma consulta ao vivo
  filtrada por mês (`monthKey(date) == currentMonthKey()`), então o dia 1
  "zera" sozinho pelo simples fato de não haver alocação nenhuma datada no
  mês novo ainda — mesmo que o usuário não abra o app naquele dia. O saldo
  total da caixinha (`categoryBalances`, o número grande no topo da linha)
  nunca participa dessa conta e continua acumulando por baixo, intocado.

  Dia de reset é sempre o dia 1 do calendário — não é configurável por
  caixinha (ao contrário do `dueDay` de uma assinatura). Decisão deliberada:
  o pedido original considerava um dia por caixinha, mas o ganho não parecia
  justificar o esforço (schema novo, migração de `savedThisMonthByCategory`
  pra uma janela de 30 dias ancorada num dia arbitrário em vez do mês
  calendário) frente a "dia 1 fixo" já resolver o caso de uso real.

- **`allowNegative` afrouxa de propósito, e só num escopo estreito, um
  invariante que antes era absoluto ("nenhum saldo fica negativo").** Uma
  caixinha `spend` pode ligar o toggle "Permitir saldo negativo" e passar a
  aceitar gastos que deixam seu saldo negativo (uma "dívida"). A quitação é a
  aritmética normal do saldo — a próxima alocação/transferência que entra
  nessa caixinha simplesmente soma e abate a dívida, sem uma ação separada de
  "quitar". Uma caixinha `save` nunca fica negativa, e a conta geral
  (`meta/account`) também não — o afrouxamento é só para `balances/{catId}`
  de uma caixinha `spend` com o flag ligado. Ver `docs/BACKEND.pt-br.md`,
  "allowNegative (dívida por caixinha)", para o mecanismo completo (rules +
  client), o restore de backup com dívida congelada (**F1**, corrigido) e a
  pendência conhecida: não há hoje guard no app contra converter uma
  caixinha `spend` negativa em `save`, ou apagá-la, com a dívida ainda aberta.

- **Um único breakpoint (720px) reaproveitado em toda a navegação/formulários
  responsivos**, em vez de um valor por tela: `AppShell` (rail lateral vs.
  menu único), `showAdaptiveFormSheet` (dialog vs. bottom sheet pros
  formulários de edição/transferência) e `ResponsiveFormRow` (campos lado a
  lado vs. empilhados) todos usam a mesma constante. Um usuário aprende o
  padrão uma vez.

- **`ColorScheme` construído explicitamente (não `ColorScheme.fromSeed`).**
  Ver `docs/DESIGN.pt-br.md` — os tokens de cor foram calibrados a mão (contraste
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

- **O onboarding é um motor pequeno mais hosts por página, não um pacote.**
  `lib/widgets/tutorial/tutorial.dart` (`showTutorial`, `TutorialStep`,
  `TutorialResult`) desenha um passo por vez sobre a tela real: véu com recorte,
  anel e balão no formato do cartão de passo do manual de marca; movimento
  reduzido e anúncio para leitor de tela ficam na própria rota.
  `tutorial_host.dart` decide QUANDO começar (ver Rastro C). Sete páginas têm
  tutorial (Dashboard 4 passos, Ajustes 2, as outras cinco 3 cada). O progresso
  fica em `meta/tutorials`, então acompanha a conta entre aparelhos; cada página
  tem um número de versão (`tutorialVersions` em
  `lib/models/tutorial_progress.dart`) — subir o número reexibe só aquele
  tutorial para quem salvou uma versão menor. Os ids de página são uma lista
  fechada que precisa bater com `validTutorials` em `firestore.rules`. Limite
  conhecido: o alvo de um passo precisa estar montado; um widget numa lista
  construída sob demanda, bem abaixo da dobra, encerra o tutorial como
  `unavailable` (não gravado). O racional do desenho e as alternativas
  rejeitadas (direção "Etiqueta") estão em `docs/onboarding-design.md`.

- **Estados vazios e o cartão "Primeiros passos" do Dashboard ensinam a próxima
  ação.** `GuidedEmptyState` (`lib/widgets/guided_empty_state.dart`: ilustração,
  título, texto, um botão com verbo) substitui o texto vazio simples em
  Receitas, Gastos, Assinaturas, Parcelamentos e Categorias; lista vazia só por
  causa do filtro de datas continua com o texto simples e "Limpar filtro". O
  `_FirstStepsCard` do Dashboard (criar caixinha, lançar receita, alocar) some
  quando os três são verdade (`categories.isNotEmpty && hasIncome &&
  hasAllocation`; transferência não conta como alocação). Ajustes → Tutoriais
  mostra o selo de cera terracota (`assets/illustrations/dindin-selo.svg`) e
  recolhe a lista quando os sete foram vistos.

- **A navegação ficou descobrível sem mudar de forma.** O chevron do título é um
  círculo tonal (`MenuChevronChip`, área de toque de 48 dp), cada linha do menu
  tem uma descrição de uma linha (strings `navXxxDescription`) e o Dashboard tem
  os botões "Lançar receita"/"Lançar gasto". Eles abrem `showQuickEntrySheet`
  (`lib/widgets/quick_entry_sheet.dart`): o mesmo formulário de Receitas/Gastos
  numa folha (diálogo em tela larga), salvando pelo mesmo
  `createIncome`/`createExpense` (vale o Rastro A) e fechando sem sair do
  Dashboard. O mecanismo anterior ("abrir a página com o cursor em Valor",
  `focus_request`) foi removido.

- **Tema: Sistema / Claro / Escuro, escolhido em Ajustes.** `themeModeProvider`
  (`lib/providers/theme_provider.dart`) tem o mesmo formato do `localeProvider`:
  `main()` carrega o valor salvo (`shared_preferences`, chave `themeMode`) antes
  do `runApp` e sobrescreve o provider, `app.dart` passa para
  `MaterialApp.themeMode`, Ajustes grava com `setThemePreference` ("Sistema"
  apaga a chave). Falha de armazenamento só custa a persistência. O fundo escuro
  oficial é `#16130F` (`AppPalette.darkBackground`), cartões `#201C17`; os tokens
  estão em `lib/theme/colors.dart` e descritos em `docs/DESIGN.pt-br.md`. O tema
  fica guardado no aparelho, não no Firestore.

- **Animação de abertura (`SplashGate`, `lib/widgets/splash_gate.dart`).**
  Envolve o `DindinApp` no `main()` (então widget tests do app nunca a veem).
  Por 1,5 s um overlay toca por cima do app, que já está montando por baixo: o
  saco da logo no tamanho normal, três moedas caem e o balançam, depois ele se
  aproxima do espectador enquanto some. O fundo segue o tema escolhido (em
  "Sistema", o brilho do aparelho, lido de `platformDispatcher`); pulada por
  inteiro quando o sistema pede movimento reduzido. Absorve toques e fica fora
  do leitor de tela. Limite: antes do primeiro quadro do Flutter a janela
  nativa ainda é branca/preta, então pode haver um flash. Verificada em testes
  (715 passam) e por revisão de vídeo; **não em aparelho real**.

- **Escritas que não precisam de transação não esperam o servidor offline
  (`FirestoreService.ackOrQueue`).** O future de uma escrita comum do Firestore
  só completa no ack do servidor, então offline o botão de salvar ficaria
  girando até a conexão voltar. `ackOrQueue` espera até 4 s (`writeAckWait`) e
  depois trata a escrita como enfileirada (o Firestore a mantém na fila local e
  envia na volta). Falha real dentro da janela (negação das rules) ainda é
  lançada; depois dela não dá mais pra reportar. Usado por `createCategory`,
  `updateCategory`, `createSubscription`, `deleteSubscription`,
  `setSubscriptionAutoCharge`, `createInstallmentPurchase` e
  `deleteInstallmentPurchase`. Transações (escritas de dinheiro) não mudaram:
  falham na hora offline.

- **`deleteCategory` recusa três situações antes de tocar em qualquer coisa.**
  Caixinha que participou de transferência (a perna pareada ficaria órfã e
  `meta/account` subiria acima do ledger); saldo negativo (a dívida precisa ser
  quitada antes, espelha `catDebtFree`); e cascata maior que 495 registros
  (`FirestoreService.maxCascadeDocs`: uma transação comporta no máximo 500
  escritas e não dá pra fatiar porque as rules a leem como um commit só). A
  tela de Categorias também desabilita o botão de remover de antemão nas duas
  primeiras, com explicação.

- **Excluir a conta confere login recente ANTES de apagar os dados.**
  `SettingsPage` chama `AuthService.hasRecentLogin()` (lê o `auth_time` do ID
  token, margem de 4 minutos sob a janela de ~5 min do Firebase) primeiro; sessão
  antiga mostra "saia e entre de novo" e nada é apagado. Antes, os dados do
  Firestore eram apagados primeiro e o `user.delete()` falhava depois, deixando
  uma conta viva e vazia. Depois da checagem: `deleteAllUserData()` (docs de
  saldo + settings + tutorials + uma entrada anônima de `accountDeletionLog` no
  primeiro commit, depois o ledger) e por último `AuthService.deleteAccount()`.

- **Edições somam o delta num passo só, como as rules.** `updateIncome`,
  `updateAllocation` e `updateExpense` calculam `saldo + (novo - velho)`, nunca
  `(saldo - velho) + novo`: as rules comparam com `==` exato e as duas formas
  diferem no último bit para certos valores, o que causava
  `permission-denied` ocasional numa edição legítima (confirmado no emulador;
  9 testes das rules fixam a paridade).

- **"Este mês" é o mês local do aparelho.** `currentMonthKey()`
  (`aggregation_service.dart`) usa hora local, o mesmo relógio das datas do
  ledger; em UTC o Dashboard virava pro mês seguinte, vazio, às 21h do último
  dia no Brasil. O parâmetro `now` é injetável nos testes.

- **Voltar do segundo plano reavalia "hoje".** O `AppShell` observa o ciclo de
  vida do app; no `resumed` ele rechecka a Play por atualização e, se o dia do
  calendário mudou desde que `todayProvider` foi lido, invalida
  `todayProvider` e `recurringChargesCatchUpProvider` (no máximo uma vez por
  dia), pra um app deixado aberto por dias ainda lançar as cobranças vencidas e
  mostrar a contagem certa de "pendentes". Puxar pra atualizar
  (`CatchUpRefresh`) roda o catch-up sob demanda.

- **Os catch-ups não deixam um documento ruim bloquear o resto.** Cada
  assinatura é tentada dentro do próprio `try`; o
  `recurringChargesCatchUpProvider` roda o catch-up de parcelamentos mesmo se o
  de assinaturas falhou e relança o primeiro erro no fim, pra o provider ainda
  terminar como `AsyncError` (a tela de Gastos continua distinguindo "nunca
  terminou" de "não coube no saldo"). Assinatura com `autoChargeEnabled == false`
  é pulada pelo catch-up e só lançada por "Cobrar agora".

- **A atualização in-app da Play nunca reinicia o app sozinha.**
  `AppUpdateService` (`lib/services/app_update_service.dart`) faz uma
  atualização flexible: `startUpdate` só resolve true quando a Play informa
  `downloaded`; então `AppShell._startUpdate` mostra um snackbar com "Reiniciar"
  e `restartToInstall` só roda nesse toque (a pessoa pode estar no meio de um
  lançamento). Um indicador fixo (ponto no gatilho do menu, item "Atualizar" no
  menu, botão na barra lateral larga) fica enquanto houver atualização e é
  rechecado ao voltar do segundo plano. Fora de uma instalação Android pela
  Play, toda chamada responde "sem atualização" em silêncio. Testada com um
  serviço falso; **o fluxo real do plugin só roda num build instalado pela Play e
  não foi observado** (o ponto no menu também não foi visto num aparelho).

## Restrições / pendências conhecidas (não inventadas — verificadas no código)

- **Edição de allocation individual existe no código mas não é alcançável
  pela UI.** `EditableAllocation` (`lib/widgets/edit_transaction_sheet.dart`)
  só pode ser construída para uma allocation não-transferência, mas hoje não
  há nenhuma lista de allocations na UI que a invoque — o comentário no
  próprio arquivo já sinaliza que isso existe pronto "pra quando uma lista de
  allocations for adicionada". Não é uma lacuna acidental.

- **Restaurar um backup com uma "dívida congelada" — CORRIGIDO (F1), testado
  contra o emulador.** Uma dívida congelada é uma caixinha `spend` que ficou
  negativa e depois teve o `allowNegative` desligado, a categoria apagada, ou
  o `kind` trocado para `save` — o número negativo continua na matemática do
  ledger, só a permissão de mantê-lo daqui pra frente que muda. A correção
  tem duas partes: (1) `firestore.rules` ganhou um helper `catMayHoldNeg`,
  agnóstico ao toggle, que permite recriar esse negativo SÓ no momento de
  criação do balance doc (restore/teardown — `resource == null`), nunca numa
  atualização de doc já existente — então o "freeze" ao vivo continua valendo
  como antes; (2) `FirestoreService.replaceAll` agora valida TODOS os saldos
  recalculados antes de mutar qualquer coisa (passo 0) — um backup
  genuinamente inconsistente (conta negativa, ou caixinha `save`/órfã
  negativa) falha atomicamente, sem gravar nada, em vez de travar o restore
  no meio. **Trade-off residual aceito, não é bug:** como `catMayHoldNeg` só
  olha `kind` (ignora o toggle), um cliente pode, nos SEUS PRÓPRIOS dados,
  apagar o balance doc de uma caixinha `spend` e recriá-lo negativo mesmo com
  o toggle desligado ("descongelar via teardown") — não é brecha de
  integridade nem cross-user (dado é single-tenant, os saldos exibidos são
  sempre recalculados do ledger, e um saldo errado auto-infligido só
  restringe mais as próprias escritas futuras daquele usuário). Ver `docs/
  BACKEND.pt-br.md`, "Option B residual limitations" (item F1), para o mecanismo
  completo.

- **Converter uma caixinha `spend` negativa em `save`, ou apagá-la, agora é
  barrado no app** (este item era uma pendência aberta). `updateCategory` recusa
  a conversão spend → save enquanto o doc de saldo está negativo e
  `deleteCategory` recusa saldo negativo; a tela de Categorias desabilita o botão
  de remover com explicação. As rules (`catDebtFree`, `convertsSpendToSave`)
  seguem como a garantia que não dá pra contornar.

- **O comentário de App Check em `lib/main.dart` está desatualizado.** Diz que o
  app "NOT in the Play Console yet"; o app está publicado. O comportamento não
  mudou (Play Integrity em release, provider de debug em debug, web pulada até
  existir uma chave reCAPTCHA v3). Correção só de comentário, deixada pra quem
  mexer em `lib/` da próxima vez.

- **`lib/widgets/app_shell.dart` cita `FLUTTER_MIGRATION.md` num comentário**
  ("per §4 of FLUTTER_MIGRATION.md") — esse arquivo não existe mais no repo
  (a migração do Next.js foi concluída e seus docs removidos, ver histórico
  de `git log` em torno de `d774ffb`/`135d006`). TODO: confirmar se esse
  comentário deveria ser atualizado/removido do código, ou se foi deixado
  como referência histórica intencional — não é algo que este documento
  decide sozinho.

## Testes

`flutter test` roda 715 testes (todos passando em 2026-11-16, quando isto foi
escrito). `test/` espelha a estrutura de `lib/`: `features/*_test.dart` (widget
tests por tela, incluindo `layout_sweep_test.dart`, que renderiza todas as telas
de 320 a 900 px, fonte x1.3, em pt e en pra pegar overflow, e os testes de
tutorial/estados vazios/navegação), `services/*_test.dart` (incl.
`aggregation_service_test.dart` para a matemática de dinheiro,
`auth_service_test.dart`, `tutorial_progress_test.dart`), `providers/*_test.dart`
(idioma, tema, catch-up recorrente), `models/*_test.dart` (round-trip do backup
JSON), `utils/*_test.dart`, `widgets/*_test.dart` (shell, motor de tutorial,
lançamento rápido, splash), e `test/rules/` — um harness Node standalone (fora da
árvore Flutter/pubspec) com dois arquivos rodados juntos via `npm test`:
`rules.test.mjs` (128 testes das regras do Firestore contra o emulador — o único
jeito de exercitar os caminhos `getAfter()`/genesis-teardown, que não rodam a
partir do Dart) e `backfill.test.mjs` (9 testes da classificação
dívida-vs-corrupção do `scripts/backfill_balances.mjs`, rodado como subprocesso
real). As contagens das rules foram lidas dos arquivos; o harness não foi rodado
nesta passada de documentação. Ver `docs/DEPLOY.pt-br.md` para como isso roda em
CI. Não há testes automatizados em aparelho real nem contra o plugin real de
atualização in-app da Play.
