# Deploy, CI, and rollback

Operational guide for a solo maintainer running/debugging Dindin's deploy
without rebuilding context. Read `docs/BACKEND.md` first for *why* the deploy
order is what it is — this file is the *how*, plus CI and rollback.

## CI (`.github/workflows/ci.yml`)

Runs on every push to `main`. Two independent jobs, both on GitHub Actions'
free tier (public/private repo, this volume of pushes — nowhere near the
2,000 free minutes/month):

- **`flutter`** — `flutter pub get && flutter analyze && flutter test`.
  Platform-agnostic (no Android/Windows packaging here — that's a separate
  backlog item).
- **`rules`** — spins up the Firestore emulator (`firebase-tools
  emulators:exec`) and runs `test/rules/rules.test.mjs` against it (13 tests
  covering the Phase-2 money-integrity rules, including the
  `getAfter()`/null-teardown paths that can't be exercised from Dart). Uses
  the emulator only — never touches production, needs no project
  credentials.

CI does **not** deploy anything. It's a safety net for the code; shipping to
production is still the deliberate manual action below.

To debug a CI failure locally, run the same commands: `flutter analyze`,
`flutter test`, or `firebase emulators:exec --only firestore --project
dindin-rules-test "npm test --prefix test/rules"` (see the header of
`test/rules/rules.test.mjs` for the two-terminal manual variant).

## Deploying (`scripts/deploy.sh`)

Encodes the mandatory release order from `docs/BACKEND.md` as a script with
hard gates, so a step can't be skipped or reordered by accident:

1. Interactive confirmation that the manual data backup (Ajustes -> Exportar
   JSON, per real user) was taken. Aborts if not confirmed.
2. Dry-run backfill (`backfill_balances.mjs --dry-run`); aborts if the output
   contains the marker `BALANCE CORRUPTION` — a negative balance that should
   never exist (the general account, a `save` caixinha, or an orphan id). A
   legitimate open/frozen debt on a `spend` caixinha (the `allowNegative`
   feature) prints as an "open debt" warning WITHOUT that marker and does
   NOT block the deploy — see `docs/BACKEND.md`, "Option B residual
   limitations" for how the script tells the two apart.
3. Final interactive confirmation before any real writes/deploys.
4. Real backfill run (idempotent).
5. Preflight: `backfill_balances.mjs --verify` — confirms every
   `/users/{uid}` has a `meta/account` doc. Aborts before touching rules if
   anyone is missing one.
6. `firebase deploy --only firestore:rules --project dindin-cafelabs`.
7. `flutter build web` + `firebase deploy --only hosting --project
   dindin-cafelabs`.

Run it from the repo root:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json  # never commit this
scripts/deploy.sh
```

This script is meant for interactive, by-hand use during a release — it is
not run in CI. If you only need to publish a hosting-only change (no rules/
schema change), the old manual sequence is still valid and safe:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

(Skip `scripts/deploy.sh` entirely for pure UI changes — the backup/backfill
gate exists specifically for changes that touch `firestore.rules` or the
balance docs, not every deploy.)

## Rollback

### Firestore rules

The previous rules file lives in git history — this is the whole rollback
path, no separate backup needed:

```bash
git log --oneline -- firestore.rules        # find the last-good commit
git show <good-commit>:firestore.rules > firestore.rules
firebase deploy --only firestore:rules --project dindin-cafelabs
git checkout -- firestore.rules             # restore the working tree after
```

This only touches rules — it does not affect the balance docs written by the
backfill, which stay valid under either rules version (Phase 1 rules simply
don't check them).

### Hosting (web client)

Firebase Hosting keeps prior releases automatically. To roll back without a
rebuild:

- Firebase console -> Hosting -> your site -> "Release history" -> pick the
  previous release -> **Rollback**. This is a few clicks, no CLI needed, and
  is the fastest path back to a known-good client.
- Or from the CLI: `firebase hosting:clone <site>:<previous-release-id>
  <site>:live --project dindin-cafelabs`.

### User data

The **only** rollback for user data is the manual JSON export taken during
the deploy-gate backup step (`scripts/deploy.sh` step 1 / `docs/BACKEND.md`).
To restore: open the app, sign in as the affected user, Ajustes -> Importar
JSON, pick the backup file. This replaces that user's four ledger
collections and resets their balance docs from the imported ledger — there
is no partial/selective restore, so use the most recent good export.

There is no automated point-in-time backup of Firestore itself (Spark/free
tier has no scheduled export product) — the per-user JSON export is the
entire data-durability story right now. If usage grows enough that "ask each
user to have exported recently" stops being an acceptable bar, revisit a
scheduled export (Blaze-tier `gcloud firestore export` to Cloud Storage, or a
scripted Admin-SDK dump) — out of scope for this MVP cycle.

## Monitoring — current gap, recommended next step (not set up in this cycle)

This cycle's scope was CI + the backup/rollback gate. Flagging explicitly:
**there is currently no uptime or error-rate visibility on the live app** —
an outage or a spike in rejected writes (e.g. from a rules regression) would
only be discovered from a user report. That's an acceptable, deliberate gap
for the code changes going out *this* cycle (rules changes are additive/
backward-compatible per `docs/BACKEND.md` and were verified against the
emulator), but it should not stay unaddressed for long as real users rely on
this app. Cheapest options, in order of effort:

- **Uptime**: a free external monitor (e.g. UptimeRobot free tier — 50
  monitors, 5-minute interval, email/webhook alert) pointed at
  `https://dindin-cafelabs.web.app`. Takes about 5 minutes to set up and
  needs no code change; requires only creating an account, so it's left for
  the owner rather than done silently here.
- **Errors**: Firebase Crashlytics (free, already-integrated Firebase
  product) for client-side errors, or watching the Firebase console's
  Firestore "Rules" usage/denials panel after a rules deploy to catch a
  spike in rejected writes.
- **Usage/cost**: Spark is a hard-capped free tier (no billing account
  attached, so there's no surprise bill), but it still has daily quotas
  (reads/writes/deletes, egress). Set a budget/quota alert in the Firebase
  console (Usage and billing -> Details & settings) so you find out about
  quota pressure before users do, e.g. as a launch goes viral.
