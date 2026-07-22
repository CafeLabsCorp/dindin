# dindin

**[Leia em Português](README.pt-br.md)**

A [Café Labs](https://cafelabs.net) product.

Personal finance app organized around "envelopes" (caixinhas): income comes
in and sits as account balance until it's allocated to an envelope; expenses
come out of an envelope (or straight from the account). Each envelope has a
purpose — **spend** (with an optional monthly limit) or **save** (with an
optional savings goal) — and money can be transferred between envelopes. A
spending envelope can optionally allow a negative balance (a "debt" that the
next allocation automatically settles).

Cross-platform Flutter (Web, Android, Windows target) with Firebase as the
backend. UI defaults to Portuguese, with English available (Settings →
Language, or following the device's locale).

## Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (stable) |
| State | Riverpod (`flutter_riverpod`) |
| Routing | `go_router` |
| Charts | `fl_chart` |
| Dates/currency | `intl` (`pt_BR` / BRL) |
| i18n | `flutter_localizations` + ARB (PT template, EN) |
| Backend | Firebase (Auth + Firestore), project `dindin-cafelabs` |

## Structure (overview)

```
lib/
  main.dart / app.dart   # bootstrap, theme, routes (go_router)
  theme/                 # "Warm Envelope" visual identity — see docs/DESIGN.md
  l10n/                   # ARB (app_pt.arb template, app_en.arb)
  models/                # Category, Income, Allocation, Expense
  providers/             # Riverpod providers (includes localeProvider)
  services/              # auth, Firestore CRUD, aggregations, import/export
  features/              # one folder per screen (dashboard, income, expenses, categories, settings, auth)
  widgets/                # shared components
functions/               # Cloud Functions — INACTIVE, see functions/README.md
```

Per-file breakdown, the data flow (Riverpod → aggregation → UI), and the
full Firestore schema are in `docs/ARQUITETURA.md`.

## Running locally

```bash
flutter pub get
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run                # Android (connected emulator/device)
```

## Build and deploy

For a UI-only change (not touching `firestore.rules`, indexes, or the
balances schema), the usual manual flow still applies:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

For any change touching rules/schema/balances, use `scripts/deploy.sh`
instead — it wraps backup + backfill + verify + rules/hosting deploy in the
required order. See `docs/DEPLOY.md` (rollback and details) and
`docs/BACKEND.md` (why that order is required).

CI (`.github/workflows/ci.yml`) runs `flutter analyze`, `flutter test`, and
the rules tests on the emulator on every push to `main` — it does not deploy.

Web deployed at https://dindin-cafelabs.web.app.

## Backup/restore

In Settings, all user data can be exported to a `.json` and imported back
(replaces current data) — useful both as a manual backup and for migrating
data between accounts/environments.

## Documentation

- `docs/ARQUITETURA.md` — layers, data/state flow, full Firestore schema,
  technical decisions and why.
- `docs/DESIGN.md` — "Warm Envelope" visual identity: palette, typography,
  spacing.
- `docs/DEPLOY.md` — CI, deploy, and rollback.
- `docs/BACKEND.md` — money integrity model (denormalized balances,
  Firestore Security Rules).
