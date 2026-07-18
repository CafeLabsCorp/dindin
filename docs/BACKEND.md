# Backend / data-integrity notes

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

Old JSON backups (no `monthlyBudget`, no `transferId`, no `kind`/`goalAmount`)
import unchanged.

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
  `balances/{catId}` accept only `{ balance }`, `balance` must be a number
  `>= 0`, owner-only. This alone guarantees no balance can ever be stored
  negative.
- **Per-write delta linkage via `getAfter()`.** Each ledger create/update/
  delete must move the affected balance doc(s) by exactly its delta and keep
  them `>= 0` (e.g. an account expense requires
  `getAfter(account).balance == before − amount && >= 0`). Because each ledger
  doc pins the FINAL value of the balance doc(s) it touches, you cannot batch
  two conflicting writes to the same balance doc past the rules — the check is
  not bypassable by bundling writes.
- **Genesis / teardown escape hatch.** Bulk operations (full JSON restore,
  category cascade-delete) can't satisfy a per-doc delta. They work by first
  DELETING the affected balance doc(s), doing the bulk ledger changes while the
  doc is absent (`getAfter(...) == null` ⇒ delta check skipped), then writing
  the recomputed, non-negative balance doc(s) last. See
  `FirestoreService.replaceAll` and `deleteCategory` for the ordering.

Client side (`lib/services/firestore_service.dart`): every balance-affecting
method runs a Firestore **transaction** that reads the balance doc(s), does the
same pre-check the rules enforce (for a friendly error before the rule
rejects), and writes the ledger doc + balance doc(s) together.

### Deploy order — MANDATORY

`scripts/deploy.sh` encodes this exact sequence as a gated script (backup
confirmation -> dry-run + negative-balance check -> real backfill -> verify
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
  without the delta check and re-create the balance at any non-negative value.
  All data is single-tenant, so this only corrupts the user's OWN numbers, and
  the UI recomputes balances from the ledger anyway. The real security boundary
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

## Client contract (stable regardless of option)

`FirestoreService`'s public method signatures are the seam. They do not change
whether a write goes direct (today / Option B) or through a callable (Option A).
Callable names and payloads in `functions/index.js` mirror these argument
names 1:1, returning `{ id }` (or `{ transferId }`):

- `createCategory(name, recurring, monthlyBudget?, kind?, goalAmount?)`
- `updateCategory(id, name?, recurring?, monthlyBudget?, clearMonthlyBudget?, kind?, goalAmount?, clearGoalAmount?)`
- `deleteCategory(id)`
- `createIncome(date, amount, source, description?)` / `updateIncome(id, ...)` / `deleteIncome(id)`
- `createAllocation(categoryId, amount, date)` / `updateAllocation(id, ...)` / `deleteAllocation(id)`
- `createTransfer(fromCategoryId, toCategoryId, amount, date) -> transferId` / `deleteTransfer(transferId)`
- `createExpense(date, amount, categoryId?, description?)` / `updateExpense(id, ...)` / `deleteExpense(id)`
