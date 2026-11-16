# Architecture

**[Leia em Português](ARQUITETURA.pt-br.md)**

How Dindin works internally. For what the app is and how to run it locally,
see `README.md`; for the money-integrity model (Firestore rules,
denormalized balances) see `docs/BACKEND.md`; for the visual identity see
`docs/DESIGN.md`; for open items and what is not yet verified on a real device
see `docs/PENDENCIAS.md`.

Describes version **1.2.1+7** (sent to Google Play on 2026-11-16, awaiting
review at the time of writing). Everything below was checked against the code
and the test suite (715 Flutter tests pass; the rules harness has 128 + 9
tests, see "Tests"). Things only exercised in tests or an emulator, never on a
real device, are flagged as such.

## Layers

```
lib/
  main.dart            bootstrap: Firebase.initializeApp, App Check, intl pt_BR,
                       loads the saved locale and theme, runApp(SplashGate(DindinApp))
  app.dart              MaterialApp.router: theme (light/dark, themeMode from
                        themeModeProvider) + go_router (7 shell branches)
  theme/                visual identity ("Warm Envelope", see docs/DESIGN.md)
    colors.dart         AppPalette — hardcoded color tokens (light/dark)
    theme.dart          ColorScheme + TextTheme + AppTokens (ThemeExtension)
  models/               plain data classes (no Firestore logic); also
                        tutorial_progress.dart (TutorialPage/State/Entry + versions)
  services/
    auth_service.dart          email/password login + Google (web and native diverge),
                               account deletion, hasRecentLogin
    firestore_service.dart     CRUD + money integrity (transactions), catch-ups,
                               restore/delete-all, tutorial progress
    aggregation_service.dart   pure functions: balances, monthly summaries
    recurring_schedule.dart    pure functions: which subscription/installment
                               charges are due (shared by catch-up and the
                               screen, so the two can't disagree)
    import_export_service.dart JSON backup/restore (+ backup_validation.dart,
                               restore_chunking.dart)
    analytics_service.dart     Firebase Analytics wrapper (opt-out, no money data)
    app_update_service.dart    Google Play in-app (flexible) update
  providers/
    providers.dart       Riverpod providers, wire services -> UI (incl. the
                         tutorial progress providers and todayProvider)
    locale_provider.dart / theme_provider.dart   language and theme choice,
                         persisted in shared_preferences
  features/<name>/<name>_page.dart   one folder per screen
                       (assinaturas/ and parcelamentos/ are top-level
                        destinations — see the navigation decision below;
                        settings/ also holds tutorials_card.dart)
  widgets/              components shared across screens: app_shell.dart
                        (navigation), splash_gate.dart (opening animation),
                        quick_entry_sheet.dart, guided_empty_state.dart,
                        nav_menu_state.dart, menu_chevron.dart,
                        catch_up_refresh.dart, tutorial/ (the onboarding engine)
```

## Data flow / state management

Riverpod (`flutter_riverpod`) is the single source of state — there's no
second mechanism (no global `setState`, no separate store). The data path:

1. `FirestoreService` exposes streams per collection. There are two flavors
   of the three ledger collections: **windowed** (`watchIncomes`,
   `watchAllocations`, `watchExpenses`: ordered by `date` desc, `.limit(2000)`,
   they feed the Receitas/Gastos/Parcelamentos lists) and **full**
   (`watchAllIncomes`, `watchAllAllocations`, `watchAllExpenses`: no limit,
   they feed only the Dashboard summary). Categories, subscriptions and
   installment purchases are capped at 500 docs. Each is a Firestore
   `snapshots()` mapped to the matching Dart model.
2. `providers.dart` wraps each stream in a `StreamProvider`
   (`categoriesProvider`, `incomesProvider`, `allIncomesProvider`, etc.), gated
   by `firestoreServiceProvider` (which is `null` while signed out —
   `authStateProvider` decides that).
3. `summaryProvider` (a plain `Provider`, not a stream) combines categories +
   the three **full** ledger streams into an `AppDb` and calls
   `aggregation_service.buildSummary(db)` —
   **pure** functions (no I/O, easy to test in isolation; see
   `test/services/aggregation_service_test.dart`) that compute the account
   balance, per-envelope balance, current-month summary, and monthly history.
4. Screens (`features/**`) only do `ref.watch(summaryProvider)` /
   `ref.watch(categoriesProvider)` etc. — they never read Firestore directly.

In other words: **Firestore stream → provider → pure aggregation → UI**,
always in that direction. The Dashboard balance is therefore **re-summed from
the whole ledger on every change**, not read from the denormalized balance
docs (those exist only for the rules, see `docs/BACKEND.md`, "Dashboard balance
re-sums the ledger"): correct by construction, at the price of reading the
entire history of the account on each session. This mirrors the old `/api/summary` endpoint from
an earlier Next.js version of the app (removed from the repo — commits
`d774ffb`/`135d006`); `aggregation_service.dart` and several models still
cite that history in comments ("mirrors X in the Next.js app's..."), kept
because they explain *why* the schema has the shape it has, not because the
Next.js app still exists anywhere in the repo.

## End-to-end traces

Three operations, traced through every layer they cross, naming the real files
and functions at each hop. They're picked because they trigger in genuinely
different ways — one from an explicit tap, one from just opening the app, and
one from first visiting a page (Trace C, which reads and writes only UI state) —
but the first two converge on the exact same read/update mechanism once the
write lands, which is the thing worth seeing spelled out once instead of
assumed to generalize.

### Trace A — creating a gasto (caixinha expense), user-initiated write

1. **Tap.** On the Gastos screen (`lib/features/gastos/gastos_page.dart`),
   the user picks a caixinha (or "Conta"), types an amount, and taps submit
   — `_GastosPageState._submit()`.
2. **Client-side pre-check.** `_submit` first calls
   `_blockedByFrozenDebt(categories, availableBalance)` to disable the
   button early with a friendly message if the chosen caixinha is a frozen
   debt that can't take more spending — a UX shortcut, not the real guard.
3. **Provider → service.** It reads `ref.read(firestoreServiceProvider)`
   (`null` while signed out) and calls
   `FirestoreService.createExpense(date:, amount:, categoryId:, description:)`
   (`lib/services/firestore_service.dart`).
4. **Transaction.** `createExpense` runs a Firestore `runTransaction`: reads
   the target balance doc (`users/{uid}/meta/account` if `categoryId` is
   null, else `users/{uid}/balances/{categoryId}`), throws `StateError`
   client-side if the amount would overdraw it (mirroring `_catDeltaOk`),
   then writes BOTH the new `users/{uid}/expenses/{id}` doc and the
   decremented balance doc in the same transaction.
5. **Server validation.** `firestore.rules`' `expenses` `allow create` rule
   re-checks `validExpense(...)` and, via `getAfter()`, that the linked
   balance doc moved by exactly the expense amount and stayed within its
   floor (`catDeltaOk`) — see `docs/BACKEND.md`, "Option B — what is
   implemented". This is the actual security boundary; step 4's check is
   only a faster error message for the honest client.
6. **Error path.** Any `StateError` from step 4, or a `permission-denied`
   `FirebaseException` from step 5, is caught in `_submit`'s `catch` and
   turned into a localized string by `friendlyErrorMessage`
   (`lib/utils/errors.dart`), shown inline under the form. Nothing is
   written on failure.
7. **Read side reacts automatically.** The commit fires the
   `users/{uid}/expenses` and `users/{uid}/balances/{categoryId}` (or
   `meta/account`) listeners that `FirestoreService.watchExpenses()` (and
   the categories/allocations/incomes streams already open) are subscribed
   to. `providers.dart`'s `expensesProvider` `StreamProvider` re-emits.
8. **Aggregation.** `summaryProvider` (`providers.dart`), watching categories
   plus the three full (unwindowed) ledger streams, recombines them into an `AppDb` and calls
   `aggregation_service.buildSummary(db)` — pure, no I/O — to recompute the
   account balance, the caixinha's balance, and the current-month summary.
9. **UI updates.** Both `GastosPage` (the expense now in its list, the
   caixinha's remaining balance) and `DashboardPage`
   (`lib/features/dashboard/dashboard_page.dart`, `ref.watch(summaryProvider)`)
   rebuild with the new numbers — with no explicit "refresh" call anywhere;
   `ref.watch` is what makes step 7's stream emission reach both screens.

### Trace B — subscription auto-charge, session-triggered write (not a tap)

Genuinely different starting point: nothing here is triggered by the user
pressing a button on this screen — it runs once whenever a signed-in session
starts, from whichever screen that happens to be.

1. **App open, not a tap.** `AppShell` (`lib/widgets/app_shell.dart`) calls
   `ref.watch(recurringChargesCatchUpProvider)` on every build — since a
   `Provider` only re-runs its body when its own dependencies change, this
   fires exactly once per sign-in, regardless of which screen `AppShell`
   happens to be showing.
2. **Provider → service.** `recurringChargesCatchUpProvider`
   (`lib/providers/providers.dart`) reads `firestoreServiceProvider` and
   calls `FirestoreService.catchUpSubscriptions()` then
   `.catchUpInstallmentPurchases()`, in that order.
3. **Date math, kept out of the service.** `catchUpSubscriptions` asks
   `lib/services/recurring_schedule.dart` which due dates each subscription
   has missed since `lastChargedDate` — pure functions, the same ones the
   Gastos screen uses to show what's still pending, so the two can never
   disagree (see `docs/BACKEND.md`, "A pending charge is shown, not
   hidden").
4. **One transaction per due date.** For each missed month, oldest first,
   `_chargePendingDueDates` runs a transaction that RE-READS the
   subscription doc (guards against a second concurrent session
   double-charging — see `docs/BACKEND.md`, "Two sessions at once do not
   double-charge"), then writes a new `users/{uid}/expenses/{id}` doc
   (tagged `sourceType: 'subscription'`, `sourceId`) plus the same
   account/`balances/{categoryId}` update as Trace A's step 4 — the exact
   same balance gate, since a generated charge must be allowed if and only
   if the same expense typed by hand would be. An occurrence that doesn't
   fit the balance is skipped, not thrown — retried on the next session.
5. **Server validation.** Same `firestore.rules` path as Trace A step 5 —
   there's no separate rule for a generated expense; `sourceType`/`sourceId`
   are additionally checked as immutable-once-set (`sameExpenseSource`).
6. **Read side reacts — same mechanism as Trace A.** Each committed charge
   is just another write to `users/{uid}/expenses` and a balance doc, so it
   reaches `watchExpenses()` → `expensesProvider` → `summaryProvider` →
   `DashboardPage`/`GastosPage` exactly as in Trace A, steps 7-9 — no
   special-casing for a generated charge anywhere in the read path.
7. **A second, independent UI reaction — not through Firestore.** Back in
   `AppShell`, `ref.listen<AsyncValue<RecurringChargeReport>>(...)` (not
   `ref.watch`) fires once the `FutureProvider` itself resolves, and shows a
   `SnackBar` naming what was just charged. This is the one part of the
   trace that does NOT go through a Firestore stream — the app tells the
   user proactively, from the provider's own result, because these charges
   happen with no interaction at all and a quiet row appearing in a list
   the user may not open would otherwise be the only trace of it.
8. **Failure is visible, not swallowed.** If step 4 itself throws (not an
   unaffordable due date, an actual failure), `recurringChargesCatchUpProvider`
   logs it and rethrows, landing as an `AsyncError` on the provider instead
   of being silently eaten — the Gastos screen tells "catch-up hasn't run
   yet" apart from "catch-up ran and this genuinely doesn't fit" using that
   error state (see `docs/BACKEND.md`, "A pending charge is shown, not
   hidden").

### Trace C — first visit to a page: the onboarding tutorial

A third kind of start: nothing is tapped and nothing is written by the user,
yet a Firestore document is read and later written. Traced for the Dashboard
on a narrow screen (the one page with the "guided by the action" step).

1. **Page is ready.** `DashboardPage.build`
   (`lib/features/dashboard/dashboard_page.dart`) shows a spinner until
   `summaryProvider` and `categoriesProvider` have data, then wraps its content
   in `TutorialHost(page: TutorialPage.dashboard, steps: _tutorialSteps, ...)`
   (`lib/widgets/tutorial/tutorial_host.dart`). The host is only built once the
   data is there, so a tutorial never starts over a spinner or an error.
2. **Is it seen?** `TutorialHost.build` watches
   `tutorialSeenProvider(page)` (`providers.dart`). That provider is `null`
   until `tutorialProgressProvider` has loaded (a `StreamProvider` over
   `FirestoreService.watchTutorialProgress()`, i.e. the snapshots of
   `users/{uid}/meta/tutorials`, parsed by `parseTutorialProgress`); `true` if
   the page is in `tutorialSessionSeenProvider` (what ended during THIS
   session) or if the saved entry's version covers
   `tutorialVersions[page]` (`TutorialEntry.covers`); `false` otherwise.
   `null` means "don't know yet" and starts nothing — otherwise the tutorial
   would flash before the saved state arrives.
3. **Wait for a calm moment.** On `false`, the host schedules `_tryStart` after
   400 ms. `_calm` requires: this tab is the visible one (`TickerMode`), no
   dialog or sheet on top (`ModalRoute.isCurrent`), the page menu is closed
   (`navMenuOpen`, a `ValueNotifier` set by `AppShell._openMenu`, because that
   menu is a dialog on the ROOT navigator and the page's own route can't see
   it), and the keyboard is closed. Not calm: retry every 600 ms, at most 30
   times, then give up quietly. When the menu closes, the host listener restarts
   the attempts from zero.
4. **Show.** `showTutorial` (`tutorial.dart`) pushes a `PopupRoute` on the root
   navigator. `_TutorialScreen` finds each step's widget through its
   `GlobalKey` (`TutorialStep.target`), scrolls it into view, paints the veil
   with a cut-out and the balloon (placed below, above, or at the bottom
   without an arrow), and re-measures on rotation/resize/keyboard. Step 1 of
   the Dashboard targets the page title (narrow) or the side rail (wide, via
   `AppNavigation.railKey`); on narrow screens its `onTargetTap` is the real
   `openMenu`, so tapping the lit-up title opens the actual menu and ends the
   tutorial as done.
5. **Outcome.** Next/Done → `TutorialResult.done`; Pular, Esc or the system
   back → `skipped`; a target that isn't mounted (a lazily built list far
   below the fold) → `unavailable`.
6. **Record.** `done`/`skipped` call `markTutorialEnded` (`providers.dart`),
   which first adds the page to `tutorialSessionSeenProvider` (so it can't
   return in this session even if the write fails), then
   `FirestoreService.setTutorialProgress` does
   `meta/tutorials.set({page: {state, v}}, merge: true)`. `unavailable` records
   nothing, so it tries again next time the page opens. A failed write is only
   logged (`dindin.tutorials`).
7. **Server validation.** `firestore.rules`' `meta/{docId}` rule accepts
   `tutorials` only through `validTutorials`: a closed list of the seven page
   ids, each `{state: 'done'|'skipped', v: int 1..1000}` — see
   `docs/BACKEND.md`.
8. **Every other reader reacts.** The `meta/tutorials` listener emits on the
   other devices and in Ajustes, so `tutorialSeenProvider` flips to `true`
   there with no extra call.
9. **Review.** Ajustes → Tutoriais (`lib/features/settings/tutorials_card.dart`)
   reads the same providers. "Rever" calls `resetTutorial` (removes the page
   from the session set and writes `FieldValue.delete()` for that key) and
   `context.go(route)`; the page's host sees `seen == false` and runs from
   step 2. "Rever todos" calls `resetAllTutorials` (`meta/tutorials.delete()`),
   with a snackbar "Desfazer" that calls `restoreTutorials` (rewrites each
   previous entry, with its original version).

Verification status: all of this is covered by widget tests and by 6 rules
tests against the emulator; **it has not been seen on a real device** (see
`docs/PENDENCIAS.md`).

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
    autoChargeEnabled: bool?   # stored only when false; absent = true. When false,
                                # catch-up skips it and it is posted by hand
                                # ("Cobrar agora", chargeSubscriptionNow)

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
    dueDayOverride: int?       # day (1-31) the REMAINING installments fall due;
                                # absent = firstChargeDate's own day

  meta/account            { balance: number }   # overall account balance (derived)
  balances/{categoryId}   { balance: number }   # each envelope's balance (derived)
  meta/settings           { analyticsOptOut: bool }   # Ajustes -> Privacidade
  meta/tutorials          { <page>: { state: 'done'|'skipped', v: int } }
                          # <page> in dashboard|receitas|gastos|assinaturas|
                          # parcelamentos|categorias|ajustes. UI state, not money

accountDeletionLog/{autoId}   # TOP-LEVEL, not under users/{uid}; create-only,
  { deletedAt: serverTimestamp, origin: 'self-service'|'admin-sweep' }
```

`Income` and `Expense` also carry an optional `createdAt` (ISO timestamp), used
only to break ties between rows of the same `date`
(`_sortByDateThenCreatedAt`). `meta/settings` and `meta/tutorials` are not part
of the JSON backup either (they are per-account app state), and
`deleteAllUserData` removes both together with the balance docs.

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

- **`recurring` (the "Recurring (repeats every month)" checkbox) was purely a
  display label until it ALSO became the switch that decides what
  `goalAmount` means on a `save` envelope.** With no goal, or with
  `recurring: false`, nothing changes — a goal is a cumulative target (the
  original behavior), and with no goal the envelope still shows
  `CaixinhaSavedThisMonth`. With a goal AND `recurring: true`
  (`Category.hasMonthlyGoal`), that same `goalAmount` is read as a MONTHLY
  target instead: the bar (`CaixinhaGoalBar` with `monthly: true`) uses
  `savedThisMonthByCategory` instead of the envelope's all-time balance.

  There's no explicit reset — no job, no "zeroed on X" field written to
  Firestore. `savedThisMonthByCategory` was already a live query filtered by
  month (`monthKey(date) == currentMonthKey()`), so day 1 "resets" on its own
  simply because no allocation is dated in the new month yet — even if the
  user never opens the app that day. The envelope's all-time balance
  (`categoryBalances`, the big number at the top of the row) never enters
  that calculation and keeps accumulating underneath, untouched.

  The reset day is always the calendar's day 1 — not configurable per
  envelope (unlike a subscription's `dueDay`). Deliberate call: the original
  ask considered a per-envelope day, but the payoff didn't seem to justify
  the cost (a new schema field, migrating `savedThisMonthByCategory` to a
  30-day window anchored on an arbitrary day instead of the calendar month)
  against "fixed day 1" already covering the real use case.

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

- **Onboarding is a small engine plus per-page hosts, not a package.**
  `lib/widgets/tutorial/tutorial.dart` (`showTutorial`, `TutorialStep`,
  `TutorialResult`) draws one step at a time over the real screen: veil with
  cut-out, ring, balloon shaped like the brand manual's step card; reduced
  motion and screen-reader announcements are handled in the route.
  `tutorial_host.dart` decides WHEN to start (see Trace C). Seven pages have a
  tutorial (Dashboard 4 steps, Ajustes 2, the other five 3 each). Progress
  lives in `meta/tutorials` so it follows the account across devices; each
  page has a version number (`tutorialVersions` in
  `lib/models/tutorial_progress.dart`) — bumping it re-shows that one tutorial
  to people whose saved version is lower. The page ids are a closed list that
  must match `validTutorials` in `firestore.rules`. Known limit: a step's
  target must be mounted; a widget in a lazily built list far below the fold
  ends the tutorial as `unavailable` (not recorded). The design rationale and
  the rejected alternatives (direction "Etiqueta") are in
  `docs/onboarding-design.md`.

- **Empty states and the Dashboard "Primeiros passos" card teach the next
  action.** `GuidedEmptyState` (`lib/widgets/guided_empty_state.dart`:
  illustration, title, text, one verb button) replaces the plain empty text on
  Receitas, Gastos, Assinaturas, Parcelamentos and Categorias; an empty list
  caused only by a date filter keeps the plain text with "Limpar filtro". The
  Dashboard's `_FirstStepsCard` (create a caixinha, add an income, allocate)
  disappears once all three are true (`categories.isNotEmpty && hasIncome &&
  hasAllocation`; transfers don't count as allocations). Ajustes → Tutoriais
  shows the terracotta wax seal (`assets/illustrations/dindin-selo.svg`) and
  collapses the list when all seven are seen.

- **Navigation was made discoverable without changing its shape.** The
  page-title chevron is a tonal circle (`MenuChevronChip`, 48 dp touch area),
  each menu row has a one-line description (`navXxxDescription` strings), and
  the Dashboard has "Lançar receita"/"Lançar gasto" buttons. Those two open
  `showQuickEntrySheet` (`lib/widgets/quick_entry_sheet.dart`): the same form
  as Receitas/Gastos in a bottom sheet (dialog on wide screens), saving through
  the same `createIncome`/`createExpense` (Trace A applies), then closing
  without leaving the Dashboard. The earlier "open the page with the cursor in
  Valor" mechanism (`focus_request`) was removed.

- **Theme: Sistema / Claro / Escuro, chosen in Ajustes.** `themeModeProvider`
  (`lib/providers/theme_provider.dart`) has the same shape as
  `localeProvider`: `main()` loads the saved value (`shared_preferences`, key
  `themeMode`) before `runApp` and overrides the provider, `app.dart` passes it
  to `MaterialApp.themeMode`, Ajustes writes it with `setThemePreference`
  ("Sistema" removes the stored key). A storage failure only costs persistence.
  The official dark background is `#16130F` (`AppPalette.darkBackground`),
  cards `#201C17`; tokens are in `lib/theme/colors.dart` and described in
  `docs/DESIGN.md`. The theme is stored on the device, not in Firestore.

- **Opening animation (`SplashGate`, `lib/widgets/splash_gate.dart`).** Wraps
  `DindinApp` in `main()` (so widget tests of the app never see it). For
  1.5 s an overlay plays on top of the already-building app: the logo bag at
  normal size, three coins fall in and shake it, then it zooms toward the
  viewer while fading out. Background follows the chosen theme (in "Sistema",
  the device's brightness, read from `platformDispatcher`); skipped entirely
  when the OS asks for reduced motion. It absorbs touches and is excluded from
  the screen reader. Limit: before Flutter's first frame the native window is
  still white/black, so a flash is possible. Verified in tests (715 pass) and
  by video review; **not on a real device**.

- **Writes that don't need a transaction don't wait for the server offline
  (`FirestoreService.ackOrQueue`).** A plain Firestore write's future completes
  only on the server ack, so offline a save button would spin until the
  connection returns. `ackOrQueue` waits up to 4 s (`writeAckWait`), then treats
  the write as queued (Firestore keeps it in its local queue and sends it on
  reconnect). A real failure inside the window (a rules denial) still throws;
  after the window it can't be reported. Used by `createCategory`,
  `updateCategory`, `createSubscription`, `deleteSubscription`,
  `setSubscriptionAutoCharge`, `createInstallmentPurchase` and
  `deleteInstallmentPurchase`. Transactions (money writes) are unchanged: they
  fail at once offline.

- **`deleteCategory` refuses three situations before touching anything.**
  A caixinha that took part in a transfer (the paired leg would be orphaned and
  `meta/account` would rise above the ledger); a negative balance (the debt must
  be settled first, mirrors `catDebtFree`); and a cascade larger than 495
  records (`FirestoreService.maxCascadeDocs`: one transaction holds at most 500
  writes and it can't be split because the rules read it as one commit). The
  Categorias screen also disables the remove button up front for the first two,
  with an explanation.

- **Deleting the account checks for a recent login BEFORE wiping data.**
  `SettingsPage` calls `AuthService.hasRecentLogin()` (reads `auth_time` from
  the ID token, 4-minute margin under Firebase's ~5-minute window) first; a
  stale session shows "sign out and in again" and nothing is deleted. Previously
  the Firestore data was wiped first and `user.delete()` failed afterwards,
  leaving a live, empty account. Order after the check: `deleteAllUserData()`
  (balance docs + settings + tutorials + one anonymous `accountDeletionLog`
  entry in the first commit, then the ledger) and last `AuthService.deleteAccount()`.

- **Edits add the delta in one step, like the rules.** `updateIncome`,
  `updateAllocation` and `updateExpense` compute `balance + (new - old)`, never
  `(balance - old) + new`: the rules compare with exact `==` and the two
  differ in the last bit for some values, which used to cause occasional
  `permission-denied` on a legitimate edit (confirmed on the emulator; 9 rules
  tests pin the parity).

- **"This month" is the device's local month.** `currentMonthKey()`
  (`aggregation_service.dart`) uses local time, the same clock as ledger dates;
  UTC made the Dashboard flip to the next, empty month at 21:00 on the last day
  in Brazil. The `now` parameter is injectable for tests.

- **Coming back from the background re-evaluates "today".** `AppShell` observes
  the app lifecycle; on `resumed` it re-checks Play for an update and, if the
  calendar day changed since `todayProvider` was read, invalidates
  `todayProvider` and `recurringChargesCatchUpProvider` (at most once per day),
  so an app left open for days still posts due charges and shows correct
  "pending" counts. Pull-to-refresh (`CatchUpRefresh`) re-runs the catch-up on
  demand.

- **Catch-ups don't let one bad document block the rest.** Each subscription is
  tried inside its own `try`; `recurringChargesCatchUpProvider` runs the
  installment catch-up even if the subscription one failed, and rethrows the
  first error at the end so the provider still ends as `AsyncError` (the Gastos
  screen keeps telling "never finished" apart from "didn't fit the balance").
  A subscription with `autoChargeEnabled == false` is skipped by catch-up and
  posted only through "Cobrar agora".

- **Play in-app update never restarts the app by itself.**
  `AppUpdateService` (`lib/services/app_update_service.dart`) does a flexible
  update: `startUpdate` resolves true only when Play reports `downloaded`, then
  `AppShell._startUpdate` shows a snackbar with "Reiniciar" and
  `restartToInstall` runs only on that tap (the user may be mid-entry). A fixed
  indicator (badge on the menu trigger, "Atualizar" entry in the menu, button in
  the wide rail) stays while an update exists and is re-checked on resume.
  Everywhere except an Android install from Play, every call quietly answers
  "no update". Tested with a fake service; **the real plugin flow only runs on a
  Play-installed build and has not been observed** (the dot indicator in the
  menu has not been seen on a device either).

## Known constraints / open items (not invented — verified in the code)

- **Editing a single allocation exists in code but isn't reachable from the
  UI.** `EditableAllocation` (`lib/widgets/edit_transaction_sheet.dart`) can
  only be constructed for a non-transfer allocation, but there's currently no
  allocation list in the UI that invokes it — the comment in the file itself
  already flags that this exists ready "pra quando uma lista de allocations
  for adicionada" (for when an allocation list gets added). Not an
  accidental gap.

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

- **Converting a negative `spend` envelope to `save`, or deleting it, is now
  guarded in the app** (this item used to be open). `updateCategory` refuses
  the spend → save conversion while the balance doc is negative, and
  `deleteCategory` refuses a negative balance; the Categorias screen disables
  the remove button with an explanation. The server rules (`catDebtFree`,
  `convertsSpendToSave`) remain the non-bypassable guarantee.

- **`lib/main.dart`'s App Check comment is out of date.** It says the app "is
  NOT in the Play Console yet"; the app is published. Behavior is unchanged
  (Play Integrity in release, debug provider in debug, web skipped until a
  reCAPTCHA v3 key exists). Comment-only fix, left for whoever next touches
  `lib/`.

- **`lib/widgets/app_shell.dart` cites `FLUTTER_MIGRATION.md` in a comment**
  ("see §4 of FLUTTER_MIGRATION.md") — that file no longer exists in the repo
  (the Next.js migration was completed and its docs removed, see the `git
  log` history around `d774ffb`/`135d006`). TODO: confirmar whether that
  comment should be updated/removed from the code, or was left intentionally
  as historical reference — not something this document decides on its own.

## Tests

`flutter test` runs 715 tests (all passing on 2026-11-16 when this was
written). `test/` mirrors the structure of `lib/`: `features/*_test.dart`
(widget tests per screen, including `layout_sweep_test.dart`, which renders
every screen at 320-900 px, text scale x1.3, in pt and en to catch overflow,
and the tutorial/empty-state/navigation tests), `services/*_test.dart` (incl.
`aggregation_service_test.dart` for the money math, `auth_service_test.dart`,
`tutorial_progress_test.dart`), `providers/*_test.dart` (locale, theme,
recurring catch-up), `models/*_test.dart` (JSON backup round-trip),
`utils/*_test.dart`, `widgets/*_test.dart` (shell, tutorial engine, quick
entry, splash), and `test/rules/` — a standalone Node harness (not part of the
Flutter/pubspec tree) with two files run together via `npm test`:
`rules.test.mjs` (128 tests of the Firestore rules against the emulator — the
only way to exercise the `getAfter()`/genesis-teardown paths, which don't run
from Dart) and `backfill.test.mjs` (9 tests of
`scripts/backfill_balances.mjs`'s debt-vs-corruption classification, run as a
real subprocess). The rules counts were read from the files; the harness was
not run for this documentation pass. See `docs/DEPLOY.md` for how this runs in
CI. There are no automated tests on a real device or against the real Play
in-app update plugin.
