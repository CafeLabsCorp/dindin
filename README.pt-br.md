# dindin

**[Read in English](README.md)**

Um produto [Café Labs](https://cafelabs.net).

App pessoal de controle financeiro por "caixinhas": receitas entram e ficam
como saldo da conta até serem alocadas numa caixinha; os gastos saem de uma
caixinha (ou direto da conta). Cada caixinha tem um propósito — **gastar**
(com limite mensal opcional) ou **guardar** (com meta de poupança opcional) —
e dá pra transferir dinheiro entre caixinhas. Uma caixinha de gastar pode,
opcionalmente, permitir saldo negativo (uma "dívida" que a próxima alocação
quita automaticamente).

Flutter multiplataforma (Web, Android, alvo Windows) com Firebase como backend.
Interface em português por padrão, com inglês disponível (Ajustes → Idioma, ou
seguindo o idioma do dispositivo).

## Stack

| Camada | Escolha |
|---|---|
| Framework | Flutter (stable) |
| Estado | Riverpod (`flutter_riverpod`) |
| Roteamento | `go_router` |
| Gráficos | `fl_chart` |
| Datas/moeda | `intl` (`pt_BR` / BRL) |
| i18n | `flutter_localizations` + ARB (PT template, EN) |
| Backend | Firebase (Auth + Firestore), projeto `dindin-cafelabs` |

## Estrutura (visão geral)

```
lib/
  main.dart / app.dart   # bootstrap, tema, rotas (go_router)
  theme/                 # identidade visual "Envelope caloroso" — ver docs/DESIGN.pt-br.md
  l10n/                   # ARB (app_pt.arb template, app_en.arb)
  models/                # Category, Income, Allocation, Expense
  providers/             # providers Riverpod (inclui localeProvider)
  services/              # auth, CRUD no Firestore, agregações, import/export
  features/              # uma pasta por tela (dashboard, receitas, gastos, categorias, ajustes, auth)
  widgets/                # componentes compartilhados
functions/               # Cloud Functions — INATIVO, ver functions/README.md
```

Detalhamento por arquivo, o fluxo de dados (Riverpod → agregação → UI) e o
schema completo do Firestore estão em `docs/ARQUITETURA.pt-br.md`.

## Rodando localmente

```bash
flutter pub get
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run                # Android (emulador/dispositivo conectado)
```

## Configuração

O app só fala com o próprio projeto Firebase (`dindin-cafelabs`) — não existe
um backend separado pra apontar e nenhum arquivo `.env`.

- `lib/firebase_options.dart` e `android/app/google-services.json` —
  configuração do app Firebase Web/Android (API key, id do projeto, id do
  app), gerados pelo `flutterfire configure`. Os dois estão **commitados de
  propósito**: é configuração do Firebase do lado do cliente, não um
  segredo — a fronteira de acesso de verdade é `firestore.rules` (ver
  `docs/BACKEND.pt-br.md`), não esconder esse arquivo. Então um clone novo
  roda sem nenhum passo de setup aqui. Só regenerar isso (mesmo comando) se
  for apontar o app pra um projeto Firebase diferente.
- `.firebaserc` — fixa a CLI `firebase` (deploys, comandos de emulador) no
  projeto `dindin-cafelabs`.
- O login com Google no Android/Windows também precisa do SHA-1 do app
  registrado no console do Firebase (um passo único no console, não um
  arquivo local) — ver `docs/ARQUITETURA.pt-br.md`, "Login diverges between
  Web and native".
- Os scripts só-de-admin (`scripts/backfill_balances.mjs`,
  `scripts/deploy.sh`) precisam das próprias credenciais do Google Cloud
  (`gcloud auth application-default login`, ou uma chave de service-account
  via `GOOGLE_APPLICATION_CREDENTIALS`) — **não** necessário pra rodar ou
  testar o app, só pra fazer deploy. Ver `docs/DEPLOY.pt-br.md`.

## Rodando os testes

```bash
flutter pub get
flutter test
```

Cobre `test/features` (testes de widget por tela), `test/services` (incl. a
matemática pura de dinheiro em `aggregation_service_test.dart`),
`test/models`, `test/utils` e `test/widgets`. Nenhum setup extra além do
`flutter pub get`.

As Firestore Security Rules — em especial os caminhos de
`getAfter()`/gênese-teardown — não dá pra exercitar via `flutter test`; são
um harness Node separado contra um **emulador local do Firestore**:

```bash
# terminal 1, a partir da raiz do repo
firebase emulators:start --only firestore

# terminal 2
cd test/rules && npm install && npm test
```

O `npm test` ali roda tanto `rules.test.mjs` (as rules em si) quanto
`backfill.test.mjs` (que dispara `scripts/backfill_balances.mjs` como um
subprocesso de verdade, então precisa do próprio `cd scripts && npm install`
feito uma vez também). O CI (`.github/workflows/ci.yml`) roda os mesmos dois
arquivos contra um emulador auto-gerenciado em todo push pra `main`, se
preferir ver a invocação exata em vez de rodar dois terminais localmente.

## Build e deploy

Para uma mudança só de UI (sem tocar `firestore.rules`, índices ou o schema
das balances), o fluxo manual de sempre continua valendo:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

Para qualquer mudança que toque regras/schema/balances, use
`scripts/deploy.sh` em vez disso — ele encapsula o backup + backfill + verify
+ deploy de rules/hosting na ordem obrigatória. Ver `docs/DEPLOY.pt-br.md` (rollback
e detalhes) e `docs/BACKEND.pt-br.md` (por que essa ordem é obrigatória).

CI (`.github/workflows/ci.yml`) roda `flutter analyze`, `flutter test` e os
testes de rules no emulador em todo push pra `main` — não faz deploy.

Web publicado em https://dindin-cafelabs.web.app.

## Backup/restore

Em Ajustes, dá pra exportar todos os dados do usuário pra um `.json` e importar de
volta (substitui os dados atuais) — útil tanto como backup manual quanto para migrar
dados entre contas/ambientes.

## Documentação

- `docs/ARQUITETURA.pt-br.md` — camadas, fluxo de dados/estado, schema completo do
  Firestore, decisões técnicas e por quê.
- `docs/DESIGN.pt-br.md` — identidade visual "Envelope caloroso": paleta, tipografia,
  espaçamento.
- `docs/DEPLOY.pt-br.md` — CI, deploy e rollback.
- `docs/BACKEND.pt-br.md` — modelo de integridade de dinheiro (saldos denormalizados,
  Firestore Security Rules).
