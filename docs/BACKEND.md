# Backend / data-integrity notes

**[Leia em Português](BACKEND.pt-br.md)**

Operational reference for Dindin's Firestore backend. Read this before any
deploy that touches `firestore.rules`, `firestore.indexes.json`, or `functions/`.

## Deploy gate: back up production data FIRST (mandatory, human step)

Before deploying ANY rules, index, schema, or functions change to the live
project (`dindin-cafelabs`):

1. Open the app signed in as each real user.
2. Ajustes -> Exportar JSON. Save the `.json` file somewhere durable.

This export is the only rollback for user data. No automated process here can
access production data, so this is a human gate. The rules/schema changes in
this phase are additive and backward-compatible (old documents and old backups
still load), but the export is still required as a safety net. This gate,
plus CI and rollback for rules/hosting, is now encoded in `scripts/deploy.sh`
— see `docs/DEPLOY.md` for the full deploy/rollback runbook.

## User data: export & deletion (privacy baseline)

Before onboarding real users there is a working path for both:

- **Export** — in-app: Ajustes → Exportar JSON produces the full ledger
  (`ImportExportService.exportToFile`). This is the user's complete data in a
  portable, human-readable format.
- **Deletion** — manual, documented process (acceptable at this stage):
  1. The user can wipe-and-replace their own data by importing an empty/edited
     backup (`replaceAll` clears the four ledger collections and resets the
     balance docs).
  2. Full account deletion (auth user + the entire `users/{uid}` subtree) is a
     manual admin step: delete the Auth user in the Firebase console and delete
     the `users/{uid}` document subtree (ledger + `meta/account` + `balances`).
     The backfill script's `firebase-admin` setup can also script this if
     needed. When a self-service "delete my account" button is added, it should
     do exactly this.

## Data model additions (all additive / backward-compatible)

- `categories/{id}.monthlyBudget` — optional `number` (BRL). Soft monthly
  spending limit per caixinha; `null`/absent means no limit. Does NOT gate the
  hard money invariants. New field (not `recurring`, which is a bool for a
  different question and is left untouched).
- `allocations/{id}.transferId` — optional `string`. A caixinha-to-caixinha
  transfer is a PAIR of allocation docs sharing this id: a negative-amount leg
  on the source, a positive-amount leg on the destination. The pair nets to
  zero against the account, so `aggregation_service.dart` stays correct with no
  changes, and the JSON backup stays consistent (transfers live inside the
  existing `allocations` array). The UI should group/label rows sharing a
  `transferId` as a transfer rather than two loose allocations.
- `categories/{id}.kind` — optional `'spend' | 'save'`. What the caixinha is
  *for*: `spend` gets the monthly-budget bar (`monthlyBudget`, above), `save`
  gets a savings-goal bar (`goalAmount`, below) or a "saved this month"
  feedback line when no goal is set. `null`/absent (a doc predating this
  field) behaves as `spend` — the only semantics that existed before.
  Validated in `firestore.rules` (`validCategory`) to be one of the two
  literal strings when present.
- `categories/{id}.goalAmount` — optional `number` (BRL), meaningful only for
  `kind == 'save'`. The target total the user wants to accumulate in that
  caixinha. Like `monthlyBudget`, this is reporting-only — it does not gate
  any money-integrity invariant.
- `categories/{id}.allowNegative` — optional `bool`. UNLIKE the three fields
  above, this one DOES gate a money-integrity invariant — see "allowNegative
  (dívida por caixinha)" below. `null`/absent (a doc predating this field, or
  any `save` caixinha) behaves as `false` — the only semantics that existed
  before.

Old JSON backups (no `monthlyBudget`, no `transferId`, no `kind`/`goalAmount`,
no `allowNegative`) import unchanged.

### Denormalized balance docs (Option B — see below)

Two derived documents hold the running balances so Security Rules can read them
in O(1) with `get()`/`getAfter()` (rules cannot sum a collection):

- `users/{uid}/meta/account` — `{ balance: number }`. The general account
  balance = total income − total allocated − account-only expenses.
- `users/{uid}/balances/{categoryId}` — `{ balance: number }`, one per
  caixinha, keyed by the SAME id as the category doc (so ledger rules can reach
  it deterministically from an allocation/expense's `categoryId`). balance =
  allocated to that caixinha (incl. transfer legs) − spent from it.

These are a **derived cache, not source of truth**:

- They are NOT part of the JSON backup. `AppDb.toJson()`/`fromJson()` stays the
  four ledger collections only; the balances are recomputed from the ledger on
  restore (`FirestoreService.replaceAll`) and by the backfill script. This
  keeps old backups importable and avoids storing redundant, drift-prone data
  in the backup file.
- The app's on-screen balances are still summed from the ledger by
  `aggregation_service.dart`. So even if a balance doc ever drifted, the UI
  would still show the truth; the balance docs exist to let the RULES enforce
  non-negativity and to give the client O(1) pre-write checks.

## Money-integrity enforcement: DECIDED — Option B (rules-only, free Spark tier)

> **Decision (owner):** ship **Option B** — rules-only with denormalized
> balances, on the free **Spark** plan. Do NOT enable Blaze and do NOT deploy
> Cloud Functions. Option A below is kept as documented reference only (the
> `functions/` code is retained but inactive — see `functions/README.md`).

Both options were considered:

The invariants — "spent <= allocated per caixinha", "allocations <= account
balance", "nothing goes negative" — depend on SUMMING whole collections.
Firestore Security Rules can `get()`/`getAfter()` individual documents but
CANNOT aggregate a collection, so rules alone cannot enforce these. Today they
are enforced client-side in `FirestoreService`. Two ways to move enforcement to
a place a malicious client can't bypass:

> Update: "nothing goes negative" is no longer an unconditional invariant.
> Since the `allowNegative` feature (below), a `spend` caixinha may opt into
> holding a negative balance ("dívida"). The account balance (`meta/account`)
> and `save` caixinhas remain unconditionally non-negative — only a `spend`
> caixinha with its own `allowNegative` flag on can go negative, and only
> itself. Written before that feature existed; kept here for the historical
> framing of why Option A/B exist, see "allowNegative (dívida por caixinha)"
> for the current, precise rule.

### Option A — Cloud Functions (RECOMMENDED, requires Blaze / paid)

- Callable functions in `functions/index.js` do each validated write inside a
  Firestore transaction under admin privileges. Robust: one trusted code path,
  transactional, no denormalization drift.
- Phase-2 rules then DENY direct client writes to `incomes`, `allocations`,
  `expenses` (and category writes if desired); the functions become the only
  write path. Reads stay client-side.
- COST: Cloud Functions require the **Blaze pay-as-you-go plan**. The Spark
  free tier does NOT run Functions. Blaze has a generous free monthly
  allowance, but it is a billing account with a card on file and no hard cap by
  default — set a budget alert. Not currently enabled.
- To adopt: enable Blaze; `cd functions && npm install`; add a `functions`
  block to `firebase.json` (not committed here — it's a deploy concern);
  `firebase deploy --only functions,firestore:rules`; add the `cloud_functions`
  Dart package and switch `FirestoreService`'s method bodies to call the
  matching callable (public method signatures do not change — see contract
  below), then tighten the rules.

### Option B — Rules-only with denormalized balances (FREE tier)

- Store a running `balance` on each category doc and an account balance doc
  (e.g. `users/{uid}/meta/account`). Every mutating write is a client-side
  Firestore transaction that updates the affected balance doc(s) alongside the
  transaction doc. Rules validate the pair with `getAfter()`, e.g. on an
  expense create: `getAfter(category).balance == get(category).balance -
  request.resource.data.amount && getAfter(category).balance >= 0`.
- HONEST trade-offs (do not pretend these away):
  - Brittle. Correctness requires paired rules on BOTH the transaction doc AND
    the balance doc (the balance doc's own update rule must forbid arbitrary
    changes, or a client just rewrites its balance). Any gap is a hole.
  - Denormalized balances can DRIFT from the true sum; needs a one-time
    backfill of existing docs at rollout and is harder to audit.
  - `getAfter()` couples writes into specific batches; the client must always
    write exactly the right doc set or writes are rejected.
- UPSIDE: stays on the free tier, no billing account.

### Why Option A was NOT chosen

For a money app, Option A (Cloud Functions) is the technically stronger design
— one trusted, transactional write path, no denormalization drift. It was not
chosen only because it requires the paid **Blaze** plan, and the owner's
constraint right now is to stay on the free tier. That trade-off is deliberate
and documented; if the app grows or the correctness cost of Option B's
brittleness starts to bite, revisit Option A (the migration path is above and
in `functions/README.md`).

## Option B — what is implemented

`firestore.rules` is now **Phase 2**. On top of Phase 1 (default-deny,
per-user ownership, shape/type validation, non-negative single amounts,
immutable `createdAt`) it adds:

- **Balance docs are first-class and strict.** `meta/account` and
  `balances/{catId}` accept only `{ balance }`, `balance` must be a number,
  owner-only. `meta/account` must ALSO be `>= 0`, unconditionally — this alone
  guarantees the general account balance can never be stored negative.
  `balances/{catId}` is `>= 0` by default too, EXCEPT for a `spend` caixinha
  that has opted into `allowNegative` — see "allowNegative (dívida por
  caixinha)" below for the exact conditional.
- **Per-write delta linkage via `getAfter()`.** Each ledger create/update/
  delete must move the affected balance doc(s) by exactly its delta (e.g. an
  account expense requires `getAfter(account).balance == before − amount &&
  >= 0`). Because each ledger doc pins the FINAL value of the balance doc(s)
  it touches, you cannot batch two conflicting writes to the same balance doc
  past the rules — the check is not bypassable by bundling writes. This delta
  linkage is unconditional for every balance doc, including an
  `allowNegative` caixinha's — only the `>= 0` floor on top of it is ever
  relaxed, never the delta check itself.
- **Genesis / teardown escape hatch.** Bulk operations (full JSON restore,
  category cascade-delete) can't satisfy a per-doc delta. They work by first
  DELETING the affected balance doc(s), doing the bulk ledger changes while the
  doc is absent (`getAfter(...) == null` ⇒ delta check skipped), then writing
  the recomputed balance doc(s) last. See `FirestoreService.replaceAll` and
  `deleteCategory` for the ordering. "Recomputed" assumes the result is
  `>= 0`, or eligible under one of the two negative-balance escape hatches
  (`catAllowsNeg` for a live update, `catMayHoldNeg` for a doc being created —
  see "allowNegative (dívida por caixinha)" below). `FirestoreService.
  replaceAll` now validates every recomputed balance BEFORE mutating anything
  (step 0), so a backup that would violate this is rejected atomically with
  nothing written — see "F1" under "Option B residual limitations" for the
  failure mode this replaced.

Client side (`lib/services/firestore_service.dart`): every balance-affecting
method runs a Firestore **transaction** that reads the balance doc(s), does the
same pre-check the rules enforce (for a friendly error before the rule
rejects), and writes the ledger doc + balance doc(s) together.

## allowNegative (dívida por caixinha)

A `spend` caixinha can opt into holding a negative balance — a "dívida" — via
`categories/{id}.allowNegative: bool`. This DELIBERATELY loosens, in a scoped
way, what used to be an absolute invariant ("no balance doc is ever negative").
Product rules:

- **Only `kind == 'spend'` is eligible.** A `save` caixinha is ALWAYS
  non-negative, unconditionally, even if `allowNegative: true` is stored on
  it (a stale/incoherent value — e.g. the user switched `kind` from `spend`
  to `save` while the toggle happened to be on). `catAllowsNeg()` in
  `firestore.rules` checks both the flag AND `kind == 'spend'` every time,
  reading the LIVE category doc, so this is enforced server-side regardless
  of what the client sends.
- **Debt is paid down automatically by the next allocation/transfer-in, not
  by a dedicated "quitar" action.** There is no separate settle/payoff
  operation — a caixinha's balance is a single running number, and an
  allocation that raises it just... raises it, same math as always.
- **Turning the toggle OFF while the balance is negative is allowed.** It
  FREEZES the existing debt: the caixinha refuses further spends/withdrawals
  (anything that would deepen the negative) while off and negative, but
  allocations/transfers that raise the balance (including back to `>= 0`)
  are still allowed. Toggling back ON re-enables deepening it further.

### Where it's enforced

- **`firestore.rules`** — the `>= 0` floor on a caixinha's balance doc became
  CONDITIONAL in exactly two places, both gated the same way:
  - `catDeltaOk(uid, cat, delta)` — the per-ledger-write delta check used by
    `allocations` and `expenses`. Was `result >= 0`; is now
    `result >= 0 || delta >= 0 || catAllowsNeg(uid, cat)`. The `delta >= 0`
    branch is what lets a frozen debt be paid down (partially or fully)
    regardless of the toggle; `catAllowsNeg` is what lets a spend/withdrawal
    deepen it.
  - The direct write rule on `balances/{categoryId}` — same two-branch
    relaxation, so a standalone balance-doc write is held to the same
    standard as a ledger-linked one.
  - New helper `catAllowsNeg(uid, cat)`: `get()`s the live category doc and
    requires `allowNegative == true` AND `kind == 'spend'` (a legacy doc with
    no `kind` reads as `'spend'` via `.get('kind', 'spend')`, matching
    `Category.effectiveKind` on the client). A missing category doc (e.g.
    mid-teardown) is not eligible.
  - New helper `catMayHoldNeg(uid, cat)` — narrower purpose than
    `catAllowsNeg`, toggle-**agnostic**: it only asks whether the caixinha is
    currently a `spend` envelope (or legacy null-`kind`), ignoring
    `allowNegative` entirely. It is wired into `balances/{categoryId}`'s
    write rule in a branch gated by `resource == null` — i.e. it can only
    fire when the balance doc is being **created** (genesis/restore), never
    on an update to an existing doc. This is what lets a frozen debt (toggle
    off, `kind` switched, or category re-created) survive a full JSON
    restore: the recomputed negative balance is legitimate ledger history,
    and genesis is the one moment the rules allow re-materializing it without
    re-checking the live toggle. A live write to an existing balance doc
    still goes through `catDeltaOk`/`catAllowsNeg`, so a frozen debt cannot
    be deepened by a normal write — only re-created at its already-frozen
    value from an absent doc. See "Descongelar via teardown" under "Option B
    residual limitations" for the trade-off this introduces.
  - The anti-race delta linkage itself (`getAfter(balDoc) == before + delta`)
    is UNCHANGED and stays unconditional — only the non-negativity floor is
    relaxed, never the "you must move the doc by exactly your own delta"
    guarantee. Same for `meta/account`: its rule was NOT touched, so the
    general account balance remains unconditionally `>= 0` no matter what any
    caixinha's `allowNegative` is set to.
- **`lib/models/category.dart`** — `allowNegative: bool?` plus
  `allowsNegativeBalance` (`(allowNegative ?? false) && effectiveKind ==
  CategoryKind.spend`), mirroring `catAllowsNeg` for client-side use.
- **`lib/services/firestore_service.dart`** — `_catDeltaOk()` mirrors the
  rules' `catDeltaOk()` exactly (same three-branch check) so the client can
  give a friendly error instead of a raw permission-denied, and so it never
  optimistically allows a write the deployed rules would reject.
- **UI** — Ajustes/Categorias, "Permitir saldo negativo" switch, shown only
  when the caixinha's `kind` is `spend` (`lib/features/categorias/
  categorias_page.dart`).

Covered by `test/rules/rules.test.mjs` (`describe('allowNegative (caixinha
debt)')`): deepening while ON, blocking further deepening while OFF-and-
negative, partial paydown while OFF-and-negative, a `save` caixinha ignoring
a stray `allowNegative: true`, transfers, the account balance staying
untouched/non-negative regardless, and that the delta-linkage anti-race check
still applies unconditionally even when `catAllowsNeg` is true.

### Deploy order — MANDATORY

`scripts/deploy.sh` encodes this exact sequence as a gated script (backup
confirmation -> dry-run + balance-corruption check -> real backfill -> verify
-> rules -> hosting) — see `docs/DEPLOY.md` for how to run/debug it and for
rollback steps. The balance docs must be correct BEFORE the Phase-2 rules and
the new client reach real users, or the first client write will initialize a
balance from a wrong (zero) base. Release sequence:

1. Back up production data (the human gate at the top of this file).
2. Run the **backfill** (`scripts/backfill_balances.mjs`, see its header) to
   compute and write `meta/account` + `balances/{catId}` for every existing
   user from their current ledger. Idempotent; safe to re-run. Runs on Spark
   via an Admin service-account key (Admin access is free — only Functions need
   Blaze).
3. Deploy `firestore.rules` (Phase 2) and ship the new client build together.

Doing 3 before 2 leaves balances desynced on day one.

### Option B residual limitations (for QA / security review)

- **The getAfter/null-teardown rules cannot be unit-tested from Flutter.** They
  MUST be exercised against the Firestore emulator before deploy — in
  particular: the `getAfter(...) == null` genesis/teardown branches, a full
  `replaceAll` restore, and a `deleteCategory` cascade. This is the single
  biggest open verification item.
- **Self-inflicted drift is possible, cross-user harm is not.** A client that
  deliberately deletes its own balance doc first can then write ledger docs
  without the delta check and re-create the balance at any non-negative value
  — and, for a `spend` caixinha specifically, at any negative value too
  (`catMayHoldNeg`, the genesis-only escape hatch — see "Descongelar via
  teardown" below for why that exists and what it does/doesn't allow). All
  data is single-tenant, so this only corrupts the user's OWN numbers, and the
  UI recomputes balances from the ledger anyway. The real security boundary
  (no cross-user read/write) is enforced unconditionally by `isOwner()`.
- **Allocation/expense edits are restricted** to keep the rules tractable:
  `updateAllocation` keeps the same caixinha, `updateExpense` keeps the same
  target (caixinha vs account). Re-homing is delete + recreate. These edit
  paths are not reachable from the current UI (only create/delete are wired),
  so this is not a user-visible regression today.
- **Transfers are not fully supported in `deleteCategory`.** Deleting a
  category that holds transfer legs would orphan the paired leg in another
  caixinha and skew that caixinha's balance. Transfers are not reachable from
  the UI yet; wire a dedicated flow before enabling them. No production data
  has transfer legs today.
- **F1 — restoring a backup with a FROZEN debt could fail partway through —
  FIXED, verified against the emulator.** A frozen debt is a `spend` caixinha
  that went negative and then either had its `allowNegative` toggle turned
  off, or had its category deleted, or had its `kind` switched to `save` — in
  all three cases the negative number itself is never erased from the ledger
  math, only the permission to hold it going forward. Two changes together
  close this:
  - **Rules (`firestore.rules`):** `balances/{categoryId}`'s create/update
    rule gained a fourth branch, `resource == null && catMayHoldNeg(uid,
    categoryId)`, evaluated only when the doc is being CREATED (a full
    restore or a category re-creation), never on an update to a live doc.
    `catMayHoldNeg` is toggle-**agnostic** — unlike `catAllowsNeg`, it only
    checks that the caixinha is currently a `spend` envelope (or legacy
    null-`kind`), so a recomputed frozen debt is accepted at genesis
    regardless of whether `allowNegative` is on or off right now. Because
    the branch is gated on `resource == null`, a live write to an existing
    balance doc still goes through `catDeltaOk`/`catAllowsNeg` exactly as
    before — the freeze on a live, negative, toggle-off caixinha is
    unaffected; deepening it still requires the toggle to be on.
  - **Client (`lib/services/firestore_service.dart`):** `replaceAll` now
    validates every recomputed balance in a **step 0**, before deleting or
    writing anything. The general account going negative, or any *existing*
    non-`spend` caixinha computing negative, throws `StateError` and aborts
    with nothing written — so a genuinely inconsistent backup fails atomically
    up front instead of leaving a partially-restored database. An
    orphan id (referenced by the ledger but absent from `db.categories`) is
    never materialized as a balance doc at all (unchanged from before), so it
    can't reach this check or the rules either way.
  - Net effect: restoring a backup that contains a legitimate frozen `spend`
    debt now succeeds and re-materializes that debt (still frozen — the
    toggle value in the restored category doc governs future writes exactly
    as it did before the restore). Restoring a backup where the debt sits on
    a `save` caixinha, or where the account itself is negative, is refused
    up front as corrupt data, not as a partial write. Covered by
    `test/rules/rules.test.mjs` (`describe('genesis re-materialization of a
    frozen debt (catMayHoldNeg, F1 fix)')`, against the emulator) and by
    `test/services/firestore_service_test.dart` (`group('replaceAll (JSON
    restore)')`, the step-0 pre-validation cases).
  - **Residual trade-off this introduces — "descongelar via teardown"
    (unfreeze via teardown), known and accepted, not a bug:** because
    `catMayHoldNeg` only checks `kind`, a client can, on its own single-tenant
    data, delete a `spend` caixinha's balance doc and recreate it at ANY
    negative value it likes — even one deeper than the real frozen debt, and
    even with `allowNegative` currently off. This is NOT a cross-user or
    integrity hole: the account and every `save` caixinha stay floored at
    `>= 0` even on genesis (`catMayHoldNeg` never applies to them), the
    on-screen balances are always recomputed from the ledger by
    `aggregation_service.dart` (the balance doc is a validation cache, not
    what's displayed), and a self-inflicted wrong balance can only
    over-restrict that same user's OWN future writes — it can never let them
    overspend or touch another user's data. Preventing this fully would need
    either summing the ledger inside rules (rules cannot do this) or Cloud
    Functions (Blaze, declined for the free-tier build — see "Why Option A
    was NOT chosen"); this is the honest Option-B ceiling. Documented in
    `firestore.rules`' `HONEST LIMITS` header comment and in
    `catMayHoldNeg`'s own comment.
- **`scripts/backfill_balances.mjs` predates `allowNegative` — FIXED, verified
  against the emulator/dry-run.** The script now splits a negative recomputed
  balance into two buckets instead of treating every negative as an error:
  - **Legitimate debt** — an EXISTING `spend` caixinha (or legacy null-`kind`)
    summing negative, whether `allowNegative` is currently on (open debt) or
    off (frozen debt). Printed as a warning (`open debt (open, allowNegative
    on)` / `(FROZEN, allowNegative off)`) but does NOT fail the script or the
    deploy gate.
  - **`BALANCE CORRUPTION`** — a negative that should never exist: the general
    account, a `save` caixinha, or an orphan id (category deleted, ledger
    entries remain). This still aborts the dry-run/backfill loudly.
  - `scripts/deploy.sh`'s gate was updated to match: it now greps the dry-run
    log for the marker `BALANCE CORRUPTION` (not the old `NEGATIVE BALANCE`,
    which no longer exists as a marker) and only aborts on that. An open or
    frozen debt prints as a warning and lets the deploy proceed. This closes
    the original defect where a single open debt in production would have
    blocked every future rules/schema deploy, not just ones touching
    `allowNegative`.
- **Known pending: no app-side guard against converting a negative `spend`
  caixinha to `save`, or deleting it, while it still owes a debt.** This is
  the ONE thing left open from the `allowNegative` security review that is
  not yet fixed. Today, `categorias_page.dart` lets the user flip a
  caixinha's `kind` from `spend` to `save`, or delete it outright
  (`FirestoreService.deleteCategory`), with no check on its current balance —
  that's the actual origin of the "save caixinha with a debt" / "orphan with a
  debt" shape that `replaceAll` (step 0, above) and
  `scripts/backfill_balances.mjs` now correctly refuse as `BALANCE
  CORRUPTION` by design, to protect the conservation-of-money invariant,
  rather than silently erasing or misattributing the debt. Refusing it in
  restore/backfill is the right last line of defense, but it means a user who
  does this today can back themselves into a backup that later fails to
  restore (correctly, but confusingly) until they fix the category's `kind`/
  balance by hand. Recommended fix (not yet implemented): add a guard in the
  app that blocks (or warns and requires explicit confirmation for) switching
  a negative-balance `spend` caixinha to `save`, and blocks deleting a
  caixinha while its balance is negative, forcing the debt to be paid down or
  explicitly forgiven first. TODO: confirmar when this guard will be
  scheduled/implemented.

## Client contract (stable regardless of option)

`FirestoreService`'s public method signatures are the seam. They do not change
whether a write goes direct (today / Option B) or through a callable (Option A).
Callable names and payloads in `functions/index.js` mirror these argument
names 1:1, returning `{ id }` (or `{ transferId }`):

- `createCategory(name, recurring, monthlyBudget?, kind?, goalAmount?, allowNegative?)`
- `updateCategory(id, name?, recurring?, monthlyBudget?, clearMonthlyBudget?, kind?, goalAmount?, clearGoalAmount?, allowNegative?)`
- `deleteCategory(id)`
- `createIncome(date, amount, source, description?)` / `updateIncome(id, ...)` / `deleteIncome(id)`
- `createAllocation(categoryId, amount, date)` / `updateAllocation(id, ...)` / `deleteAllocation(id)`
- `createTransfer(fromCategoryId, toCategoryId, amount, date) -> transferId` / `deleteTransfer(transferId)`
- `createExpense(date, amount, categoryId?, description?)` / `updateExpense(id, ...)` / `deleteExpense(id)`
