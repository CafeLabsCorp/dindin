# Backend / data-integrity notes

**[Leia em Português](BACKEND.pt-br.md)**

Operational reference for Dindin's Firestore backend (describes version 1.2.1+7,
checked against `firestore.rules`, `lib/services/firestore_service.dart` and
`test/rules` on 2026-11-16; the rules harness was read, not run). Read this before any
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

- **Export** — in-app: Ajustes → Exportar JSON produces the full ledger
  (`ImportExportService.exportToFile`). This is the user's complete data in a
  portable, human-readable format. The account-deletion confirmation dialog
  (below) offers this same export as an optional step before deleting.
- **Wipe-and-replace** — the user can also reset their own data in place by
  importing an empty/edited backup (`replaceAll` clears the six ledger
  collections and resets the balance docs) without deleting the account.
- **Full account deletion (B3/B5 — Play Store requirement + LGPD)** —
  self-service, in-app: Ajustes → Privacidade → "Excluir conta"
  (`SettingsPage._openDeleteAccountDialog`). Decision 3 (ratified
  2026-08-31, opção A): **hard delete, immediate, no carência/recovery** —
  there is no "deactivated" state. The confirmation dialog offers exporting a
  backup first (not required) alongside cancel/delete.
  1. `FirestoreService.deleteAllUserData()` wipes the entire `users/{uid}`
     subtree: `meta/account` + every `balances/{catId}` doc **first, on their
     own committed batch(es)**, then the six ledger collections, chunked the
     same way `replaceAll` is (see "Batch chunking" — a category's/
     allocation's/expense's delete counts as one document-access against the
     rules' 20-access ceiling, same as a write does; doc-count-only chunking
     here would reproduce the restore data-loss bug below).
  2. `AuthService.deleteAccount()` then calls `FirebaseAuth.currentUser.delete()`
     to remove the Auth identity. **Order matters and is enforced by
     `firestore.rules` itself**, not just by convention: `catDebtFree()` (which
     gates deleting an indebted category) reads the balance doc's PRE-COMMIT
     value, so an indebted caixinha's `categories/{id}` delete is rejected
     while its `balances/{id}` doc still exists — the balance docs MUST be
     gone, in an already-committed batch, before the ledger delete. Deleting
     the Auth user before the Firestore data would instead strand
     `users/{uid}` unreachable forever (uids are never reissued).
  3. **Recent login is checked BEFORE step 1.** `SettingsPage` calls
     `AuthService.hasRecentLogin()` (reads the ID token's `auth_time`, 4-minute
     margin under Firebase's ~5-minute window) and, if the session is too old,
     shows "sign out and back in, then retry" and **deletes nothing**. (Before
     1.1.2 the Firestore data was wiped first and `user.delete()` then failed
     with `requires-recent-login`, leaving a live, empty account.) The user
     still has to sign out and in again; re-authenticating in place was not
     built. If `user.delete()` still throws `requires-recent-login` (the
     margin is not a guarantee), the same message shows, and
     `scripts/sweep_orphans.mjs` below is the backstop for a deletion that dies
     between steps 1 and 2.
  - No tombstone IDENTIFYING the user is written or expected after a
    successful deletion — there is nothing left under `users/{uid}` for
    anyone to read (rules key on `request.auth.uid`, and a deleted uid is
    never reissued), so an empty subtree already proves the deletion
    happened. `scripts/sweep_orphans.mjs` doesn't look for a tombstone either:
    it detects an incomplete/interrupted deletion purely by "this uid has
    data under `users/{uid}` but no Auth user" — see the script's header.
    What IS written is the anonymous `accountDeletionLog` entry described
    below — an audit trail that a deletion happened, with nothing in it that
    identifies who.
  - Covered end-to-end by `test/rules/rules.test.mjs`, `describe('full
    account deletion (B5)')` (the prescribed order against the real
    emulator, including a frozen-debt caixinha, plus the order-matters
    negative cases and cross-user isolation) and `describe('accountDeletionLog
    (create-only, anonymous audit trail)')`;
    `test/services/firestore_service_test.dart`, `group('deleteAllUserData
    (B3/B5 — hard account deletion)')` (including its nested
    `group('accountDeletionLog entry (Privacy Policy §7)')`); and
    `test/features/settings_page_test.dart` (dialog open/cancel/export-then-
    close flow).

### `accountDeletionLog` — proof of deletion, with no personal data (2026-09-23)

Closes a gap the 2026-09-22 security audit surfaced: `legal/politica-de-
privacidade.md` §7 already promises, as published legal text, "Registro de
que a exclusão foi feita (sem os seus dados pessoais) | 5 anos" — but until
now nothing wrote that record. `scripts/sweep_orphans.mjs`'s cleanup was also
silent (stdout only, no persisted trail), which was the audit's original,
narrower finding; both are closed by the same collection.

**Schema** — `accountDeletionLog/{autoId}`, a TOP-LEVEL collection (not
nested under `users/{uid}`, so the about-to-be-deleted uid never ends up in
the document path):
```
{
  deletedAt: Timestamp,  // FieldValue.serverTimestamp() — never client-supplied
  origin:    string,     // 'self-service' | 'admin-sweep'
}
```
No uid, email, or other identifier — client or hash — is stored. This was a
deliberate call, not an oversight: a hash of a Firebase auto-id uid is
realistically irreversible (128 bits of entropy), so it would have been
*defensible*, but the policy's own wording promises "sem os seus dados
pessoais" unconditionally, and the only thing this record needs to prove is
that *a* deletion happened at a given time, for a given reason — never
*whose*. Omitting any uid/hash field is both the simplest implementation and
the one that can never be read as breaking that sentence.

**Rules** (`firestore.rules`, `accountDeletionLog` block): CREATE-ONLY.
`create` requires `request.auth != null` and validates the exact shape above,
closed with `keys().hasOnly` (so a `uid` or `email` field can never be
smuggled in) and `deletedAt == request.time` (so only the server's own commit
clock can set it — a client can't backdate or forge one). `read`, `update`,
and `delete` are `false` unconditionally, for everyone, including a doc's own
author: this collection has no legitimate in-app reader, and real auditing of
it (the 5-year retention the policy promises) is an Admin SDK / Firebase
console operation, entirely outside any client's reach.

**Written from two places**, always in the same request/commit as the
deletion it is attesting to, never as a separate call:
- `FirestoreService.deleteAllUserData()` (self-service, `origin:
  'self-service'`) — in the SAME batch as the first commit of step 1 (the
  one that always includes `meta/account` + `meta/settings`). It has to
  happen there: `AuthService.deleteAccount()` runs right after, and once that
  completes this client is no longer authenticated and could never write
  here — and bundling it with the real deletion's first commit means the log
  can never claim a deletion happened when it didn't (they commit together or
  not at all).
- `scripts/sweep_orphans.mjs` (`origin: 'admin-sweep'`) — written inside
  `sweepUser()`, once per uid actually swept (i.e. `total > 0` in write mode;
  a `--dry-run` writes nothing, matching every other write in that script).
  Runs under the Admin SDK, which bypasses `firestore.rules` entirely, so the
  script's own code is what keeps its write's shape identical to what the
  rule would validate anyway.

**Retention**: the Privacy Policy promises 5 years, not "forever" — this
collection has no TTL configured yet. Setting one (Firestore native TTL
policies, keyed on `deletedAt`) is an infra/console step outside this
repo's code and is a separate follow-up, not required for the promise to be
kept today (nothing currently *reads* this collection for anything other than
a maintainer audit, so an unbounded collection is not yet a correctness
problem — only an eventual storage-cap one, same class of concern as
"Abuse / overload posture" above, worth revisiting well before 5 years' worth
of entries could approach it).

**This is a `firestore.rules` change and therefore does NOT take effect in
production on its own** — it ships to `dindin-cafelabs` only via
`scripts/deploy.sh`'s full backup -> backfill -> rules flow (see
"Deploy gate" above and `docs/DEPLOY.md`), which has a human-confirmed backup
step by design.
  - **Backstop for a deletion that dies partway** (app killed, network drops,
    the required re-auth is refused): `scripts/sweep_orphans.mjs`, a
    maintainer-run Admin SDK script (Cloud Functions would need Blaze, which
    is deliberately not in use — see "Option B" below). Detects any uid with
    Firestore data but no Auth user and deletes the leftover subtree; also
    cleans up an Auth user deleted by hand from the Firebase console (which
    never touches Firestore). `--dry-run` by default; requires `--confirm` to
    write. Run periodically (see its header for the invocation and
    credentials).

## App Check (abuse posture)

`lib/main.dart` calls `FirebaseAppCheck.instance.activate` at startup, wrapped
in a try/catch so a failure can never block the app:

- **Android:** `AndroidPlayIntegrityProvider` in release builds,
  `AndroidDebugProvider` under `kDebugMode` (prints a token that must be
  registered once in Firebase Console → App Check → Apps → debug tokens for local
  builds to keep working).
- **Web:** not activated. It needs a reCAPTCHA v3 site key
  (`_recaptchaV3SiteKey` is still the placeholder `REPLACE_WITH_RECAPTCHA_V3_SITE_KEY`),
  and the maintainer decided on 2026-09-21 to defer web App Check (the
  alternative, reCAPTCHA Enterprise, needs a billing account linked, which
  contradicts staying on Spark without a card). Per that decision record.
- **Enforcement is OFF.** The app only *sends* tokens; "Enforce" for Firestore and
  Authentication in the Firebase Console has not been turned on, deliberately,
  until the console metrics show real Android traffic as verified. Turning it on
  would also reject the web client, which sends no token. Open item in
  `docs/PENDENCIAS.md`. `firestore.rules`' own header ("ABUSE / OVERLOAD
  POSTURE") explains that rules alone cannot rate-limit and that App Check is what
  bounds the Spark quota.

## Email verification (non-blocking)

Closes the "Verificação de e-mail não implementada" finding from the
2026-09-22 security audit. Scope ratified by Felipe: **non-blocking** —
nothing in the app gates on a confirmed e-mail (solo-use personal-finance
app, no invite/account sharing), so this is pure Firebase Auth — it does not
touch `firestore.rules`.

- **Automatic send** — `AuthService.registerWithEmail` calls
  `sendEmailVerification()` right after `createUserWithEmailAndPassword`
  succeeds. Best-effort: if sending fails (e.g. a network blip), signup still
  goes through — the unverified state stays visible and retryable
  afterward. Does NOT apply to "Sign in with Google": those accounts are
  already verified by Google, and `AuthService.needsEmailVerification`
  explicitly excludes any account whose `providerData` doesn't include the
  password provider (`EmailAuthProvider.PROVIDER_ID`).
- **Warning** — Ajustes → Privacidade shows a discreet banner with a "Resend
  verification email" button when `AuthService.needsEmailVerification` is
  true for the signed-in user. `User.emailVerified` is a snapshot taken at
  sign-in and doesn't update on its own — `AuthService.reloadCurrentUser()`
  is called when Ajustes opens and when the app resumes from the background
  (`SettingsPage` uses `WidgetsBindingObserver`), to pick up a confirmation
  that happened outside this session (e.g. the link tapped in a mail app).
- **Rate limit** — Firebase Auth already rate-limits resends on its own
  (`too-many-requests`); the UI turns that code into a friendly message
  instead of letting the exception propagate.
- Covered by `test/services/auth_service_test.dart` (automatic send for
  email/password only, `needsEmailVerification`, reload, rate limit) and
  `test/features/settings_page_test.dart`, `group('verificação de e-mail
  ...')` (conditional banner, resend, rate-limit message).

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
- `subscriptions/{id}` — a new collection (not a field on an existing one): a
  fixed recurring monthly expense (name, amount, dueDay, createdAt,
  lastChargedDate?, categoryId?), charged from the account or from an
  envelope (see `categoryId` below). It carries no
  money invariant of its own — `FirestoreService.catchUpSubscriptions` is the
  only writer of the `expenses` docs it produces, and those go through the
  ordinary balance gate like any other expense. See "Subscriptions
  (recurring expenses)" below for the client-triggered catch-up model this
  implies. An old backup with no `subscriptions` key imports as an empty list.
- `installmentPurchases/{id}` — another new collection, the BOUNDED
  counterpart to `subscriptions`: a card purchase (name, totalAmount,
  installments, purchaseDate, firstChargeDate, createdAt,
  chargedInstallments) split into N fixed monthly charges instead of an
  open-ended recurrence. Same no-invariant-of-its-own posture;
  `FirestoreService.catchUpInstallmentPurchases` produces its `expenses` docs
  and stops once `chargedInstallments` reaches `installments`. See
  "Subscriptions (recurring expenses)" below — it shares that section's
  client-triggered catch-up model verbatim.

- `expenses/{id}.sourceType` + `sourceId` — two optional fields that travel
  together (both present or both absent) linking an expense to the doc that
  generated it: `'subscription'`/`'installment'` plus the id. Absent = the
  user typed it in. Same idea as `Allocation.transferId`, and the same
  no-money-invariant-of-its-own posture — a generated expense debits the
  account exactly like a manual one, so the balance-delta rules already cover
  the money side. What the rules add is that the link is **immutable** once
  created: an edit can't plant, strip, or repoint it (`sameExpenseSource`).
  Why they exist: without them a generated expense is indistinguishable from
  a manual one with the same description — there's no way to say what a
  subscription has cost so far, nor to notice a charge was deleted by hand.
  `sourceType` is stored as a raw string (not an enum) so a value written by
  a newer build survives an export/import cycle instead of vanishing on the
  way back out.

- `subscriptions/{id}.categoryId` and `installmentPurchases/{id}.categoryId` —
  the envelope the charge comes out of; absent = the general account, the same
  meaning it has on an expense. No invariant of its own: the balance only
  moves when catch-up writes the `Expense`, and that write is validated by the
  `expenses` rules against whichever balance doc it targets. The client
  (`_readChargeSource`) mirrors `createExpense`'s two branches, `allowNegative`
  included. A deleted envelope means the charge stays pending with a warning,
  never a silent fallback to the account.
- `installmentPurchases/{id}.amortizedAmount` — how much has been paid beyond
  the scheduled installments (paying extra one month, or settling). Mutable
  but only ever grows, never negative and never above `totalAmount` — beyond
  that would mean collecting more than the debt. It exists so
  `totalAmount`/`installments` never have to be rewritten; those stay
  immutable because they are what `chargedInstallments` is counted against.
  Absent = 0.
- `installmentPurchases/{id}.dueDayOverride` — the day of the month the
  REMAINING installments fall due, when the user has moved it. Absent = keep
  `firstChargeDate`'s own day, which is how every purchase behaved before this
  field existed. Mutable (1-31) precisely because `firstChargeDate` is not:
  that field anchors every occurrence, including the ones already billed, so
  rewriting it would retroactively change dates money already went out on.
  `recurring_schedule.installmentDueDate` therefore ignores the override for
  any index below `chargedInstallments` — moving the due day never rewrites
  history — and only the DAY moves, never the month sequence.

- `subscriptions/{id}.autoChargeEnabled` — optional `bool`, stored only when
  `false` (absent = `true`). With `false`, `catchUpSubscriptions` skips the
  subscription and its due dates stay pending until the user posts them with
  "Cobrar agora" (`chargeSubscriptionNow`, which ignores the flag). No invariant
  of its own.
- `users/{uid}/meta/settings` — `{ analyticsOptOut: bool }`. Only key allowed
  (`keys().hasOnly`). Missing doc = collection ON. Deliberately a separate doc
  from `meta/account`, whose validator anchors the money model and is kept as
  narrow as possible.
- `users/{uid}/meta/tutorials` — which onboarding tutorials the user has seen:
  `{ <page>: { state: 'done' | 'skipped', v: int } }`, one optional key per
  page, closed list `dashboard`, `receitas`, `gastos`, `assinaturas`,
  `parcelamentos`, `categorias`, `ajustes` (`validTutorials`/`validTutorialEntry`
  in `firestore.rules`; `v` is the tutorial version, integer 1..1000). UI
  state, not money: no balance touches it, nothing reads it but the tutorial
  engine, and it is not in the JSON backup. Kept as its own doc (not a field of
  `settings`) so that doc's validator stays as narrow as it is. The app
  writes with `set(..., merge: true)` (one page at a time), resets a page with
  `FieldValue.delete()` and all pages with a document delete (allowed by the
  generic `meta` delete rule). `lib/models/tutorial_progress.dart`'s
  `TutorialPage` ids MUST stay in sync with that closed list: adding an eighth
  tutorial needs a rules change and therefore `scripts/deploy.sh`. Covered by
  `describe('meta/tutorials (onboarding progress)')` (6 tests). Until the rules
  were deployed (done by the maintainer on 2026-11-13, before 1.2.0), the app
  kept progress only in the session, so tutorials would have reappeared on the
  next open.
- `accountDeletionLog/{autoId}` — top-level, create-only audit trail; see
  "`accountDeletionLog`" above.
- `incomes/{id}.createdAt` and `expenses/{id}.createdAt` — optional ISO
  timestamp, set by the client clock (`FirestoreService._now`); only used to
  order rows that share a `date`. Absent on older documents (they sort after
  the ones that have it).

Old JSON backups (no `monthlyBudget`, no `transferId`, no `kind`/`goalAmount`,
no `allowNegative`, no `subscriptions`, no `installmentPurchases`, no
`sourceType`/`sourceId`, no `categoryId` on the recurring collections, no
`amortizedAmount`, no `dueDayOverride`) import unchanged.

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
  six ledger collections only; the balances are recomputed from the ledger on
  restore (`FirestoreService.replaceAll`) and by the backfill script. This
  keeps old backups importable and avoids storing redundant, drift-prone data
  in the backup file.
- The app's on-screen balances are still summed from the ledger by
  `aggregation_service.dart`. So even if a balance doc ever drifted, the UI
  would still show the truth; the balance docs exist to let the RULES enforce
  non-negativity and to give the client O(1) pre-write checks.

### Dashboard balance re-sums the ledger (read windowing)

Two different consumers read the same collections for two different purposes,
and they are deliberately NOT the same query:

- **Lists** (Receitas, Gastos, Parcelamentos) use the windowed streams
  `watchIncomes`/`watchAllocations`/`watchExpenses`: `orderBy('date', desc)`
  plus `.limit(2000)` (`_ledgerLimit` in `firestore_service.dart`;
  categories/subscriptions/installment purchases use a 500 cap,
  `_smallCollectionLimit`). The `orderBy` is not optional: a bare `.limit()`
  returns documents by id and could drop RECENT rows while keeping old ones.
  Rows that share a `date` are re-sorted client-side by `createdAt` (a
  Firestore `orderBy('createdAt')` would silently drop older docs without the
  field). `fetchAll()` (export) has no limit either.
- **The Dashboard** (`summaryProvider`) uses the full, unlimited
  `watchAllIncomes`/`watchAllAllocations`/`watchAllExpenses`, then sums them in
  Dart (`aggregation_service.buildSummary`). The account balance and each
  caixinha's balance shown there are **re-summed from the whole ledger on every
  snapshot**, not read from `meta/account`/`balances/{id}`.

Why: the Dashboard balance is the number users trust with their money. Summing
the windowed list would silently undercount for an account with more than 2000
rows per collection, and reading the denormalized docs would show whatever a
drifted cache holds (see "Option B residual limitations": a client can rewrite
its own balance docs). Re-summing is correct by construction. The cost is real
and accepted: every session reads the entire history of the account (counted against the
Spark tier's daily read quota), and every snapshot re-sums everything in
memory. It should be revisited if accounts with
tens of thousands of rows appear. Only the monthly history chart of a very
long-lived account can still fall outside the 2000-row window of the lists; the
Dashboard totals cannot.

The denormalized docs remain what they were: an O(1) anchor for the rules'
`getAfter()` checks and for the client's pre-write checks. The backfill script
(`scripts/backfill_balances.mjs`) and `replaceAll` rebuild them from the ledger.

## Subscriptions (recurring expenses): client-triggered catch-up, not a server schedule

A subscription (`users/{uid}/subscriptions/{id}`) is a fixed monthly charge
(name, amount, dueDay) the user registers once. The "automatic" part — an
[Expense] appearing on the due date without the user typing it in — has two
possible designs, same trade-off as the Option A/B split above:

- **Chosen: client-triggered catch-up.** `FirestoreService.catchUpSubscriptions`
  runs once per signed-in session (`recurringChargesCatchUpProvider`, watched
  from `AppShell`), computes every due date each subscription has missed since
  it was last charged, and creates one account-level `Expense` per missed
  month, oldest first — going through the exact same account-balance gate as a
  manual expense (it will not overdraw the account; an unaffordable due date is
  retried next run instead of failing loudly). This stays on the free Spark
  tier: no Cloud Scheduler, no Cloud Function. The real-world consequence is
  that a due date is only ever charged the next time the app is OPENED on or
  after it — never while the app is closed.
- **Not chosen: server-scheduled charging.** A Cloud Scheduler job hitting a
  Cloud Function daily could charge exactly on the due day regardless of
  whether the app is open, but requires the paid Blaze plan (same cost gate as
  Option A above) — declined for the same reason Option A was declined.

**Installment purchases reuse this verbatim.** `FirestoreService.
catchUpInstallmentPurchases` is called right after `catchUpSubscriptions` in
the same provider, on the same per-session trigger — the only difference is
it stops once every installment has been billed instead of running forever.
No separate cost decision was needed: it was never going to be anything but
client-triggered once subscriptions settled that question.

If this ever needs to become "charges even if you never open the app",
revisit alongside Option A — the two decisions share the same Blaze
enablement step.

### Two sessions at once do not double-charge

Because catch-up is client-triggered, nothing stops two sessions from running
together — phone and web open at the same time, or two tabs. The
`subscriptions.get()` that lists the work happens OUTSIDE the transaction, so
both sides can see the same charge as still owed.

The fix is the re-read inside the transaction: before writing, each charge
re-reads its own doc via `tx.get` and only proceeds if it's still where it
expected (`lastChargedDate` earlier than the due date in question, or
`chargedInstallments` exactly at the installment being billed). That covers
both halves of the problem:

1. The doc joins the transaction's read set, so the other device's concurrent
   write becomes a detected conflict rather than a blind overwrite.
2. The retry that conflict triggers re-runs the body — and since Firestore
   only refreshes what the transaction itself read, without this re-read it
   would re-run against the stale object captured outside and bill again the
   month the other device just billed.

The same path covers a doc deleted mid-run (it's skipped, not resurrected).
All reads precede all writes, as Firestore requires.

### Paying ahead and paying off

An installment purchase isn't only a fixed schedule: you can pay extra one
month, or settle the whole thing. `FirestoreService.payInstallmentPurchase`
creates an ordinary `Expense` (out of the account or an envelope, chosen at
payment time — not necessarily the same source as the monthly charges) and
adds the amount to `amortizedAmount`.

The effect is on the TERM, not the installment: the outstanding balance is
`totalAmount − installments already billed − amount paid ahead`, and catch-up
simply stops once it reaches zero. A purchase can be settled with occurrences
still on the calendar — which is why what decides whether it's over is the
outstanding balance (`isSettled`), not the `chargedInstallments` counter.

Two details worth recording:

- The payment is **clamped to what is still owed**, read inside the
  transaction. That is what makes the "pay it all off" button safe: it sends
  the outstanding it last saw, and if a scheduled charge landed in between,
  the clamp prevents an overpayment.
- The final scheduled charge is clamped the same way
  (`installmentChargeAmount`), so it can never bill past the debt after an
  early payment. With no extra payments it is a no-op — it reproduces the
  original "rounding remainder lands on the last installment" behavior.

### A pending charge is shown, not hidden

When the account balance can't cover a charge, catch-up stops at that
occurrence and retries on the next run — the account never goes negative.
That's correct, but it used to be invisible: a subscription that hadn't
charged in months looked exactly like a paid one.

The Gastos screen now counts what's left pending with the SAME functions
catch-up bills from (`lib/services/recurring_schedule.dart`), and shows it in
two places: a warning at the top of the card and the count on each
subscription/purchase row. The count only appears once catch-up has finished
— before that everything due looks "pending" simply because nothing has run
yet. And if catch-up itself fails, the warning says so instead of blaming the
balance: `recurringChargesCatchUpProvider` logs and surfaces the failure as
an `AsyncError` instead of swallowing it, and the screen tells the two states
apart.

### One bad document does not stop the others

`catchUpSubscriptions` tries each subscription inside its own `try`, and
`recurringChargesCatchUpProvider` runs `catchUpInstallmentPurchases` even if the
subscription pass failed. The first error is rethrown at the end, so the
provider still ends as an `AsyncError` ("the run did not finish cleanly") while
everything else was billed. Before this, one malformed or rule-denied document
aborted all later charges. Covered by `test/services/firestore_service_test.dart`
and `test/providers/recurring_catch_up_provider_test.dart`.

### Coming back after days

The catch-up runs once per session, and `todayProvider` is read once, so an app
left in the background for days would keep the day it started on. `AppShell`
(`didChangeAppLifecycleState`, state `resumed`) compares the stored "today" with
the real date and, when the day changed, invalidates both providers (at most once
per day). Pull-to-refresh on the pages that list charges (`CatchUpRefresh`) re-runs
the catch-up on demand.

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
  Every `>= 0` floor in the rules is really `>= -1e-9` (`nonNegBal`), the
  same float tolerance the client uses (`FirestoreService._eps`): balances
  are running double sums, so a doc can hold `48.129999999999995` while the
  UI shows R$ 48,13, and spending that "48.13" in full lands at `-7e-15`. A
  strict `>= 0` rejected that with a raw permission error (bug reported
  2026-09-23). The exact delta linkage is unchanged, so the tolerance can't
  accumulate into a real negative.
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
- **Self-inflicted drift is possible, cross-user harm is not.** *(Description
  corrected — the mechanism is simpler than previously documented here. The
  conclusion is unchanged and still accepted.)* A client can rewrite its own
  balance docs **directly**: there is no delta linkage on a write to a balance
  document at all. A plain `set(users/{uid}/meta/account, {balance:
  999999999})` on an **already-existing** doc is accepted — no teardown, no
  delete-then-recreate, no linked ledger op — and `balances/{catId}` likewise
  takes any non-negative value, **raised or lowered**, via the `>= 0` and
  `>= balBefore` branches. The `getAfter()` delta check is attached to LEDGER
  writes, not to the balance docs themselves. Separately, a client that
  deletes its balance doc first can also write ledger docs with no delta check
  and re-create the balance at any non-negative value — and, for a `spend`
  caixinha specifically, at any negative value too (`catMayHoldNeg`, the
  genesis-only escape hatch — see "Descongelar via teardown" below).
  All data is single-tenant, so this only corrupts the user's OWN numbers, and
  the UI recomputes balances from the ledger anyway. The real security boundary
  (no cross-user read/write) is enforced unconditionally by `isOwner()`.
  Closing this would require summing the ledger (impossible in rules) or Cloud
  Functions (Blaze, declined) — so it is the accepted Option-B ceiling, not an
  oversight. Pinned by `test/rules/rules.test.mjs`, "the bypass needs NO
  teardown".
- **`Infinity` used to neutralise the delta check entirely — CLOSED.**
  `Infinity` is a valid Firestore double that satisfies `>= 0`, and it made
  `getAfter().balance == balBefore + delta` true for *every* delta, because
  `Infinity == Infinity + x`. One write of `{balance: Infinity}` therefore
  disabled the whole Option B money-integrity model for that user — a cheaper
  and more total bypass than the teardown one above. Every amount and balance
  now carries a finite upper bound, which rejects `Infinity`; `NaN` was
  already rejected because it fails every comparison. Pinned by "non-finite
  numbers are rejected".
- **Allocation/expense edits are restricted** to keep the rules tractable:
  `updateAllocation` keeps the same caixinha, `updateExpense` keeps the same
  target (caixinha vs account). Re-homing is delete + recreate. The edit sheet
  (`edit_transaction_sheet.dart`) reaches these paths for incomes and expenses
  from the lists. It also has an `EditableAllocation` case for plain
  allocations, but no screen currently builds one (see "Known constraints" in
  `docs/ARQUITETURA.md`), so `updateAllocation` is exercised by tests, not by
  the UI. A transfer leg is never editable on its own. **All three updates add
  the delta in one step (`balance + (new - old)`), exactly like the rules**,
  because the rules compare with exact `==` and `(balance - old) + new` differs
  in the last bit for some values (that used to cause an occasional
  `permission-denied` on a legitimate edit; confirmed on the emulator, pinned by
  `describe('edits: balance arithmetic parity with the rules (floating point)')`,
  9 tests).
- **`deleteCategory` refuses a caixinha that took part in a transfer.**
  Transfers are reachable from the UI. Deleting a caixinha that holds a
  transfer leg would orphan the paired leg in the other caixinha and, for a
  source caixinha, push `meta/account` above the ledger (the sum reversed into
  the account only counts plain allocations). The client throws a `StateError`
  ("took part in a transfer; undo the transfer first", localized as
  `errorCategoryHasTransfer`); the user undoes the transfer (`deleteAllocation`
  on either leg removes both) and then deletes. The Categorias screen disables
  the remove button up front with an explanation. Two more refusals, both before
  anything is written: a negative balance, and more than 495 records to cascade
  (`FirestoreService.maxCascadeDocs`; the cascade is one transaction, which holds
  at most 500 writes, and the rules read it as one commit so it can't be split;
  localized as `errorCategoryTooBig`). Pinned by the `deleteCategory cascade`
  tests.
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
- **App-side guard against converting a negative `spend` caixinha to `save`,
  or deleting it, while it owes a debt — IMPLEMENTED** (this used to be the one
  open item from the `allowNegative` security review). `updateCategory` reads the
  balance doc and refuses spend → save while it is negative; `deleteCategory`
  refuses a negative balance inside its transaction; the Categorias screen
  disables the remove button (`hasUnsettledDebt`) up front. The rules
  (`convertsSpendToSave`, `catDebtFree`) remain the guarantee that holds even if
  the client is bypassed, so a user can no longer back themselves into a backup
  that `replaceAll` step 0 refuses as `BALANCE CORRUPTION` through the normal UI.

## Integration surface

There is no REST/GraphQL API in this app — the boundary where the client
reads/writes data is the Firestore SDK, plus a parallel, unused Cloud
Functions implementation of the same operations. Both are documented below in
their own shape.

### 1. Firestore, direct from the client (live)

The client reads and writes Firestore directly through
`lib/services/firestore_service.dart` — there is no backend of the app's own
in the request path; money integrity is enforced by `firestore.rules`
instead of a trusted server (see "Option B" above). Every operation below is
addressed by a path under `users/{uid}`; see `docs/ARQUITETURA.md` for the
full `lib/` layer breakdown and one write traced end to end.

**Who can call it (applies to every path below):** `isOwner(uid)` in
`firestore.rules` — `request.auth.uid == uid`. No cross-user read or write is
possible. On the client, every stream/write call is additionally gated on
being signed in: `firestoreServiceProvider` (`lib/providers/providers.dart`)
is `null` while signed out, and every screen reads/writes through it rather
than instantiating `FirestoreService` itself.

**Reads — realtime streams**, one per collection, each a `.snapshots()`
mapped to the matching Dart model:

| Method | Firestore path |
|---|---|
| `watchCategories()` | `users/{uid}/categories` |
| `watchIncomes()` | `users/{uid}/incomes` |
| `watchAllocations()` | `users/{uid}/allocations` |
| `watchExpenses()` | `users/{uid}/expenses` |
| `watchSubscriptions()` | `users/{uid}/subscriptions` |
| `watchInstallmentPurchases()` | `users/{uid}/installmentPurchases` |
| `watchAllIncomes()` / `watchAllAllocations()` / `watchAllExpenses()` | same three ledger collections, **no `.limit()`** — used only by the Dashboard summary (see "Dashboard balance re-sums the ledger") |
| `watchAnalyticsOptOut()` | `users/{uid}/meta/settings` (`analyticsOptOut`, default `false`) |
| `watchTutorialProgress()` | `users/{uid}/meta/tutorials` |

`watchIncomes`/`watchAllocations`/`watchExpenses` are windowed (latest 2000 by
`date`); `watchCategories`/`watchSubscriptions`/`watchInstallmentPurchases` are
capped at 500.

A stream never throws in the request sense — a permission-denied or dropped
connection surfaces as an `AsyncError` on the matching `StreamProvider`,
which screens (via `ref.watch(...).value`) currently treat the same as "not
loaded yet" rather than a dedicated error state. No dedicated
stream-error UI is planned (maintainer, 2026-11-16); today a denied/broken
stream just looks like it never finishes loading.

**Writes — one `FirestoreService` method per operation, each a Firestore
transaction.** "Fails with" lists the `StateError` message(s) thrown BEFORE
the write is attempted (mapped to a localized string by
`friendlyErrorMessage`, `lib/utils/errors.dart`); if a client-side check here
is ever wrong or bypassed, the same write is still rejected server-side by
`firestore.rules` with `FirebaseException(code: 'permission-denied')` — that
rejection, not the `StateError`, is the actual security boundary, the
`StateError` only exists for a faster/friendlier message. "Also writes" is
what changes beyond the obvious document.

- **Categories** — `users/{uid}/categories/{id}`, validated by
  `validCategory` in `firestore.rules`:
  - `createCategory(name, recurring, monthlyBudget?, kind?, goalAmount?, allowNegative?) → Category`.
    Also writes: `users/{uid}/balances/{id}` at `{ balance: 0 }`.
  - `updateCategory(id, name?, recurring?, monthlyBudget?, clearMonthlyBudget?, kind?, goalAmount?, clearGoalAmount?, allowNegative?)`.
    Metadata-only, never touches the balance doc. Fails with:
    `'category not found'`; `'cannot convert a caixinha with a negative
    balance to a savings box; settle the debt first'` (converting `spend` →
    `save` while the caixinha holds a debt).
  - `deleteCategory(id)`. Fails with: `'cannot delete a caixinha that took
    part in a transfer; undo the transfer first'` (`errorCategoryHasTransfer`),
    `'too many records to remove at once; remove some first'` (more than 495
    allocations+expenses, `errorCategoryTooBig`), `'cannot delete a caixinha
    with a negative balance; settle the debt first'`. All three are thrown
    before anything is written. Also writes: cascade-deletes every
    `allocations`/`expenses` doc referencing this category, restores
    `meta/account` by the sum of the allocations that had drawn from it, and
    deletes `balances/{id}`.
  - **Offline behavior of the non-transactional writes below
    (`createCategory`, `updateCategory`, the subscription/installment creates,
    deletes and the auto-charge toggle):** they go through
    `FirestoreService.ackOrQueue`, which waits up to 4 s for the server ack and
    then returns, leaving the write in Firestore's local queue to be sent when
    the connection returns. A rules denial inside the 4 s still throws; after
    it, a denial can no longer reach the screen. Money transactions
    (`createExpense`, incomes, allocations, transfers, edits) are not wrapped:
    they fail immediately offline.

- **Incomes** — `users/{uid}/incomes/{id}`, `validIncome`. Only ever move
  `meta/account`:
  - `createIncome(date, amount, source, description?) → Income`. Fails with:
    `'income amount cannot be negative'`. Also writes: `meta/account` (+amount).
  - `updateIncome(id, ...)`. Fails with: `'income not found'`,
    `'lowering income would overdraw the account'`.
  - `deleteIncome(id)`. Fails with: `'deleting this income would overdraw
    the account'`.

- **Allocations** — `users/{uid}/allocations/{id}`, `validAllocation` /
  `isTransferLeg`. Account → caixinha:
  - `createAllocation(categoryId, amount, date) → Allocation`. Fails with:
    `'allocation amount cannot be negative'`, `'category not found'`,
    `'amount exceeds account balance'`. Also writes: `meta/account`
    (−amount) AND `balances/{categoryId}` (+amount), same transaction.
  - `updateAllocation(id, ...)`. The caixinha is fixed (re-homing is
    delete+recreate); a transfer leg can't be edited individually. Fails
    with: `'allocation not found'`, an unsupported-edit message for a
    transfer leg, `'category not found'`, `'amount exceeds account
    balance'`, `'reducing this allocation would overdraw the caixinha'`.
  - `deleteAllocation(id)`. If the allocation is a transfer leg, BOTH legs
    are removed via `deleteTransfer` — never a half-transfer. Fails with:
    `'removing this allocation would overdraw the caixinha'`.
  - `createTransfer(fromCategoryId, toCategoryId, amount, date) → transferId`.
    Fails with: `'transfer amount must be positive'`, `'source and
    destination must differ'`, `'source category not found'`,
    `'destination category not found'`, `'amount exceeds source caixinha
    balance'`. Also writes: TWO allocation docs sharing the returned
    `transferId` (negative leg on the source, positive leg on the
    destination) and BOTH `balances/{fromCategoryId}` /
    `balances/{toCategoryId}` — `meta/account` is untouched.
  - `deleteTransfer(transferId)`. Fails with: `'undoing this transfer would
    overdraw a caixinha'`. Reverses both legs.

- **Expenses** — `users/{uid}/expenses/{id}`, `validExpense` /
  `isCaixinhaExpense` / `sameExpenseTarget` / `sameExpenseSource`. From an
  envelope, or straight from the account:
  - `createExpense(date, amount, categoryId?, description?) → Expense`.
    Fails with: `'expense amount cannot be negative'`, `'category not
    found'`, `'amount exceeds available balance'`. Also writes:
    `meta/account` (−amount) if `categoryId` is null, else
    `balances/{categoryId}` (−amount).
  - `updateExpense(id, ...)`. The target (envelope vs account) is fixed —
    moving an expense is delete+recreate. Fails with the same set as
    create, plus `'expense not found'` and an unsupported-edit message for
    the target/source fields.
  - `deleteExpense(id)`.

- **Subscriptions** — `users/{uid}/subscriptions/{id}`,
  `validSubscription`. A fixed recurring monthly charge; the doc itself
  carries no balance:
  - `createSubscription(name, amount, dueDay, categoryId?) → Subscription`.
    Fails with: `'subscription amount must be positive'`, `'dueDay must be
    between 1 and 31'`.
  - `updateSubscription(id, ...)`. Fails with: `'subscription not found'`,
    plus the two above.
  - `deleteSubscription(id)`.
  - `setSubscriptionAutoCharge(id, enabled)` — single-field toggle, no
    balance implication.
  - `catchUpSubscriptions() → RecurringChargeReport`. Not addressed by a
    single path — reads every subscription and, for each one, may write one
    or more `expenses/{id}` docs (one per missed due date, oldest first),
    each going through the same `meta/account`/`balances/{categoryId}` side
    effect as `createExpense`, tagged `sourceType: 'subscription'`,
    `sourceId: <subscriptionId>`. Never throws for an unaffordable due
    date — it's silently skipped and retried next call, reflected in the
    returned `RecurringChargeReport` (count/total charged) rather than an
    error. Called once per session, not by a server schedule — traced end
    to end in `docs/ARQUITETURA.md`.
  - `chargeSubscriptionNow(id) → RecurringChargeReport` — same mechanism for
    one subscription, ignoring `autoChargeEnabled`.

- **Installment purchases** — `users/{uid}/installmentPurchases/{id}`,
  `validInstallmentPurchase`. A bounded counterpart to a subscription:
  - `createInstallmentPurchase(name, totalAmount, installments, purchaseDate, firstChargeDate, categoryId?) → InstallmentPurchase`.
    Fails with: `'installment purchase amount must be positive'`,
    `'installments must be between 2 and 36'`.
  - `deleteInstallmentPurchase(id)`.
  - `updateInstallmentDueDay(id, day?)` — moves the day the remaining
    installments fall due, or clears the move with `null`. Fails with:
    `'due day must be between 1 and 31'`, `'installment purchase not found'`.
  - `payInstallmentPurchase(id, amount, categoryId?)`. Fails with:
    `'payment amount must be positive'`, `'installment purchase not
    found'`, `'installment purchase is already settled'`, plus a
    balance/category message. Also writes: an ordinary `Expense` (through
    the same account/envelope gate as `createExpense`) and increments
    `amortizedAmount` (clamped to what's still owed).
  - `catchUpInstallmentPurchases() → RecurringChargeReport`. Same mechanism
    as `catchUpSubscriptions`, tagged `sourceType: 'installment'`, stopping
    once `chargedInstallments == installments` per purchase.

- **App state docs** — not money, not validated against the ledger:
  - `setAnalyticsOptOut(bool)` → `users/{uid}/meta/settings` (validated:
    `keys().hasOnly(['analyticsOptOut'])`, bool).
  - `setTutorialProgress(page, state, {version})` →
    `meta/tutorials.set({page: {state, v}}, merge)`; `resetTutorial(page)` →
    `FieldValue.delete()` on that key; `resetAllTutorials()` → deletes the doc.
    Fails with `permission-denied` for an unknown page id, a `state` other than
    `done`/`skipped`, or `v` outside 1..1000. The app swallows (logs) such a
    failure and keeps the page "seen" for the session.
- **Account deletion** — `deleteAllUserData()` (balance docs + `meta/settings`
  + `meta/tutorials` first, in already-committed batches, with one
  `accountDeletionLog` create in the first batch; then the ledger collections,
  chunked), then `AuthService.deleteAccount()`. Preceded by
  `AuthService.hasRecentLogin()` in `SettingsPage`. See "User data: export &
  deletion" and "`accountDeletionLog`" above.
- **Local-only state (not an integration surface, listed so nobody looks for it
  in Firestore):** language (`localeProvider`) and theme
  (`themeModeProvider`, key `themeMode`) live in `shared_preferences` on the
  device.
- **Google Play in-app update** (`AppUpdateService`, plugin `in_app_update`):
  `isUpdateAvailable()`, `startUpdate()` (flexible; true only once the download
  finished), `restartToInstall()`. Android installed from Play only; anything
  else answers "no update".
- **Backup/restore** (`ImportExportService`, on top of
  `FirestoreService.fetchAll()`/`replaceAll(AppDb)`): not addressed by a
  Firestore path — `fetchAll` reads the six ledger collections into a JSON
  file (Ajustes → Exportar JSON), `replaceAll` wipes and rewrites all six
  plus recomputes both balance doc types from the restored ledger, through
  the rules' genesis/teardown escape hatch (see "Option B — what is
  implemented" above). Fails with a `StateError` naming the first
  inconsistent balance found — a **step 0** pre-validation that runs before
  anything is written, so a bad backup is rejected atomically (see "F1"
  above).

`FirestoreService`'s public method signatures are the stable seam regardless
of which option is live — they would not change if writes moved from direct
(today) to a callable (below).

### 2. Cloud Functions callables (`functions/index.js`) — written, NOT deployed

`functions/` implements the same write operations as callable Cloud
Functions (`onCall`) — "Option A" above. It exists as reference only; nothing
in the app calls it and `firebase.json` has no `functions` block, so
`firebase deploy` never touches it (see `functions/README.md`). If it were
ever wired in:

- **How addressed:** callable name, e.g.
  `FirebaseFunctions.instance.httpsCallable('createExpense')`.
- **Payload / response:** `{ ...args }` matching `FirestoreService`'s
  argument names 1:1 (same list as above); returns `{ id }` (or
  `{ transferId }` for `createTransfer`).
- **Who can call it:** `requireUid(request)` throws
  `HttpsError('unauthenticated', ...)` if `request.auth?.uid` is absent; the
  function then only ever touches that uid's own subtree — same boundary as
  `isOwner(uid)` above, just enforced in code (admin privileges) instead of
  rules.
- **How it fails:** `HttpsError` codes — `'failed-precondition'` (a money
  invariant would be violated), `'not-found'` (a referenced doc is missing),
  `'invalid-argument'` (malformed payload), `'unauthenticated'`.
- **Coverage gap (verified in the code, not a guess):** `functions/index.js`
  only has callables for `createCategory`/`updateCategory`/`deleteCategory`,
  `createIncome`/`updateIncome`/`deleteIncome`,
  `createAllocation`/`updateAllocation`/`deleteAllocation`,
  `createTransfer`/`deleteTransfer`,
  `createExpense`/`updateExpense`/`deleteExpense` — it predates
  `subscriptions`/`installmentPurchases` and has no callables for either.
  Adopting Option A today would need those added first.
