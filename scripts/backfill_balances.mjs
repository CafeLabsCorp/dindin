/**
 * Dindin — one-time backfill of the denormalized balance docs (Option B).
 *
 * WHY: `firestore.rules` Phase 2 enforces money integrity by reading O(1)
 * balance documents that mirror the summed ledger:
 *   users/{uid}/meta/account      { balance }   (general account balance)
 *   users/{uid}/balances/{catId}  { balance }   (one per caixinha)
 * Data already in production has ledger docs but NOT these balance docs. Until
 * they exist and are correct, the client's transactions would initialize them
 * from a wrong (zero) base and every subsequent integrity check would be off.
 *
 * So this script MUST run BEFORE the Phase-2 rules + the new client reach real
 * users. It is idempotent: it recomputes each balance from the ledger and
 * overwrites the balance docs, so it is safe to re-run.
 *
 * COST: runs on the FREE Spark tier. It uses the Admin SDK with a service
 * account key (Admin access is available on every plan — only Cloud Functions
 * require Blaze). Admin writes bypass Security Rules, so no rule-ordering
 * dance is needed here.
 *
 * HOW TO RUN:
 *   1. Firebase console -> Project settings -> Service accounts ->
 *      "Generate new private key". Save the JSON somewhere OUTSIDE the repo.
 *   2. cd scripts && npm install
 *   3. GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/serviceAccount.json \
 *        node backfill_balances.mjs --dry-run     # inspect first
 *   4. Re-run without --dry-run to write.
 *   5. --verify checks every /users/{uid} has a meta/account balance doc
 *      (does not read/write anything else). This is the deploy-gate
 *      preflight called by scripts/deploy.sh right before `firestore.rules`
 *      goes out: rules Phase 2 assumes that doc exists for every user, so a
 *      gap here would lock a user out of writes the instant the new rules
 *      land. Exits non-zero (and lists the affected uids) if any are missing.
 *
 * The service account key is a secret: never commit it, never paste it into
 * chat, keep it out of the repo tree.
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const DRY_RUN = process.argv.includes("--dry-run");
const VERIFY = process.argv.includes("--verify");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const num = (v) => (typeof v === "number" && !Number.isNaN(v) ? v : 0);

// Sums over many docs accumulate binary floating-point error (e.g. an account
// that is truly R$0 can sum to -1.7e-13). Round to the cent before comparing
// against zero or persisting — otherwise a mathematically-zero balance can be
// stored as a hair negative, which fails the rules' `>= 0` check for real.
const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;

// Legacy data predating the client-side invariants can legitimately sum
// negative. A negative balance doc under Phase-2 rules blocks that user's
// future spending writes, so negatives must be reconciled in the ledger BEFORE
// the real run — never auto-clamped, which would hide the inconsistency.
const negatives = [];

async function backfillUser(uid) {
  const base = db.collection("users").doc(uid);
  const [incomes, allocations, expenses, categories] = await Promise.all([
    base.collection("incomes").get(),
    base.collection("allocations").get(),
    base.collection("expenses").get(),
    base.collection("categories").get(),
  ]);

  const totalIncome = incomes.docs.reduce((t, d) => t + num(d.get("amount")), 0);
  const totalAllocated = allocations.docs.reduce((t, d) => t + num(d.get("amount")), 0);
  const accountExpenses = expenses.docs
    .filter((d) => d.get("categoryId") == null)
    .reduce((t, d) => t + num(d.get("amount")), 0);
  const account = round2(totalIncome - totalAllocated - accountExpenses);

  // One balance per existing category, plus any category id referenced by the
  // ledger (defensive — should match the category set).
  const catBalances = new Map();
  for (const c of categories.docs) catBalances.set(c.id, 0);
  for (const a of allocations.docs) {
    const cat = a.get("categoryId");
    if (cat == null) continue;
    catBalances.set(cat, (catBalances.get(cat) ?? 0) + num(a.get("amount")));
  }
  for (const e of expenses.docs) {
    const cat = e.get("categoryId");
    if (cat == null) continue;
    catBalances.set(cat, (catBalances.get(cat) ?? 0) - num(e.get("amount")));
  }
  for (const [cat, bal] of catBalances) catBalances.set(cat, round2(bal));

  console.log(`user ${uid}: account=${account.toFixed(2)}`);
  if (account < 0) {
    negatives.push(`user ${uid}: account=${account.toFixed(2)}`);
    console.warn(`  *** NEGATIVE BALANCE: account=${account.toFixed(2)} ***`);
  }
  for (const [cat, bal] of catBalances) {
    console.log(`  caixinha ${cat}: ${bal.toFixed(2)}`);
    if (bal < 0) {
      negatives.push(`user ${uid} / caixinha ${cat}: ${bal.toFixed(2)}`);
      console.warn(`  *** NEGATIVE BALANCE: caixinha ${cat}=${bal.toFixed(2)} ***`);
    }
  }

  if (DRY_RUN) return;

  const batch = db.batch();
  batch.set(base.collection("meta").doc("account"), { balance: account });
  for (const [cat, bal] of catBalances) {
    batch.set(base.collection("balances").doc(cat), { balance: bal });
  }
  await batch.commit();
}

async function verify() {
  const users = await db.collection("users").listDocuments();
  if (users.length === 0) {
    console.log("No users found under /users.");
    return;
  }
  console.log(`Verifying meta/account exists for ${users.length} user(s)...`);
  const missing = [];
  for (const u of users) {
    const snap = await db.collection("users").doc(u.id).collection("meta").doc("account").get();
    if (!snap.exists) {
      missing.push(u.id);
      console.warn(`  *** MISSING meta/account for user ${u.id} ***`);
    } else {
      console.log(`  ok: user ${u.id} -> balance=${snap.get("balance")}`);
    }
  }
  if (missing.length > 0) {
    console.error(`\n*** ${missing.length} user(s) missing meta/account — do NOT deploy the rules yet. Re-run the backfill (without --dry-run) first: ***`);
    for (const uid of missing) console.error(`  ${uid}`);
    process.exit(1);
  }
  console.log("Verify OK — every user has a meta/account balance doc.");
}

async function main() {
  if (VERIFY) {
    await verify();
    return;
  }
  const users = await db.collection("users").listDocuments();
  if (users.length === 0) {
    console.log("No users found under /users.");
    return;
  }
  console.log(`${DRY_RUN ? "[DRY RUN] " : ""}Backfilling ${users.length} user(s)...`);
  for (const u of users) {
    await backfillUser(u.id);
  }
  if (negatives.length > 0) {
    console.warn(`\n*** ${negatives.length} NEGATIVE BALANCE(S) FOUND — reconcile the ledger before the real run: ***`);
    for (const n of negatives) console.warn(`  ${n}`);
  }
  console.log(DRY_RUN ? "Dry run complete — nothing written." : "Backfill complete.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
