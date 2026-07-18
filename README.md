# dindin

Um produto [Café Labs](https://cafelabs.net).

App pessoal de controle financeiro por "caixinhas": receitas entram e ficam
como saldo da conta até serem alocadas numa caixinha; os gastos saem de uma
caixinha (ou direto da conta). Cada caixinha tem um propósito — **gastar**
(com limite mensal opcional) ou **guardar** (com meta de poupança opcional) —
e dá pra transferir dinheiro entre caixinhas.

Flutter multiplataforma (Web, Android, alvo Windows) com Firebase como backend.

## Stack

| Camada | Escolha |
|---|---|
| Framework | Flutter (stable) |
| Estado | Riverpod (`flutter_riverpod`) |
| Roteamento | `go_router` |
| Gráficos | `fl_chart` |
| Datas/moeda | `intl` (`pt_BR` / BRL) |
| Backend | Firebase (Auth + Firestore), projeto `dindin-cafelabs` |

## Estrutura (visão geral)

```
lib/
  main.dart / app.dart   # bootstrap, tema, rotas (go_router)
  theme/                 # identidade visual "Envelope caloroso" — ver docs/DESIGN.md
  models/                # Category, Income, Allocation, Expense
  providers/             # providers Riverpod
  services/              # auth, CRUD no Firestore, agregações, import/export
  features/              # uma pasta por tela (dashboard, receitas, gastos, categorias, ajustes, auth)
  widgets/                # componentes compartilhados
functions/               # Cloud Functions — INATIVO, ver functions/README.md
```

Detalhamento por arquivo, o fluxo de dados (Riverpod → agregação → UI) e o
schema completo do Firestore estão em `docs/ARQUITETURA.md`.

## Rodando localmente

```bash
flutter pub get
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run                # Android (emulador/dispositivo conectado)
```

## Build e deploy

Para uma mudança só de UI (sem tocar `firestore.rules`, índices ou o schema
das balances), o fluxo manual de sempre continua valendo:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

Para qualquer mudança que toque regras/schema/balances, use
`scripts/deploy.sh` em vez disso — ele encapsula o backup + backfill + verify
+ deploy de rules/hosting na ordem obrigatória. Ver `docs/DEPLOY.md` (rollback
e detalhes) e `docs/BACKEND.md` (por que essa ordem é obrigatória).

CI (`.github/workflows/ci.yml`) roda `flutter analyze`, `flutter test` e os
testes de rules no emulador em todo push pra `main` — não faz deploy.

Web publicado em https://dindin-cafelabs.web.app.

## Backup/restore

Em Ajustes, dá pra exportar todos os dados do usuário pra um `.json` e importar de
volta (substitui os dados atuais) — útil tanto como backup manual quanto para migrar
dados entre contas/ambientes.

## Documentação

- `docs/ARQUITETURA.md` — camadas, fluxo de dados/estado, schema completo do
  Firestore, decisões técnicas e por quê.
- `docs/DESIGN.md` — identidade visual "Envelope caloroso": paleta, tipografia,
  espaçamento.
- `docs/DEPLOY.md` — CI, deploy e rollback.
- `docs/BACKEND.md` — modelo de integridade de dinheiro (saldos denormalizados,
  Firestore Security Rules).
