# Backend / notas de integridade de dados

**[Read in English](BACKEND.md)**

Referência operacional pro backend em Firestore do Dindin. Ler isto antes de
qualquer deploy que toque `firestore.rules`, `firestore.indexes.json`, ou
`functions/`.

## Deploy gate: fazer backup dos dados de produção PRIMEIRO (obrigatório, passo humano)

Antes de fazer deploy de QUALQUER mudança de rules, index, schema ou
functions pro projeto ao vivo (`dindin-cafelabs`):

1. Abrir o app logado como cada usuário real.
2. Ajustes -> Exportar JSON. Salvar o arquivo `.json` em algum lugar durável.

Essa exportação é o único rollback pros dados do usuário. Nenhum processo
automatizado aqui consegue acessar dados de produção, então isso é um gate
humano. As mudanças de rules/schema nesta fase são aditivas e
retrocompatíveis (documentos antigos e backups antigos continuam
carregando), mas a exportação continua sendo exigida como rede de segurança.
Esse gate, mais CI e rollback pra rules/hosting, agora está codificado em
`scripts/deploy.sh` — ver `docs/DEPLOY.pt-br.md` pro runbook completo de
deploy/rollback.

## Dados do usuário: exportação e exclusão (baseline de privacidade)

Antes de aceitar usuários reais existe um caminho funcional pras duas coisas:

- **Exportação** — no app: Ajustes → Exportar JSON produz o ledger completo
  (`ImportExportService.exportToFile`). São os dados completos do usuário
  num formato portável e legível por humanos.
- **Exclusão** — processo manual, documentado (aceitável neste estágio):
  1. O usuário pode limpar-e-substituir os próprios dados importando um
     backup vazio/editado (`replaceAll` limpa as quatro coleções do ledger
     e reseta os docs de saldo).
  2. Exclusão completa de conta (usuário de auth + toda a subárvore
     `users/{uid}`) é um passo manual de admin: apagar o usuário de Auth no
     console do Firebase e apagar a subárvore de documento `users/{uid}`
     (ledger + `meta/account` + `balances`). A configuração
     `firebase-admin` do script de backfill também pode scriptar isso se
     necessário. Quando um botão de "excluir minha conta" self-service for
     adicionado, ele deve fazer exatamente isso.

## Adições ao modelo de dados (todas aditivas / retrocompatíveis)

- `categories/{id}.monthlyBudget` — `number` opcional (BRL). Limite mensal
  de gasto suave por caixinha; `null`/ausente significa sem limite. NÃO
  restringe os invariantes rígidos de dinheiro. Campo novo (não `recurring`,
  que é um bool pra uma pergunta diferente e foi deixado intocado).
- `allocations/{id}.transferId` — `string` opcional. Uma transferência
  caixinha-a-caixinha é um PAR de docs de allocation compartilhando esse id:
  uma perna de valor negativo na origem, uma perna de valor positivo no
  destino. O par soma zero contra a conta, então `aggregation_service.dart`
  continua correto sem mudanças, e o backup JSON continua consistente (as
  transferências vivem dentro do array `allocations` existente). A UI deve
  agrupar/rotular linhas que compartilham um `transferId` como uma
  transferência em vez de duas allocations soltas.
- `categories/{id}.kind` — `'spend' | 'save'` opcional. Pra que a caixinha
  *serve*: `spend` recebe a barra de orçamento mensal (`monthlyBudget`,
  acima), `save` recebe uma barra de meta de poupança (`goalAmount`, abaixo)
  ou uma linha de feedback "guardado este mês" quando nenhuma meta está
  definida. `null`/ausente (um doc anterior a este campo) se comporta como
  `spend` — a única semântica que existia antes. Validado em
  `firestore.rules` (`validCategory`) como sendo uma das duas strings
  literais quando presente.
- `categories/{id}.goalAmount` — `number` opcional (BRL), relevante só pra
  `kind == 'save'`. O total-alvo que o usuário quer acumular naquela
  caixinha. Assim como `monthlyBudget`, isso é só pra reporting — não
  restringe nenhum invariante de integridade de dinheiro.
- `categories/{id}.allowNegative` — `bool` opcional. AO CONTRÁRIO dos três
  campos acima, este SIM restringe um invariante de integridade de dinheiro
  — ver "allowNegative (dívida por caixinha)" abaixo. `null`/ausente (um
  doc anterior a este campo, ou qualquer caixinha `save`) se comporta como
  `false` — a única semântica que existia antes.

Backups JSON antigos (sem `monthlyBudget`, sem `transferId`, sem
`kind`/`goalAmount`, sem `allowNegative`) importam sem alterações.

### Docs de saldo denormalizados (Option B — ver abaixo)

Dois documentos derivados guardam os saldos correntes pra que as Security
Rules consigam lê-los em O(1) com `get()`/`getAfter()` (rules não conseguem
somar uma coleção):

- `users/{uid}/meta/account` — `{ balance: number }`. O saldo da conta
  geral = total de receitas − total alocado − gastos só-da-conta.
- `users/{uid}/balances/{categoryId}` — `{ balance: number }`, um por
  caixinha, chaveado pelo MESMO id do doc de categoria (pra que as rules do
  ledger consigam chegar nele deterministicamente a partir do `categoryId`
  de uma allocation/expense). balance = alocado pra aquela caixinha (incl.
  pernas de transferência) − gasto dela.

Esses são um **cache derivado, não fonte de verdade**:

- Eles NÃO fazem parte do backup JSON. `AppDb.toJson()`/`fromJson()`
  continua sendo só as quatro coleções do ledger; os saldos são
  recalculados a partir do ledger no restore (`FirestoreService.
  replaceAll`) e pelo script de backfill. Isso mantém backups antigos
  importáveis e evita guardar dados redundantes e sujeitos a drift no
  arquivo de backup.
- Os saldos exibidos na tela do app continuam sendo somados do ledger por
  `aggregation_service.dart`. Então mesmo que um doc de saldo algum dia
  desalinhasse, a UI continuaria mostrando a verdade; os docs de saldo
  existem pra deixar as RULES aplicarem não-negatividade e dar ao cliente
  checagens O(1) antes de escrever.

## Aplicação de integridade de dinheiro: DECIDIDO — Option B (só regras, tier Spark grátis)

> **Decisão (dono):** lançar **Option B** — só regras, com saldos
> denormalizados, no plano gratuito **Spark**. NÃO habilitar Blaze e NÃO
> fazer deploy de Cloud Functions. A Option A abaixo é mantida só como
> referência documentada (o código de `functions/` é mantido mas inativo —
> ver `functions/README.md`).

As duas opções foram consideradas:

Os invariantes — "gasto <= alocado por caixinha", "alocações <= saldo da
conta", "nada fica negativo" — dependem de SOMAR coleções inteiras. As
Firestore Security Rules conseguem `get()`/`getAfter()` documentos
individuais mas NÃO CONSEGUEM agregar uma coleção, então as rules sozinhas
não conseguem aplicar esses invariantes. Hoje eles são aplicados no lado do
cliente em `FirestoreService`. Duas formas de mover a aplicação pra um lugar
que um cliente malicioso não consiga contornar:

> Atualização: "nada fica negativo" não é mais um invariante incondicional.
> Desde a feature `allowNegative` (abaixo), uma caixinha `spend` pode optar
> por manter um saldo negativo ("dívida"). O saldo da conta (`meta/
> account`) e caixinhas `save` continuam incondicionalmente não-negativos —
> só uma caixinha `spend` com sua própria flag `allowNegative` ligada pode
> ficar negativa, e só ela mesma. Escrito antes dessa feature existir;
> mantido aqui pelo enquadramento histórico de por que a Option A/B
> existem, ver "allowNegative (dívida por caixinha)" pra regra atual e
> precisa.

### Option A — Cloud Functions (RECOMENDADA, exige Blaze / paga)

- Funções callable em `functions/index.js` fazem cada escrita validada
  dentro de uma transação do Firestore com privilégios de admin. Robusto:
  um único caminho de código confiável, transacional, sem drift de
  denormalização.
- As rules da Fase 2 então NEGAM escritas diretas do cliente pra `incomes`,
  `allocations`, `expenses` (e escritas de categoria se desejado); as
  funções se tornam o único caminho de escrita. As leituras continuam do
  lado do cliente.
- CUSTO: Cloud Functions exigem o **plano pago Blaze**. O tier gratuito
  Spark NÃO roda Functions. Blaze tem uma cota mensal gratuita generosa,
  mas é uma conta de billing com cartão cadastrado e sem hard-cap por
  padrão — configurar um alerta de orçamento. Não habilitado atualmente.
- Pra adotar: habilitar Blaze; `cd functions && npm install`; adicionar um
  bloco `functions` ao `firebase.json` (não commitado aqui — é uma
  preocupação de deploy); `firebase deploy --only functions,firestore:
  rules`; adicionar o pacote Dart `cloud_functions` e trocar os corpos de
  método do `FirestoreService` pra chamar o callable correspondente (as
  assinaturas de método público não mudam — ver o contrato abaixo), depois
  apertar as rules.

### Option B — Só regras com saldos denormalizados (tier GRÁTIS)

- Guardar um `balance` corrente em cada doc de categoria e um doc de saldo
  de conta (ex.: `users/{uid}/meta/account`). Toda escrita mutante é uma
  transação do Firestore do lado do cliente que atualiza o(s) doc(s) de
  saldo afetado(s) junto com o doc de transação. As rules validam o par com
  `getAfter()`, ex.: na criação de um expense: `getAfter(category).balance
  == get(category).balance - request.resource.data.amount &&
  getAfter(category).balance >= 0`.
- Trade-offs HONESTOS (não fingir que não existem):
  - Frágil. Correção exige rules pareadas TANTO no doc de transação QUANTO
    no doc de saldo (a rule de atualização do próprio doc de saldo precisa
    proibir mudanças arbitrárias, ou um cliente simplesmente reescreve seu
    saldo). Qualquer brecha é um buraco.
  - Saldos denormalizados podem SOFRER DRIFT em relação à soma real; exige
    um backfill único dos docs existentes no rollout e é mais difícil de
    auditar.
  - `getAfter()` acopla escritas em batches específicos; o cliente precisa
    sempre escrever exatamente o conjunto certo de docs ou as escritas são
    rejeitadas.
- VANTAGEM: continua no tier grátis, sem conta de billing.

### Por que a Option A NÃO foi escolhida

Pra um app de dinheiro, a Option A (Cloud Functions) é o design tecnicamente
mais forte — um único caminho de escrita confiável, transacional, sem
drift de denormalização. Não foi escolhida só porque exige o plano pago
**Blaze**, e a restrição do dono agora é ficar no tier grátis. Esse
trade-off é deliberado e documentado; se o app crescer ou o custo de
correção da fragilidade da Option B começar a incomodar, revisitar a
Option A (o caminho de migração está acima e em `functions/README.md`).

## Option B — o que está implementado

`firestore.rules` agora é **Fase 2**. Em cima da Fase 1 (default-deny,
ownership por usuário, validação de forma/tipo, valores únicos não-
negativos, `createdAt` imutável) ela adiciona:

- **Docs de saldo são cidadãos de primeira classe e estritos.** `meta/
  account` e `balances/{catId}` aceitam só `{ balance }`, `balance` precisa
  ser um número, só o dono. `meta/account` também DEVE ser `>= 0`,
  incondicionalmente — isso sozinho garante que o saldo da conta geral
  nunca pode ser armazenado negativo. `balances/{catId}` também é `>= 0`
  por padrão, EXCETO pra uma caixinha `spend` que optou por
  `allowNegative` — ver "allowNegative (dívida por caixinha)" abaixo pro
  condicional exato.
- **Vinculação de delta por escrita via `getAfter()`.** Cada create/update/
  delete do ledger precisa mover o(s) doc(s) de saldo afetado(s) por
  exatamente seu delta (ex.: um expense de conta exige
  `getAfter(account).balance == antes − valor && >= 0`). Como cada doc do
  ledger fixa o valor FINAL do(s) doc(s) de saldo que toca, você não
  consegue empacotar duas escritas conflitantes no mesmo doc de saldo pra
  passar pelas rules — a checagem não é contornável agrupando escritas.
  Essa vinculação de delta é incondicional pra todo doc de saldo, incluindo
  o de uma caixinha `allowNegative` — só o piso `>= 0` em cima dela é
  relaxado, nunca a própria checagem de delta.
- **Escape hatch de gênese/teardown.** Operações em massa (restore completo
  de JSON, cascade-delete de categoria) não conseguem satisfazer um delta
  por doc. Elas funcionam APAGANDO primeiro o(s) doc(s) de saldo
  afetado(s), fazendo as mudanças em massa no ledger enquanto o doc está
  ausente (`getAfter(...) == null` ⇒ checagem de delta pulada), depois
  escrevendo o(s) doc(s) de saldo recalculado(s) por último. Ver
  `FirestoreService.replaceAll` e `deleteCategory` pra ordem. "Recalculado"
  assume que o resultado é `>= 0`, ou elegível sob um dos dois escape
  hatches de saldo negativo (`catAllowsNeg` pra uma atualização ao vivo,
  `catMayHoldNeg` pra um doc sendo criado — ver "allowNegative (dívida por
  caixinha)" abaixo). `FirestoreService.replaceAll` agora valida todo saldo
  recalculado ANTES de mutar qualquer coisa (passo 0), então um backup que
  violaria isso é rejeitado atomicamente sem nada escrito — ver "F1" em
  "Option B residual limitations" pro modo de falha que isso substituiu.

Do lado do cliente (`lib/services/firestore_service.dart`): todo método que
afeta saldo roda uma **transação** do Firestore que lê o(s) doc(s) de
saldo, faz a mesma pré-checagem que as rules aplicam (pra um erro amigável
antes da rule rejeitar), e escreve o doc do ledger + o(s) doc(s) de saldo
juntos.

## allowNegative (dívida por caixinha)

Uma caixinha `spend` pode optar por manter um saldo negativo — uma "dívida"
— via `categories/{id}.allowNegative: bool`. Isso DELIBERADAMENTE afrouxa,
de forma restrita, o que antes era um invariante absoluto ("nenhum doc de
saldo é jamais negativo"). Regras de produto:

- **Só `kind == 'spend'` é elegível.** Uma caixinha `save` está SEMPRE
  não-negativa, incondicionalmente, mesmo que `allowNegative: true` esteja
  armazenado nela (um valor obsoleto/incoerente — ex.: o usuário trocou
  `kind` de `spend` pra `save` enquanto o toggle por acaso estava ligado).
  `catAllowsNeg()` em `firestore.rules` checa tanto a flag QUANTO
  `kind == 'spend'` toda vez, lendo o doc de categoria AO VIVO, então isso
  é aplicado no servidor independente do que o cliente enviar.
- **A dívida é quitada automaticamente pela próxima alocação/transferência-
  de-entrada, não por uma ação dedicada de "quitar".** Não existe uma
  operação separada de settle/payoff — o saldo de uma caixinha é um único
  número corrente, e uma alocação que o eleva simplesmente... eleva, mesma
  matemática de sempre.
- **Desligar o toggle enquanto o saldo está negativo é permitido.** Isso
  CONGELA a dívida existente: a caixinha recusa mais gastos/retiradas
  (qualquer coisa que aprofundaria o negativo) enquanto desligada e
  negativa, mas alocações/transferências que elevam o saldo (incluindo de
  volta pra `>= 0`) continuam permitidas. Ligar o toggle de novo reabilita
  aprofundá-la mais.

### Onde isso é aplicado

- **`firestore.rules`** — o piso `>= 0` no doc de saldo de uma caixinha
  ficou CONDICIONAL em exatamente dois lugares, ambos controlados da mesma
  forma:
  - `catDeltaOk(uid, cat, delta)` — a checagem de delta por escrita de
    ledger usada por `allocations` e `expenses`. Era `result >= 0`; agora é
    `result >= 0 || delta >= 0 || catAllowsNeg(uid, cat)`. O ramo
    `delta >= 0` é o que permite uma dívida congelada ser paga (parcial ou
    totalmente) independente do toggle; `catAllowsNeg` é o que permite um
    gasto/retirada aprofundá-la.
  - A rule de escrita direta em `balances/{categoryId}` — mesma relaxação
    de dois ramos, então uma escrita autônoma de doc de saldo é mantida no
    mesmo padrão de uma vinculada ao ledger.
  - Novo helper `catAllowsNeg(uid, cat)`: dá `get()` no doc de categoria ao
    vivo e exige `allowNegative == true` E `kind == 'spend'` (um doc legado
    sem `kind` lê como `'spend'` via `.get('kind', 'spend')`, batendo com
    `Category.effectiveKind` no cliente). Um doc de categoria ausente (ex.:
    meio-teardown) não é elegível.
  - Novo helper `catMayHoldNeg(uid, cat)` — propósito mais estreito que
    `catAllowsNeg`, **agnóstico** ao toggle: só pergunta se a caixinha é
    atualmente um envelope `spend` (ou `kind` nulo legado), ignorando
    `allowNegative` completamente. É conectado à rule de escrita de
    `balances/{categoryId}` num ramo controlado por `resource == null` —
    ou seja, só pode disparar quando o doc de saldo está sendo **criado**
    (gênese/restore), nunca numa atualização de doc existente. É isso que
    permite que uma dívida congelada (toggle desligado, `kind` trocado, ou
    categoria recriada) sobreviva a um restore completo de JSON: o saldo
    negativo recalculado é histórico legítimo do ledger, e a gênese é o
    único momento em que as rules permitem rematerializá-lo sem rechecar o
    toggle ao vivo. Uma escrita ao vivo num doc de saldo existente ainda
    passa por `catDeltaOk`/`catAllowsNeg`, então uma dívida congelada não
    pode ser aprofundada por uma escrita normal — só recriada em seu valor
    já-congelado a partir de um doc ausente. Ver "Descongelar via
    teardown" em "Option B residual limitations" pro trade-off que isso
    introduz.
  - A própria vinculação de delta anti-race (`getAfter(balDoc) == antes +
    delta`) está INALTERADA e continua incondicional — só o piso de
    não-negatividade é relaxado, nunca a garantia de "você precisa mover o
    doc por exatamente seu próprio delta". O mesmo pra `meta/account`: sua
    rule NÃO foi tocada, então o saldo da conta geral continua
    incondicionalmente `>= 0` independente do `allowNegative` de qualquer
    caixinha.
- **`lib/models/category.dart`** — `allowNegative: bool?` mais
  `allowsNegativeBalance` (`(allowNegative ?? false) && effectiveKind ==
  CategoryKind.spend`), espelhando `catAllowsNeg` pra uso do lado do
  cliente.
- **`lib/services/firestore_service.dart`** — `_catDeltaOk()` espelha o
  `catDeltaOk()` das rules exatamente (mesma checagem de três ramos) pra
  que o cliente possa dar um erro amigável em vez de um permission-denied
  cru, e pra que nunca permita otimisticamente uma escrita que as rules
  implantadas rejeitariam.
- **UI** — Ajustes/Categorias, switch "Permitir saldo negativo", mostrado
  só quando o `kind` da caixinha é `spend` (`lib/features/categorias/
  categorias_page.dart`).

Coberto por `test/rules/rules.test.mjs` (`describe('allowNegative (caixinha
debt)')`): aprofundar enquanto LIGADO, bloquear mais aprofundamento enquanto
DESLIGADO-e-negativo, quitação parcial enquanto DESLIGADO-e-negativo, uma
caixinha `save` ignorando um `allowNegative: true` perdido, transferências,
o saldo da conta permanecendo intocado/não-negativo independente disso, e
que a checagem anti-race de vinculação de delta continua se aplicando
incondicionalmente mesmo quando `catAllowsNeg` é verdadeiro.

### Ordem de deploy — OBRIGATÓRIA

`scripts/deploy.sh` codifica essa sequência exata como um script com gates
(confirmação de backup -> dry-run + checagem de balance-corruption ->
backfill real -> verify -> rules -> hosting) — ver `docs/DEPLOY.pt-br.md`
pra como rodar/debugar e pros passos de rollback. Os docs de saldo precisam
estar corretos ANTES das rules da Fase 2 e do novo cliente chegarem a
usuários reais, ou a primeira escrita do cliente vai inicializar um saldo a
partir de uma base errada (zero). Sequência de release:

1. Fazer backup dos dados de produção (o gate humano no topo deste
   arquivo).
2. Rodar o **backfill** (`scripts/backfill_balances.mjs`, ver seu
   cabeçalho) pra calcular e escrever `meta/account` + `balances/{catId}`
   pra todo usuário existente a partir do ledger atual dele. Idempotente;
   seguro pra rerodar. Roda no Spark via uma chave de service-account
   Admin (acesso Admin é grátis — só Functions precisa de Blaze).
3. Fazer deploy de `firestore.rules` (Fase 2) e lançar o novo build do
   cliente juntos.

Fazer 3 antes de 2 deixa os saldos dessincronizados no dia um.

### Option B residual limitations (pra QA / revisão de segurança)

- **As rules de getAfter/null-teardown não podem ser unit-testadas a
  partir do Flutter.** Elas DEVEM ser exercitadas contra o emulador do
  Firestore antes do deploy — em particular: os ramos de gênese/teardown
  `getAfter(...) == null`, um restore completo de `replaceAll`, e um
  cascade de `deleteCategory`. Esse é o maior item de verificação em
  aberto.
- **Drift auto-infligido é possível, dano cross-user não é.** Um cliente
  que deliberadamente apaga o próprio doc de saldo primeiro pode então
  escrever docs de ledger sem a checagem de delta e recriar o saldo em
  qualquer valor não-negativo — e, especificamente pra uma caixinha
  `spend`, também em qualquer valor negativo (`catMayHoldNeg`, o escape
  hatch só-de-gênese — ver "Descongelar via teardown" abaixo pro porquê
  disso existir e o que permite/não permite). Todos os dados são
  single-tenant, então isso só corrompe os PRÓPRIOS números do usuário, e a
  UI recalcula os saldos do ledger de qualquer forma. A fronteira real de
  segurança (sem leitura/escrita cross-user) é aplicada incondicionalmente
  por `isOwner()`.
- **Edições de allocation/expense são restritas** pra manter as rules
  tratáveis: `updateAllocation` mantém a mesma caixinha, `updateExpense`
  mantém o mesmo alvo (caixinha vs conta). Re-homing é delete + recriar.
  Esses caminhos de edição não são alcançáveis pela UI atual (só
  create/delete estão conectados), então isso não é uma regressão visível
  ao usuário hoje.
- **Transferências não são totalmente suportadas em `deleteCategory`.**
  Apagar uma categoria que tem pernas de transferência deixaria a perna
  pareada em outra caixinha órfã e desalinharia aquele saldo.
  Transferências não são alcançáveis pela UI ainda; conectar um fluxo
  dedicado antes de habilitá-las. Nenhum dado de produção tem pernas de
  transferência hoje.
- **F1 — restaurar um backup com uma dívida CONGELADA poderia falhar no
  meio do caminho — CORRIGIDO, verificado contra o emulador.** Uma dívida
  congelada é uma caixinha `spend` que ficou negativa e depois teve seu
  toggle `allowNegative` desligado, ou teve sua categoria apagada, ou teve
  seu `kind` trocado pra `save` — em todos os três casos o número negativo
  em si nunca é apagado da matemática do ledger, só a permissão de mantê-lo
  daqui pra frente. Duas mudanças juntas fecham isso:
  - **Rules (`firestore.rules`):** a rule de create/update de
    `balances/{categoryId}` ganhou um quarto ramo, `resource == null &&
    catMayHoldNeg(uid, categoryId)`, avaliado só quando o doc está sendo
    CRIADO (um restore completo ou uma recriação de categoria), nunca numa
    atualização de doc ao vivo. `catMayHoldNeg` é **agnóstico** ao toggle —
    ao contrário de `catAllowsNeg`, só checa que a caixinha é atualmente um
    envelope `spend` (ou `kind` nulo legado), então uma dívida congelada
    recalculada é aceita na gênese independente de `allowNegative` estar
    ligado ou desligado agora. Como o ramo é controlado por
    `resource == null`, uma escrita ao vivo num doc de saldo existente
    ainda passa por `catDeltaOk`/`catAllowsNeg` exatamente como antes — o
    congelamento numa caixinha ao vivo, negativa, com toggle desligado não
    é afetado; aprofundá-la ainda exige o toggle ligado.
  - **Cliente (`lib/services/firestore_service.dart`):** `replaceAll` agora
    valida todo saldo recalculado num **passo 0**, antes de apagar ou
    escrever qualquer coisa. A conta geral ficando negativa, ou qualquer
    caixinha *existente* não-`spend` calculando negativo, lança
    `StateError` e aborta sem nada escrito — então um backup genuinamente
    inconsistente falha atomicamente de saída em vez de deixar um banco
    parcialmente restaurado. Um id órfão (referenciado pelo ledger mas
    ausente de `db.categories`) nunca é materializado como um doc de saldo
    de forma alguma (inalterado de antes), então não consegue alcançar
    essa checagem nem as rules de qualquer forma.
  - Efeito líquido: restaurar um backup que contém uma dívida `spend`
    congelada legítima agora tem sucesso e rematerializa essa dívida
    (ainda congelada — o valor do toggle na categoria restaurada governa
    escritas futuras exatamente como governava antes do restore).
    Restaurar um backup onde a dívida está numa caixinha `save`, ou onde a
    conta em si está negativa, é recusado de saída como dado corrompido,
    não como uma escrita parcial. Coberto por `test/rules/rules.test.mjs`
    (`describe('genesis re-materialization of a frozen debt
    (catMayHoldNeg, F1 fix)')`, contra o emulador) e por
    `test/services/firestore_service_test.dart` (`group('replaceAll (JSON
    restore)')`, os casos de pré-validação do passo 0).
  - **Trade-off residual que isso introduz — "descongelar via teardown"
    (unfreeze via teardown), conhecido e aceito, não é bug:** como
    `catMayHoldNeg` só checa `kind`, um cliente pode, nos próprios dados
    single-tenant, apagar o doc de saldo de uma caixinha `spend` e
    recriá-lo em QUALQUER valor negativo que quiser — até um mais fundo
    que a dívida congelada real, e mesmo com `allowNegative` atualmente
    desligado. Isso NÃO é um buraco de integridade nem cross-user: a conta
    e toda caixinha `save` continuam com piso em `>= 0` mesmo na gênese
    (`catMayHoldNeg` nunca se aplica a elas), os saldos exibidos na tela
    sempre são recalculados do ledger por `aggregation_service.dart` (o
    doc de saldo é um cache de validação, não o que é exibido), e um saldo
    errado auto-infligido só consegue restringir ainda mais as próprias
    escritas futuras daquele mesmo usuário — nunca pode deixá-lo gastar a
    mais ou tocar nos dados de outro usuário. Prevenir isso completamente
    exigiria somar o ledger dentro das rules (rules não conseguem) ou
    Cloud Functions (Blaze, recusado pro build de tier grátis — ver "Por
    que a Option A NÃO foi escolhida"); esse é o teto honesto da Option B.
    Documentado no comentário de cabeçalho `HONEST LIMITS` do
    `firestore.rules` e no próprio comentário do `catMayHoldNeg`.
- **`scripts/backfill_balances.mjs` era anterior ao `allowNegative` —
  CORRIGIDO, verificado contra o emulador/dry-run.** O script agora divide
  um saldo negativo recalculado em dois baldes em vez de tratar todo
  negativo como erro:
  - **Dívida legítima** — uma caixinha `spend` EXISTENTE (ou `kind` nulo
    legado) somando negativo, seja `allowNegative` atualmente ligado
    (dívida aberta) ou desligado (dívida congelada). Impresso como aviso
    (`open debt (open, allowNegative on)` / `(FROZEN, allowNegative
    off)`) mas NÃO falha o script nem o deploy.
  - **`BALANCE CORRUPTION`** — um negativo que nunca deveria existir: a
    conta geral, uma caixinha `save`, ou um id órfão (categoria apagada,
    entradas do ledger permanecem). Isso ainda aborta o dry-run/backfill
    ruidosamente.
  - O gate do `scripts/deploy.sh` foi atualizado pra bater com isso: agora
    faz grep do log de dry-run pelo marcador `BALANCE CORRUPTION` (não o
    antigo `NEGATIVE BALANCE`, que não existe mais como marcador) e só
    aborta nesse caso. Uma dívida aberta ou congelada imprime como aviso e
    deixa o deploy prosseguir. Isso fecha o defeito original onde uma
    única dívida aberta em produção teria bloqueado todo deploy futuro de
    rules/schema, não só os que tocam `allowNegative`.
- **Pendência conhecida: sem guard do lado do app contra converter uma
  caixinha `spend` negativa em `save`, ou apagá-la, enquanto ainda deve
  uma dívida.** Essa é a ÚNICA coisa que ficou em aberto da revisão de
  segurança do `allowNegative` que ainda não foi corrigida. Hoje,
  `categorias_page.dart` deixa o usuário trocar o `kind` de uma caixinha
  de `spend` pra `save`, ou apagá-la de vez
  (`FirestoreService.deleteCategory`), sem nenhuma checagem no saldo
  atual — essa é a origem real da forma "caixinha save com dívida" /
  "órfã com dívida" que `replaceAll` (passo 0, acima) e
  `scripts/backfill_balances.mjs` agora recusam corretamente como
  `BALANCE CORRUPTION` por design, pra proteger o invariante de
  conservação de dinheiro em vez de apagar ou atribuir mal a dívida
  silenciosamente. Recusar isso no restore/backfill é a linha de defesa
  final certa, mas significa que um usuário que faz isso hoje pode se
  encurralar num backup que depois falha ao restaurar (corretamente, mas
  de forma confusa) até que ele conserte o `kind`/saldo da categoria à
  mão. Correção recomendada (ainda não implementada): adicionar um guard
  no app que bloqueia (ou avisa e exige confirmação explícita pra)
  trocar uma caixinha `spend` de saldo negativo pra `save`, e bloqueia
  apagar uma caixinha enquanto seu saldo é negativo, forçando a dívida a
  ser paga ou explicitamente perdoada primeiro. TODO: confirmar quando
  esse guard será agendado/implementado.

## Contrato do cliente (estável independente da opção)

As assinaturas de método público do `FirestoreService` são a costura. Elas
não mudam se uma escrita vai direto (hoje / Option B) ou por um callable
(Option A). Nomes de callable e payloads em `functions/index.js` espelham
esses nomes de argumento 1:1, retornando `{ id }` (ou `{ transferId }`):

- `createCategory(name, recurring, monthlyBudget?, kind?, goalAmount?, allowNegative?)`
- `updateCategory(id, name?, recurring?, monthlyBudget?, clearMonthlyBudget?, kind?, goalAmount?, clearGoalAmount?, allowNegative?)`
- `deleteCategory(id)`
- `createIncome(date, amount, source, description?)` / `updateIncome(id, ...)` / `deleteIncome(id)`
- `createAllocation(categoryId, amount, date)` / `updateAllocation(id, ...)` / `deleteAllocation(id)`
- `createTransfer(fromCategoryId, toCategoryId, amount, date) -> transferId` / `deleteTransfer(transferId)`
- `createExpense(date, amount, categoryId?, description?)` / `updateExpense(id, ...)` / `deleteExpense(id)`
