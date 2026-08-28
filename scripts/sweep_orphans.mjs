/**
 * Dindin — orphan data sweep: purge Firestore data belonging to Auth users
 * that no longer exist (LGPD / Google Play "delete my account" backstop).
 *
 * WHY THIS EXISTS: the in-app "Excluir minha conta" flow deletes the user's
 * Firestore data and then the Auth user. Anything that interrupts it between
 * those two halves — the app is killed, the network drops, the required
 * re-auth is refused at the last step — leaves documents under
 * `users/{uid}`. That data is UNREACHABLE FOREVER: every rule keys on
 * `request.auth.uid`, and Firebase never reissues a uid. So it is invisible to
 * everyone (not a disclosure risk) but it still:
 *   * consumes the Spark plan's 1 GiB storage cap, which DOES NOT RESET, and
 *   * is an unmet deletion request — an LGPD and Play-policy problem, since
 *     the user asked to be forgotten and part of them wasn't.
 *
 * The same happens whenever an Auth user is deleted straight from the Firebase
 * console, which deletes the account but never its Firestore documents.
 *
 * WHY A SCRIPT AND NOT A FUNCTION: the usual answer is an
 * `onAuthUserDeleted`/`beforeUserDeleted` Cloud Function, but Cloud Functions
 * require the Blaze (paid) plan, which is deliberately not in use here — see
 * docs/BACKEND.md, "Option B". There is NO server-side hook on Spark, so a
 * periodic human-run sweep is the answer. It is not automatic; it is meant to
 * be run from a maintainer's machine (see the cadence note in
 * docs/BACKEND.md, "User data: export & deletion").
 *
 * COST: free. The Admin SDK works on every plan — only Cloud Functions need
 * Blaze. Admin writes bypass Security Rules, so none of the rule-ordering
 * dance the in-app deletion needs applies here: this can delete a caixinha
 * holding a frozen debt directly, in any order.
 *
 * HOW TO RUN (same credentials as backfill_balances.mjs):
 *   1. gcloud auth application-default login
 *      gcloud auth application-default set-quota-project dindin-cafelabs
 *   2. cd scripts && npm install
 *   3. GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/application_default_credentials.json \
 *      GOOGLE_CLOUD_PROJECT=dindin-cafelabs \
 *        node sweep_orphans.mjs --dry-run          # ALWAYS inspect first
 *   4. Re-run with --confirm to actually delete.
 *
 * There is no service-account key in this repo and there must never be one:
 * a key committed to git history is compromised permanently, not just until
 * it is removed. See scripts/.gitignore.
 *
 * FLAGS:
 *   --dry-run   list what WOULD be deleted; writes nothing. (Default: a run
 *               with neither flag refuses to do anything, so a mistyped
 *               command can never wipe data.)
 *   --confirm   actually delete. Required for any destructive action.
 *   --uid=UID   restrict to a single uid. Use this for a targeted cleanup
 *               after a user reports that account deletion failed halfway.
 *               Still requires the uid to have NO Auth user, unless --force.
 *   --force     with --uid, delete even if the Auth user still EXISTS. This
 *               is the "user asked me to delete their data by hand" path.
 *               Refuses to run without an explicit --uid, so it can never
 *               become a project-wide wipe.
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");
const CONFIRM = args.includes("--confirm");
const FORCE = args.includes("--force");
const UID_ARG = args.find((a) => a.startsWith("--uid="))?.slice("--uid=".length);

if (!DRY_RUN && !CONFIRM) {
  console.error(
    "Refusing to run: pass --dry-run to inspect, or --confirm to delete.\n" +
      "This script permanently removes user data; it never acts by default.",
  );
  process.exit(2);
}
if (FORCE && !UID_ARG) {
  console.error(
    "Refusing to run: --force requires an explicit --uid=UID.\n" +
      "Without it, --force would delete data for users whose accounts are alive.",
  );
  process.exit(2);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const auth = getAuth();

// Every subcollection a user's data can live in. `meta` and `balances` are the
// derived Option-B balance docs; the other six are the ledger itself — the
// same six that AppDb/replaceAll round-trips. Kept explicit rather than
// discovered dynamically so a typo in a collection name shows up as "0 docs"
// in the dry run instead of silently leaving data behind.
const USER_SUBCOLLECTIONS = [
  "meta",
  "balances",
  "categories",
  "incomes",
  "allocations",
  "expenses",
  "subscriptions",
  "installmentPurchases",
];

/** True iff an Auth user still exists for this uid. */
async function authUserExists(uid) {
  try {
    await auth.getUser(uid);
    return true;
  } catch (err) {
    if (err.code === "auth/user-not-found") return false;
    throw err; // a real error (network/permissions) must not read as "orphan"
  }
}

/** Counts, and optionally deletes, everything under users/{uid}. */
async function sweepUser(uid, { write }) {
  const base = db.collection("users").doc(uid);
  let total = 0;

  for (const name of USER_SUBCOLLECTIONS) {
    const snap = await base.collection(name).get();
    if (snap.empty) continue;
    total += snap.size;
    console.log(`    ${name}: ${snap.size} doc(s)`);
    if (!write) continue;

    // Admin deletes bypass rules, so plain 400-doc batches are fine here —
    // the rules' 20-document-access ceiling that constrains the CLIENT's
    // chunking (see docs/BACKEND.md, "Batch chunking") simply does not apply.
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const d of snap.docs.slice(i, i + 400)) batch.delete(d.ref);
      await batch.commit();
    }
  }

  // The users/{uid} document itself usually does not exist (only its
  // subcollections do), but delete it if it was ever materialized.
  const rootSnap = await base.get();
  if (rootSnap.exists) {
    total += 1;
    console.log("    users/{uid} root document: 1 doc");
    if (write) await base.delete();
  }

  return total;
}

async function main() {
  const write = CONFIRM && !DRY_RUN;
  const label = write ? "" : "[DRY RUN] ";

  const uids = UID_ARG
    ? [UID_ARG]
    : (await db.collection("users").listDocuments()).map((d) => d.id);

  if (uids.length === 0) {
    console.log("No users found under /users.");
    return;
  }

  console.log(`${label}Checking ${uids.length} uid(s) under /users...`);
  let orphanCount = 0;
  let docCount = 0;

  for (const uid of uids) {
    // --force already means "delete regardless of Auth state", so don't ask
    // Auth at all on that path: the answer can't change the outcome, and the
    // lookup would be the only thing needing Auth access in an environment
    // that may not have it (e.g. a Firestore-only emulator run).
    const exists = FORCE ? true : await authUserExists(uid);
    if (exists && !FORCE) {
      console.log(`  uid ${uid}: Auth user ALIVE — skipping (not an orphan).`);
      continue;
    }
    console.log(
      exists
        ? `  uid ${uid}: Auth user alive but --force given — deleting anyway.`
        : `  uid ${uid}: NO Auth user — orphaned data:`,
    );
    orphanCount += 1;
    docCount += await sweepUser(uid, { write });
  }

  console.log(
    `\n${label}${orphanCount} orphaned uid(s), ${docCount} document(s) ` +
      `${write ? "deleted" : "would be deleted"}.`,
  );
  if (!write && docCount > 0) {
    console.log("Re-run with --confirm to delete.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
