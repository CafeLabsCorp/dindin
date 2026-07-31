# Arquitetura

**[Read in English](ARQUITETURA.md)**

Como o Dindin funciona por dentro. Para o que o app é e como rodar localmente,
ver `README.md`; para a modelagem de integridade de dinheiro (Firestore rules,
saldos denormalizados) ver `docs/BACKEND.pt-br.md`; para a identidade visual ver
`docs/DESIGN.pt-br.md`.

## Camadas

```
lib/
  main.dart            bootstrap: Firebase.initializeApp, intl pt_BR, runApp
  app.dart              MaterialApp.router: tema (light/dark) + go_router
  theme/                identidade visual ("Envelope caloroso", ver docs/DESIGN.pt-br.md)
    colors.dart         AppPalette — tokens de cor hardcoded (light/dark)
    theme.dart          ColorScheme + TextTheme + AppTokens (ThemeExtension)
  models/               classes de dado puras (sem lógica de Firestore)
  services/
    auth_service.dart          login email/senha + Google (web e nativo divergem)
    firestore_service.dart     CRUD + integridade de dinheiro (transactions)
    aggregation_service.dart   funções puras: saldos, resumos mensais
    recurring_schedule.dart    funções puras: quais cobranças de assinatura/
                               parcelamento estão vencidas (usado pelo
                               catch-up e pela tela, pra não divergirem)
    import_export_service.dart backup/restore em JSON
  providers/providers.dart     providers Riverpod, ligam services -> UI
  features/<nome>/<nome>_page.dart   uma pasta por tela
                       (assinaturas/ e parcelamentos/ são destinos de topo,
                        ver a decisão de navegação abaixo)
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

  meta/account            { balance: number }   # saldo geral da conta (derivado)
  balances/{categoryId}   { balance: number }   # saldo de cada caixinha (derivado)
```

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

  A forma atual não tem essa costura: em tela estreita não existe barra
  inferior, e o símbolo do Dindin na app bar abre um menu com os SETE
  destinos. Como bônus, acaba de vez o problema de rótulo — uma lista
  vertical dá largura cheia pra cada nome, então nada trunca nem precisa de
  abreviação ("Assinaturas" e "Parcelamentos" voltaram por inteiro). O título
  ao lado do logo passa a dizer em qual tela você está, papel que era do slot
  selecionado da barra. O custo é honesto: navegar vira dois toques.

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
  transferência) — ver `docs/BACKEND.pt-br.md`, "Option B residual limitations".

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

- **Não há guard no app contra converter uma caixinha `spend` negativa em
  `save`, ou apagá-la, enquanto a dívida está aberta.** `categorias_page.dart`
  deixa trocar o `kind` ou chamar `deleteCategory` sem checar o saldo atual —
  é essa a origem real do estado "`save` com dívida" / "órfã com dívida" que
  o restore (`replaceAll` passo 0) e o backfill hoje recusam de propósito
  como `BALANCE CORRUPTION`, pra não destruir a conservação de dinheiro.
  Recomendação (ainda não implementada): bloquear ou exigir confirmação
  explícita antes de trocar o `kind` de uma caixinha `spend` negativa, e
  bloquear apagar uma caixinha com saldo negativo. Ver `docs/BACKEND.pt-br.md`,
  "Option B residual limitations", último item. TODO: confirmar quando essa
  correção entra no roadmap.

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
`widgets/*_test.dart`, e `test/rules/` — um harness Node standalone (fora da
árvore Flutter/pubspec) com dois arquivos rodados juntos via `npm test`:
`rules.test.mjs` (as regras do Firestore contra o emulador — o único jeito de
exercitar os caminhos `getAfter()`/genesis-teardown, que não rodam a partir
do Dart) e `backfill.test.mjs` (cobertura de regressão pra classificação de
dívida-vs-corrupção do `scripts/backfill_balances.mjs`, rodado como
subprocesso real). Ver `docs/DEPLOY.pt-br.md` para como isso roda em CI.
