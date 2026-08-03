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
    recurring_schedule.dart    pure functions: which subscription/installment
                               charges are due (shared by catch-up and the
                               screen, so the two can't disagree)
    import_export_service.dart JSON backup/restore
  providers/
    providers.dart             Riverpod providers, wire services -> UI
    settings_provider.dart     theme and language, persisted on the device
  features/<name>/<name>_page.dart   one folder per screen
                       (assinaturas/ and parcelamentos/ are top-level
                        destinations — see the navigation decision below)
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
    sourceType: string?        # 'subscription' | 'installment' — absent = typed in by hand
    sourceId: string?          # id of the doc that generated this expense; travels
                                # with sourceType (both present or both absent)

  subscriptions/{subscriptionId}
    name: string, amount: number, dueDay: int (1-31)
    createdAt: string (ISO date)
    lastChargedDate: string?   # ISO date of the last due date already turned
                                # into an expense by catchUpSubscriptions
    categoryId: string?        # envelope the charge comes out of; absent = account

  installmentPurchases/{purchaseId}
    name: string, totalAmount: number, installments: int (2-36)
    purchaseDate: string (ISO date)     # informational only
    firstChargeDate: string (ISO date)  # anchors every monthly occurrence
    createdAt: string (ISO date)
    chargedInstallments: int  # 0..installments; how many have already been
                                # turned into an expense by
                                # catchUpInstallmentPurchases
    categoryId: string?        # envelope the charges come out of; absent = account
    amortizedAmount: number?   # paid ahead of the schedule; absent = 0.
                                # Shortens the TERM, not the installment

  meta/account            { balance: number }   # overall account balance (derived)
  balances/{categoryId}   { balance: number }   # each envelope's balance (derived)
```

`meta/account` and `balances/{categoryId}` are a **derived cache**, not
source of truth: they are not part of the JSON backup and are recomputed from
the ledger (the six collections above) both on restore
(`FirestoreService.replaceAll`) and by the backfill script. The balances
shown on screen are always summed from the ledger by
`aggregation_service.dart` — even if the cache ever drifted, the UI would
still show the truth. They exist only so Security Rules can validate in O(1)
(rules cannot sum a whole collection). See `docs/BACKEND.md` for the full
rationale, the guaranteed invariants, and this design's known limitations.

`Category.kind`, `monthlyBudget`, `goalAmount`, `allowNegative`, and
`Allocation.transferId` are all optional fields added after the original
schema — an old JSON backup without them still imports unchanged.
`subscriptions` is a whole new collection added the same way — an old backup
with no `subscriptions` key imports as an empty list. `installmentPurchases`
is a second such addition, right after it. `Expense.sourceType`/`sourceId`
follow the same rule: an expense exported before they existed imports as a
manual expense, with neither field invented on the way back in. `categoryId`
(on both new collections) and `amortizedAmount` are the most recent additions,
same design: absent means "comes out of the account" and "nothing paid ahead",
which is exactly how the older docs already behaved.

## Technical decisions and why

- **Writes go straight from the client to Firestore, with no backend of its
  own.** There's no intermediary API — `FirestoreService` writes directly,
  and money integrity is guaranteed by Firestore Security Rules
  (`firestore.rules`), not by a trusted server. This is the "Option B"
  documented in `docs/BACKEND.md`, chosen to stay on Firebase's free tier
  (Spark) — the Cloud Functions alternative (`functions/`, paid Blaze tier)
  exists as inactive reference only, not deployed.

- **A subscription only ever charges when the app is opened, never on a
  server schedule.** `FirestoreService.catchUpSubscriptions` runs once per
  signed-in session and backfills every due date a subscription has missed,
  oldest first, straight from the account — but nothing runs while the app is
  closed. The alternative (Cloud Scheduler + Cloud Function charging exactly
  on the due day) would require the same paid Blaze plan declined for Option
  A above, for the same reason. See `docs/BACKEND.md`, "Subscriptions
  (recurring expenses)".

- **An installment purchase reuses the exact same catch-up machinery as a
  subscription, just bounded.** `catchUpInstallmentPurchases` shares
  `dueDateFor`'s month-clamping with `catchUpSubscriptions` and follows the
  identical client-triggered-on-app-open model — the only structural
  difference is that it stops once `chargedInstallments` reaches
  `installments`, instead of running forever. The rounding remainder from
  splitting `totalAmount` into equal slices always lands on the LAST
  installment (matches a real card bill), computed once per purchase via
  `installmentAmounts`, never re-derived per charge (so a value never drifts
  across catch-up runs).

- **All of catch-up's date math lives outside `FirestoreService`, in
  `lib/services/recurring_schedule.dart`.** Pure functions (no Firestore, no
  I/O), like `aggregation_service.dart`. The reason: two consumers need the
  same answer and must not disagree — catch-up, which turns each due
  occurrence into an `Expense`, and the Gastos screen, which shows how many
  occurrences are still PENDING. If the screen re-derived "pending" with its
  own copy of that math, the warning could claim something catch-up would
  never do.

- **Catch-up re-reads the doc INSIDE the transaction before charging.**
  Without it, two simultaneous sessions (phone + web, or two tabs) bill the
  same occurrence twice: the `get()` that lists subscriptions happens outside
  the transaction, and a Firestore retry only re-runs the body against what
  the transaction itself read — the object captured outside stays stale, so
  the retry re-bills the month the other device just billed. Re-reading in
  there fixes both halves: it puts the doc in the read set (so the race is
  detected as a conflict) and the retry then sees the already-bumped
  `lastChargedDate`/`chargedInstallments` and backs off. The attempt's result
  comes back as a `_ChargeOutcome` rather than an exception, so "already
  charged" and "didn't fit the balance" are no-op transactions instead of
  control flow through `StateError` — the same type the real validation
  failures use.

- **A charge that didn't fit the balance is visible on screen, not silent.**
  Catch-up stops at that occurrence and retries later (it never overdraws the
  account), but until this existed, a subscription that hadn't charged for
  months was indistinguishable from a paid one. The Gastos screen counts what
  is pending with `recurring_schedule.dart`'s functions and shows it per row
  and per card — and only once catch-up has finished, because before that
  "pending" doesn't mean anything yet (see `recurringChargesCatchUpProvider`,
  which now surfaces a failure as an `AsyncError` instead of swallowing it).

- **Subscriptions and installment purchases are top-level destinations, and
  on mobile ALL navigation lives in a single menu.** They used to be two
  cards at the bottom of `GastosPage`, AFTER the expense list — which is
  unbounded, so in practice they were unreachable.

  Promoting them made seven destinations, and seven don't fit a
  `NavigationBar` (five is the ceiling: past it labels truncate and targets
  shrink). Two attempts preceded the current shape, both recorded here
  because they explain it:

  1. Bar with five plus the logo in a sixth slot. Six slots gave ~63px each
     and "Assinaturas" wrapped mid-word on a real phone.
  2. Bar with five plus the logo in the app bar. It fit, but it drew an
     arbitrary line between "daily" and "management" screens, and the user
     had to learn which side each one was on.

  3. No bar, with the menu in the app bar. That fixed the seam, but the app
     bar showed the screen's name and the page body showed the SAME name one
     line below — "Dashboard" twice.

  The current shape has neither seam nor repetition: on narrow screens there
  is no bottom bar AND no app bar. The page's own title (`PageHeader`) grows
  a chevron and opens a menu with all SEVEN destinations, dropping down from
  the top over a dimmed background — the motion points back at what you
  tapped. What you read is what you tap, and the screen's name appears once. As a bonus it ends the label problem outright — a vertical
  list gives every name full width, so nothing truncates or needs abbreviating
  ("Assinaturas" and "Parcelamentos" went back to their full forms). The cost
  is honest: navigating is two taps.

  `AppShell` hands the menu to the screens through an `InheritedWidget`
  (`AppNavigation`), so each page's title can be the trigger without the page
  knowing how navigation works. On wide screens that callback is null and the
  same `PageHeader` renders as a plain title.

  A wheel spun from the logo was considered and declined: nothing about it
  says it spins, it's awkward with a mouse (the live platform is the web),
  and it would need considerable work to be reachable by a screen reader. A
  list in a sheet is all three for free, and still opens from the logo.

  None of this applies on wide screens: the `NavigationRail` is a vertical
  list and fits all seven. The top of Gastos kept the **how much of the month
  is already committed** figure (`committedThisMonth`), now as information
  only.

- **A charge can come out of the account or an envelope (`categoryId`).**
  `_readChargeSource` mirrors `createExpense`'s two branches exactly,
  `allowNegative` via `_catDeltaOk` included: a generated charge is allowed
  if and only if the same expense typed by hand would be. Only `spend`
  envelopes are offered — a `save` one is a savings goal, and draining it
  monthly works against the reason it exists (it also can't go negative, so
  it would just fail at charge time). If the envelope is deleted the charge
  stays pending with a warning and **never** silently falls back to the
  account: taking money from somewhere the user didn't choose would be worse
  than not charging.

- **Paying ahead shortens the TERM, not the installment
  (`amortizedAmount`).** Paying extra one month, or settling in full, cuts
  the outstanding balance and the purchase simply ends sooner — the
  installment keeps its size. The amount paid ahead is its own running total
  rather than a rewrite of `totalAmount`/`installments`, which are immutable
  in the rules on purpose (they are what `chargedInstallments` is counted
  against; rewriting them would desync progress from what was actually
  billed). The outstanding balance — not the installment counter — is what
  says whether it's over, and the final charge is clamped to what remains so
  it can never bill past the debt.

- **A generated expense knows where it came from (`sourceType`/`sourceId`).**
  Same idea as `Allocation.transferId`: pair the rows by an id instead of
  adding a new collection. Without it, an expense generated by a subscription
  is indistinguishable from a manual one with the same description — the app
  can't say what a subscription has cost so far, nor notice that the user
  deleted a charge by hand. Both fields are immutable in the rules once
  created: an edit can't plant, strip, or repoint the link.

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

- **Theme and language are DEVICE preferences, not user data in Firestore.**
  They describe how this screen should look, not anyone's money — and keeping
  them in the ledger would mean they couldn't apply until after sign-in,
  which is exactly when the wrong theme is most jarring. They live in
  `shared_preferences`, read in `main()` BEFORE `runApp`: an async provider
  would paint the default and then swap, the flash this design exists to
  avoid. An unknown value (never chosen, or written by a future build)
  degrades to "follow the system", which is always a sane answer.

- **A single breakpoint (720px) reused across all responsive
  navigation/forms**, instead of a per-screen value: `AppShell` (side rail
  vs. single menu), `showAdaptiveFormSheet` (dialog vs. bottom sheet for
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
`widgets/*_test.dart`, and `test/rules/` — a standalone Node harness (not
part of the Flutter/pubspec tree) with two files run together via `npm test`:
`rules.test.mjs` (the Firestore rules against the emulator — the only way to
exercise the `getAfter()`/genesis-teardown paths, which don't run from Dart)
and `backfill.test.mjs` (regression coverage for
`scripts/backfill_balances.mjs`'s debt-vs-corruption classification, run as a
real subprocess). See `docs/DEPLOY.md` for how this runs in CI.
