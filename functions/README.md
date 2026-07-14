# functions/ — INACTIVE reference (Option A, not deployed)

This directory is the **Cloud Functions implementation of Option A** from
`docs/BACKEND.md`: server-side, transactional money-integrity writes running
under admin privileges. **It is not deployed and is not wired into the app.**

The product owner chose **Option B** (rules-only with denormalized balances on
the free **Spark** tier). Cloud Functions require the paid **Blaze** plan, so
this code stays dormant:

- `firebase.json` has **no `functions` block** — `firebase deploy` never touches it.
- The Flutter client writes directly to Firestore (see
  `lib/services/firestore_service.dart`), guarded by `firestore.rules` Phase 2.

## Why it's kept and not deleted

It is a complete, correct reference for the alternative design, and the migration
path is documented in `docs/BACKEND.md` (client method signatures are stable, so
switching a write from a direct transaction to a callable is a body-only change).
Keeping it preserves that option cheaply. It was retained rather than deleted
because it is uncommitted work from an earlier step of this initiative.

**If the owner prefers a lean repo, this whole directory can be safely deleted**
— nothing in the app, the rules, or the build depends on it.

## If Option A is ever adopted

See `docs/BACKEND.md` → "Option A — Cloud Functions". In short: enable Blaze,
`cd functions && npm install`, add a `functions` block to `firebase.json`,
`firebase deploy --only functions,firestore:rules`, then switch the client
methods to call the matching callables and tighten the rules to deny direct
ledger writes.
