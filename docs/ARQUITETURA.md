# Architecture

**[Leia em Português](ARQUITETURA.pt-br.md)**

How Dindin works internally. For what the app is and how to run it locally,
see `README.md`; for the money-integrity model (Firestore rules,
denormalized balances) see `docs/BACKEND.md`; for the visual identity see
`docs/DESIGN.md`.

## Layers

```
lib/
  main.dart            bootstrap: Firebase.initializeApp, intl pt_BR, runApp
  app.dart              MaterialApp.router: theme (light/dark) + go_router
  theme/                visual identity ("Warm Envelope", see docs/DESIGN.md)
    colors.dart         AppPalette — hardcoded color tokens (light/dark)
    theme.dart          ColorScheme + TextTheme + AppTokens (ThemeExtension)
  models/               plain data classes (no Firestore logic)
  services/
    auth_service.dart          email/password login + Google (web and native diverge)
    firestore_service.dart     CRUD + money integrity (transactions)
    aggregation_service.dart   pure functions: balances, monthly summaries
    import_export_service.dart JSON backup/restore
  providers/providers.dart     Riverpod providers, wire services -> UI
  features/<name>/<name>_page.dart   one folder per screen
  widgets/              components shared across screens
```

## Data flow / state management

Riverpod (`flutter_riverpod`) is the single source of state — there's no
second mechanism (no global `setState`, no separate store). The data path:

1. `FirestoreService` exposes one `Stream` per collection (`watchCategories`,
   `watchIncomes`, `watchAllocations`, `watchExpenses`), each a Firestore
   `snapshots()` mapped to the matching Dart model.
2. `providers.dart` wraps each stream in a `StreamProvider`
   (`categoriesProvider`, `incomesProvider`, etc.), gated by
   `firestoreServiceProvider` (which is `null` while signed out —
   `authStateProvider` decides that).
3. `summaryProvider` (a plain `Provider`, not a stream) combines the four
   streams into an `AppDb` and calls `aggregation_service.buildSummary(db)` —
   **pure** functions (no I/O, easy to test in isolation; see
   `test/services/aggregation_service_test.dart`) that compute the account
   balance, per-envelope balance, current-month summary, and monthly history.
4. Screens (`features/**`) only do `ref.watch(summaryProvider)` /
   `ref.watch(categoriesProvider)` etc. — they never read Firestore directly.

In other words: **Firestore stream → provider → pure aggregation → UI**,
always in that direction. This mirrors the old `/api/summary` endpoint from
an earlier Next.js version of the app (removed from the repo — commits
`d774ffb`/`135d006`); `aggregation_service.dart` and several models still
cite that history in comments ("mirrors X in the Next.js app's..."), kept
because they explain *why* the schema has the shape it has, not because the
Next.js app still exists anywhere in the repo.

## Data model (Firestore)

Partitioned per user under `users/{uid}`:

```
users/{uid}
  categories/{categoryId}
    name: string
    recurring: bool
    createdAt: string (ISO date)
    monthlyBudget: number?     # soft monthly spending limit ("spend" envelope)
    kind: 'spend' | 'save'?    # null/absent = legacy, treated as 'spend'
    goalAmount: number?        # savings goal ("save" envelope)
    allowNegative: bool?       # only relevant for kind == 'spend'; lets the
                                # envelope hold a negative balance ("debt")

  incomes/{incomeId}
    date: string (ISO), amount: number, source: string, description: string?

  allocations/{allocationId}
    categoryId: string, amount: number, date: string (ISO)
    transferId: string?        # non-null = one leg of an envelope-to-envelope
                                # transfer (see below)

  expenses/{expenseId}
    date: string (ISO), amount: number
    categoryId: string?        # null = expense straight from the account, not an envelope
    description: string?

  meta/account            { balance: number }   # overall account balance (derived)
  balances/{categoryId}   { balance: number }   # each envelope's balance (derived)
```

`meta/account` and `balances/{categoryId}` are a **derived cache**, not
source of truth: they are not part of the JSON backup and are recomputed from
the ledger (the four collections above) both on restore
(`FirestoreService.replaceAll`) and by the backfill script. The balances
shown on screen are always summed from the ledger by
`aggregation_service.dart` — even if the cache ever drifted, the UI would
still show the truth. They exist only so Security Rules can validate in O(1)
(rules cannot sum a whole collection). See `docs/BACKEND.md` for the full
rationale, the guaranteed invariants, and this design's known limitations.

`Category.kind`, `monthlyBudget`, `goalAmount`, `allowNegative`, and
`Allocation.transferId` are all optional fields added after the original
schema — an old JSON backup without them still imports unchanged.

## Technical decisions and why

- **Writes go straight from the client to Firestore, with no backend of its
  own.** There's no intermediary API — `FirestoreService` writes directly,
  and money integrity is guaranteed by Firestore Security Rules
  (`firestore.rules`), not by a trusted server. This is the "Option B"
  documented in `docs/BACKEND.md`, chosen to stay on Firebase's free tier
  (Spark) — the Cloud Functions alternative (`functions/`, paid Blaze tier)
  exists as inactive reference only, not deployed.

- **A transfer between envelopes is two `Allocation`s paired by
  `transferId`, not a new collection.** A negative leg on the source
  envelope, a positive leg on the destination one, netting to zero against
  the account balance. This avoids any change to `aggregation_service.dart`
  (which already sums allocations per category) and keeps the JSON backup
  compatible (the transfer already lives inside the existing `allocations`
  array).

- **An envelope's purpose (`CategoryKind`: `spend` vs. `save`) changes the
  progress widget, not the money model.** A "spend" envelope shows
  `CaixinhaBudgetBar` (consumption of a monthly limit, turns into an alert
  as it approaches/passes the limit). A "save" envelope shows
  `CaixinhaGoalBar` (progress toward a goal) when it has a `goalAmount`, or
  `CaixinhaSavedThisMonth` (net in/out for the month) when no goal is set —
  see `lib/widgets/caixinha_budget_bar.dart`. A null `kind` (a document
  predating this field) behaves as `spend`, preserving the only semantics
  that existed before.

- **`allowNegative` deliberately loosens, and only in a narrow scope, an
  invariant that used to be absolute ("no balance ever goes negative").** A
  `spend` envelope can turn on the "Permitir saldo negativo" (allow negative
  balance) toggle and start accepting expenses that leave its balance
  negative (a "debt"). Paying it off is just normal balance arithmetic — the
  next allocation/transfer into that envelope simply adds up and pays down
  the debt, with no separate "settle" action. A `save` envelope never goes
  negative, and neither does the overall account (`meta/account`) — the
  loosening applies only to `balances/{catId}` for a `spend` envelope with
  the flag on. See `docs/BACKEND.md`, "allowNegative (dívida por caixinha)",
  for the full mechanism (rules + client), restoring a backup with a frozen
  debt (**F1**, fixed), and the known open item: there's currently no
  in-app guard against converting a negative `spend` envelope into `save`,
  or deleting it, while the debt is still open.

- **A single breakpoint (720px) reused across all responsive
  navigation/forms**, instead of a per-screen value: `AppShell` (side rail
  vs. bottom nav), `showAdaptiveFormSheet` (dialog vs. bottom sheet for
  edit/transfer forms), and `ResponsiveFormRow` (side-by-side vs. stacked
  fields) all use the same constant. A user learns the pattern once.

- **`ColorScheme` built explicitly (not `ColorScheme.fromSeed`).** See
  `docs/DESIGN.md` — the color tokens were hand-calibrated (WCAG contrast
  checked per foreground/background pair), so deriving from a single seed
  color would lose that control.

- **Rounding to the cent (`round2`) on every money sum
  (`aggregation_service.dart`).** Summing many floating-point values
  accumulates binary error (an amount that should be exactly R$0 can sum to
  `-1.7e-13`); every aggregation passes through `round2` before reaching a
  comparison or the screen.

- **Login diverges between Web and native.** On Web, Google Sign-In uses
  Firebase Auth's own `signInWithPopup` (uses the project's authorized
  domains, no separate OAuth client to configure). On Android/Windows, it
  uses the `google_sign_in` package with a fixed `serverClientId` (the
  Firebase project's "Web" OAuth client) — depends on the Android app's
  SHA-1 being registered in Firebase. See `lib/services/auth_service.dart`.

## Known constraints / open items (not invented — verified in the code)

- **Editing a single allocation exists in code but isn't reachable from the
  UI.** `EditableAllocation` (`lib/widgets/edit_transaction_sheet.dart`) can
  only be constructed for a non-transfer allocation, but there's currently no
  allocation list in the UI that invokes it — the comment in the file itself
  already flags that this exists ready "pra quando uma lista de allocations
  for adicionada" (for when an allocation list gets added). Not an
  accidental gap.

- **`deleteCategory` doesn't handle envelopes with transfer legs.** Deleting
  a category that has `transferId` legs would leave the paired leg in another
  envelope orphaned and throw that balance off. Not reachable from the UI
  today (no production category has transfer legs) — see `docs/BACKEND.md`,
  "Option B residual limitations".

- **Restoring a backup with a "frozen debt" — FIXED (F1), tested against the
  emulator.** A frozen debt is a `spend` envelope that went negative and then
  had `allowNegative` turned off, the category deleted, or `kind` switched to
  `save` — the negative number stays in the ledger math, only the permission
  to keep it going forward changes. The fix has two parts: (1)
  `firestore.rules` gained a toggle-agnostic helper `catMayHoldNeg`, that
  allows re-creating that negative ONLY at the moment the balance doc is
  created (restore/teardown — `resource == null`), never on an update to an
  existing doc — so the live "freeze" still holds exactly as before; (2)
  `FirestoreService.replaceAll` now validates ALL recomputed balances before
  mutating anything (step 0) — a genuinely inconsistent backup (negative
  account, or a negative `save`/orphan envelope) fails atomically, writing
  nothing, instead of stalling the restore midway. **Accepted residual
  trade-off, not a bug:** since `catMayHoldNeg` only looks at `kind` (ignores
  the toggle), a client can, on its OWN data, delete a `spend` envelope's
  balance doc and re-create it negative even with the toggle off ("unfreeze
  via teardown") — not an integrity hole nor cross-user (data is
  single-tenant, the displayed balances are always recomputed from the
  ledger, and a self-inflicted wrong balance only further restricts that same
  user's own future writes). See `docs/BACKEND.md`, "Option B residual
  limitations" (item F1), for the full mechanism.

- **There's no in-app guard against converting a negative `spend` envelope
  into `save`, or deleting it, while the debt is still open.**
  `categorias_page.dart` lets you switch `kind` or call `deleteCategory`
  without checking the current balance — that's the real origin of the
  "`save` with debt" / "orphan with debt" state that restore (`replaceAll`
  step 0) and the backfill now deliberately refuse as `BALANCE CORRUPTION`,
  to avoid breaking money conservation. Recommendation (not yet
  implemented): block or require explicit confirmation before switching the
  `kind` of a negative `spend` envelope, and block deleting an envelope with
  a negative balance. See `docs/BACKEND.md`, "Option B residual
  limitations", last item. TODO: confirmar when this fix lands on the
  roadmap.

- **`lib/widgets/app_shell.dart` cites `FLUTTER_MIGRATION.md` in a comment**
  ("per §4 of FLUTTER_MIGRATION.md") — that file no longer exists in the repo
  (the Next.js migration was completed and its docs removed, see the `git
  log` history around `d774ffb`/`135d006`). TODO: confirmar whether that
  comment should be updated/removed from the code, or was left intentionally
  as historical reference — not something this document decides on its own.

## Tests

`test/` mirrors the structure of `lib/`: `features/*_test.dart` (widget tests
per screen), `services/*_test.dart` (incl. `aggregation_service_test.dart`
for the money math, which is pure and easy to test in isolation),
`models/db_json_test.dart` (JSON backup round-trip), `utils/*_test.dart`,
`widgets/*_test.dart`, and `test/rules/rules.test.mjs` (the Firestore rules
against the emulator — the only way to exercise the `getAfter()`/
genesis-teardown paths, which don't run from Dart). See `docs/DEPLOY.md` for
how this runs in CI.
