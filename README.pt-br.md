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

Flutter multiplataforma (Web e Android) com Firebase como backend. Interface em
português por padrão, com inglês disponível (Ajustes → Idioma, ou seguindo o
idioma do dispositivo). O tema segue o sistema por padrão e pode ser forçado para
claro ou escuro em Ajustes → Tema. O desktop Windows deixou de ser alvo em
2026-08-30 (sem provider de App Check pra ele, nunca empacotado) e a pasta
`windows/` foi removida em 2026-11-16.

**Situação (2026-11-17):** versão **1.2.1+7**. O app web está no ar em
`app.dindin.cafelabs.net` (também https://dindin-cafelabs.web.app). No Android o
app está em produção na Google Play, só Brasil
([ficha](https://play.google.com/store/apps/details?id=com.cafelabs.dindin)): a
1.2.1 está aprovada e no ar (enviada em 2026-11-16, confirmada em 2026-11-17). Versões publicadas e o fluxo de release:
`docs/DEPLOY.pt-br.md`. Páginas legais (públicas, hospedadas pelo site
`dindin-landing`, não em `docs/`): política de privacidade
https://dindin.cafelabs.net/privacidade; termos de uso (`/termos`) e exclusão de
conta (`/excluir-conta`) no mesmo host. O texto-fonte dos dois primeiros está em
`legal/`.

**O que não está verificado:** os tutoriais do onboarding, o seletor de tema, a
animação de abertura e o indicador de atualização in-app foram validados só em
testes de widget e em emuladores/renders, não num aparelho real. A lista completa
está em `docs/PENDENCIAS.pt-br.md`.

## Stack

| Camada | Escolha |
|---|---|
| Framework | Flutter (stable) |
| Estado | Riverpod (`flutter_riverpod`) |
| Roteamento | `go_router` |
| Gráficos | `fl_chart` |
| Datas/moeda | `intl` (`pt_BR` / BRL) |
| i18n | `flutter_localizations` + ARB (PT template, EN) |
| Preferências locais | `shared_preferences` (idioma, tema) |
| Ilustrações | `flutter_svg` (`assets/illustrations/`, `assets/logo.svg`) |
| Backend | Firebase (Auth + Firestore), projeto `dindin-cafelabs`, plano Spark (grátis) |
| Abuso/analytics | Firebase App Check (Play Integrity no Android; envia tokens, sem Enforce) e Firebase Analytics (opt-out em Ajustes) |
| Atualização | Atualização in-app da Google Play (`in_app_update`, só Android pela Play) |

## Estrutura (visão geral)

```
lib/
  main.dart / app.dart   # bootstrap, tema, rotas (go_router)
  theme/                 # identidade visual "Envelope caloroso" — ver docs/DESIGN.pt-br.md
  l10n/                   # ARB (app_pt.arb template, app_en.arb)
  models/                # Category, Income, Allocation, Expense, Subscription,
                         # InstallmentPurchase, progresso dos tutoriais
  providers/             # providers Riverpod (streams de dados, idioma, tema, tutoriais)
  services/              # auth, CRUD no Firestore, agregações, agenda de cobranças
                         # recorrentes, import/export, analytics, atualização in-app
  features/              # uma pasta por tela (dashboard, receitas, gastos,
                         # assinaturas, parcelamentos, categorias, settings, auth)
  widgets/                # componentes compartilhados; widgets/tutorial/ = motor do
                         # onboarding; splash_gate.dart = animação de abertura
assets/                  # fontes, logo, ilustrações (SVG)
functions/               # Cloud Functions — INATIVO, ver functions/README.md
scripts/                 # deploy.sh, release_android.sh, scripts de backfill/varredura (Node)
test/                    # testes Flutter + test/rules (harness das rules do Firestore)
docs/                    # arquitetura, backend, deploy, design, Play Console, pendências
legal/                   # texto-fonte da política de privacidade e dos termos (publicados no site)
```

Detalhamento por arquivo, o fluxo de dados (Riverpod → agregação → UI) e o
schema completo do Firestore estão em `docs/ARQUITETURA.pt-br.md`.

## Rodando localmente

```bash
flutter pub get
flutter run -d chrome      # Web
flutter run                # Android (emulador/dispositivo conectado)
```

## Configuração

O app só fala com o próprio projeto Firebase (`dindin-cafelabs`) — não existe
um backend separado pra apontar e nenhum arquivo `.env`.

- Versão do Flutter: a CI fixa o Flutter `3.44.4` (canal stable,
  `.github/workflows/ci.yml`); a restrição de SDK Dart em `pubspec.yaml` é
  `^3.12.2`. Use o mesmo Flutter pra evitar surpresas.
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
- `android/key.properties` (fora do repo; modelo em
  `android/key.properties.example`) aponta pro **keystore de upload** da Play, que
  precisa ficar fora do repo. Só é preciso pra gerar um `.aab` assinado com
  `scripts/release_android.sh`; sem ele um build de release cai na chave de debug
  (serve pra CI, a Play recusa). Ver `docs/DEPLOY.pt-br.md`.
- Firebase App Check: builds Android de release pedem um token do Play Integrity
  e builds de debug usam o provider de debug (o token dele precisa ser registrado
  uma vez no Firebase Console, App Check → Apps → tokens de debug). A web ainda
  não tem App Check (`_recaptchaV3SiteKey` em `lib/main.dart` é um placeholder).
  Ver `docs/BACKEND.pt-br.md`, "App Check".
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

715 testes passam em 2026-11-16. Cobre `test/features` (testes de widget por
tela, os tutoriais do onboarding, estados vazios e `layout_sweep_test.dart`, que
renderiza todas as telas de 320 a 900 px, fonte x1.3, em pt e en),
`test/services` (incl. a matemática pura de dinheiro em
`aggregation_service_test.dart`), `test/providers`, `test/models`, `test/utils` e
`test/widgets`. Nenhum setup extra além do `flutter pub get`. Nada disso roda em
aparelho real nem exercita a atualização in-app real da Play.

As Firestore Security Rules — em especial os caminhos de
`getAfter()`/gênese-teardown — não dá pra exercitar via `flutter test`; são
um harness Node separado contra um **emulador local do Firestore**:

```bash
# terminal 1, a partir da raiz do repo
firebase emulators:start --only firestore

# terminal 2
cd test/rules && npm install && npm test
```

O `npm test` ali roda tanto `rules.test.mjs` (as rules em si; 128 testes) quanto
`backfill.test.mjs` (9 testes; dispara `scripts/backfill_balances.mjs` como um
subprocesso de verdade, então precisa do próprio `cd scripts && npm install`
feito uma vez também). O CI (`.github/workflows/ci.yml`) roda os mesmos dois
arquivos contra um emulador auto-gerenciado em todo push pra `main`, se
preferir ver a invocação exata em vez de rodar dois terminais localmente.

## Build e deploy

Web (Firebase Hosting) e Android (Google Play) saem separados.

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

Web publicado em https://dindin-cafelabs.web.app (e `app.dindin.cafelabs.net`).

**Release Android:** `scripts/release_android.sh` sobe o `versionCode`, roda
analyze + testes, gera um `.aab` assinado e confere que a assinatura não é a chave
de debug; o upload no Play Console é manual; os releases levam a tag `vX.Y.Z`.
Mudança de rules/schema sempre passa antes por `scripts/deploy.sh`. Detalhes, a
lista de versões publicadas e os limites de rollback (na Play não existe
rollback): `docs/DEPLOY.pt-br.md`.

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
- `docs/PLAY_CONSOLE.pt-br.md` — situação do Play Console (declarações feitas e
  pendentes), ficha da loja, configuração OAuth do login com Google.
- `docs/onboarding-design.md` — racional de design e o que foi construído nos
  tutoriais do onboarding (só em português).
- `docs/PENDENCIAS.pt-br.md` — pendências, riscos aceitos, dependências e o que
  ainda não foi verificado.
- `docs/PROGRESSO.pt-br.md` — em que pé o trabalho está.
- `docs/play-store-assets/README.md` — quais gráficos da loja existem (os PNGs não
  são versionados).
- `CLAUDE.md` — ponteiro curto para agentes de IA; tudo que é substantivo mora
  nos arquivos acima.
