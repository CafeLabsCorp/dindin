# Deploy, CI e rollback

**[Read in English](DEPLOY.md)**

Guia operacional pra um mantenedor solo rodar/debugar o deploy do Dindin sem
reconstruir contexto. Ler `docs/BACKEND.pt-br.md` primeiro pro *porquê* a
ordem de deploy é a que é — este arquivo é o *como*, mais CI e rollback.

## CI (`.github/workflows/ci.yml`)

Roda em todo push pra `main`. Dois jobs independentes, ambos no tier
gratuito do GitHub Actions (repo público/privado, esse volume de pushes —
longe dos 2.000 minutos grátis/mês):

- **`flutter`** — `flutter pub get && flutter analyze && flutter test`.
  Agnóstico de plataforma (sem empacotamento Android/Windows aqui — isso é
  um item de backlog separado).
- **`rules`** — sobe o emulador do Firestore (`firebase-tools
  emulators:exec`) e roda `npm test` em `test/rules/`, que é
  `rules.test.mjs` (regras de segurança — integridade de dinheiro da Fase 2,
  incluindo os caminhos `getAfter()`/null-teardown que não podem ser
  exercitados a partir do Dart; dezenas de casos em 8 blocos `describe`) **e**
  `backfill.test.mjs` (classificação de dívida-legítima-vs-corrupção do
  `scripts/backfill_balances.mjs`, rodado como subprocesso real contra o
  mesmo emulador), os dois numa passada só. Usa só o emulador — nunca toca
  produção, não precisa de credenciais de projeto.

CI **não** faz deploy de nada. É uma rede de segurança pro código; publicar
em produção continua sendo a ação manual deliberada abaixo.

Pra debugar uma falha de CI localmente, rodar os mesmos comandos: `flutter
analyze`, `flutter test`, ou `firebase emulators:exec --only firestore
--project dindin-rules-test "npm test --prefix test/rules"` (ver o cabeçalho
de `test/rules/rules.test.mjs` pra variante manual de dois terminais).

## Fazendo deploy (`scripts/deploy.sh`)

Codifica a ordem obrigatória de release de `docs/BACKEND.pt-br.md` como um
script com gates rígidos, pra que um passo não possa ser pulado ou
reordenado por acidente:

1. Confirmação interativa de que o backup manual dos dados (Ajustes ->
   Exportar JSON, por usuário real) foi feito. Aborta se não confirmado.
2. Dry-run do backfill (`backfill_balances.mjs --dry-run`); aborta se a
   saída contiver o marcador `BALANCE CORRUPTION` — um saldo negativo que
   nunca deveria existir (a conta geral, uma caixinha `save`, ou um id
   órfão). Uma dívida aberta/congelada legítima numa caixinha `spend` (a
   feature `allowNegative`) imprime como um aviso "open debt" SEM esse
   marcador e NÃO bloqueia o deploy — ver `docs/BACKEND.pt-br.md`, "Option
   B residual limitations" pra como o script diferencia os dois casos.
3. Confirmação interativa final antes de qualquer escrita/deploy real.
4. Rodada real do backfill (idempotente).
5. Preflight: `backfill_balances.mjs --verify` — confirma que todo
   `/users/{uid}` tem um doc `meta/account`. Aborta antes de tocar as
   rules se alguém estiver sem um.
6. `firebase deploy --only firestore:rules --project dindin-cafelabs`.
7. `flutter build web` + `firebase deploy --only hosting --project
   dindin-cafelabs`.

Rodar a partir da raiz do repo:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/caminho/abs/pra/serviceAccount.json  # nunca commitar isso
scripts/deploy.sh
```

Esse script é pensado pra uso interativo, manual, durante um release — não
roda em CI. Se você só precisa publicar uma mudança só de hosting (sem
mudança de rules/schema), a sequência manual antiga continua válida e
segura:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

(Pular `scripts/deploy.sh` inteiramente pra mudanças puras de UI — o gate de
backup/backfill existe especificamente pra mudanças que tocam
`firestore.rules` ou os docs de saldo, não todo deploy.)

## Rollback

### Firestore rules

O arquivo de rules anterior vive no histórico do git — esse é todo o
caminho de rollback, sem backup separado necessário:

```bash
git log --oneline -- firestore.rules        # achar o último commit bom
git show <commit-bom>:firestore.rules > firestore.rules
firebase deploy --only firestore:rules --project dindin-cafelabs
git checkout -- firestore.rules             # restaurar a working tree depois
```

Isso só toca as rules — não afeta os docs de saldo escritos pelo backfill,
que continuam válidos sob qualquer versão de rules (as rules da Fase 1
simplesmente não os checam).

### Hosting (cliente web)

O Firebase Hosting mantém releases anteriores automaticamente. Pra fazer
rollback sem rebuild:

- Console do Firebase -> Hosting -> seu site -> "Release history" -> escolher
  o release anterior -> **Rollback**. São alguns cliques, sem precisar de
  CLI, e é o caminho mais rápido de volta a um cliente conhecido-bom.
- Ou pela CLI: `firebase hosting:clone <site>:<id-do-release-anterior>
  <site>:live --project dindin-cafelabs`.

### Dados do usuário

O **único** rollback pros dados do usuário é a exportação manual de JSON
feita durante o passo de backup do deploy-gate (`scripts/deploy.sh` passo 1
/ `docs/BACKEND.pt-br.md`). Pra restaurar: abrir o app, logar como o
usuário afetado, Ajustes -> Importar JSON, escolher o arquivo de backup.
Isso substitui as quatro coleções de ledger daquele usuário e reseta os
docs de saldo a partir do ledger importado — não há restore parcial/
seletivo, então usar a exportação boa mais recente.

Não há backup automatizado point-in-time do Firestore em si (o tier
Spark/grátis não tem produto de export agendado) — a exportação JSON por
usuário é toda a história de durabilidade de dados agora. Se o uso crescer
o bastante pra "pedir pra cada usuário ter exportado recentemente" deixar
de ser uma barra aceitável, revisitar um export agendado (tier Blaze
`gcloud firestore export` pro Cloud Storage, ou um dump scriptado com o
Admin SDK) — fora do escopo deste ciclo de MVP.

## Monitoramento — gap atual, próximo passo recomendado (não configurado neste ciclo)

O escopo deste ciclo foi CI + o gate de backup/rollback. Marcando
explicitamente: **não há hoje visibilidade de uptime ou taxa de erro no app
em produção** — uma queda ou um pico de escritas rejeitadas (ex.: de uma
regressão de rules) só seria descoberto por um report de usuário. Isso é
uma lacuna aceitável e deliberada pras mudanças de código que saem *neste*
ciclo (mudanças de rules são aditivas/retrocompatíveis conforme
`docs/BACKEND.pt-br.md` e foram verificadas contra o emulador), mas não
deve continuar sem endereçamento por muito tempo conforme usuários reais
passam a depender deste app. Opções mais baratas, em ordem de esforço:

- **Uptime**: um monitor externo grátis (ex.: tier grátis do UptimeRobot —
  50 monitores, intervalo de 5 minutos, alerta por email/webhook) apontado
  pra `https://dindin-cafelabs.web.app`. Leva uns 5 minutos pra configurar
  e não precisa de mudança de código; só precisa criar uma conta, então
  fica pro dono em vez de ser feito silenciosamente aqui.
- **Erros**: Firebase Crashlytics (grátis, produto Firebase já integrado)
  pra erros do lado do cliente, ou observar o painel de uso/negações de
  "Rules" do Firestore no console do Firebase depois de um deploy de rules
  pra pegar um pico de escritas rejeitadas.
- **Uso/custo**: Spark é um tier grátis com hard-cap (sem conta de billing
  anexada, então não tem risco de conta surpresa), mas ainda tem quotas
  diárias (leituras/escritas/deleções, egress). Configurar um alerta de
  orçamento/quota no console do Firebase (Usage and billing -> Details &
  settings) pra descobrir sobre pressão de quota antes dos usuários,
  ex.: se um lançamento viralizar.
