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

// A negative recomputed balance splits into two kinds, aligned EXACTLY with
// what `firestore.rules` will and won't re-materialize (catMayHoldNeg on the
// genesis path), so the deploy gate never diverges from the rules:
//
//   * LEGITIMATE DEBT — an EXISTING spend caixinha (kind 'spend' or legacy
//     null-kind) summing negative. This is a supported state: the debt was
//     incurred while allowNegative was on and may still be open (toggle on) or
//     FROZEN (toggle later turned off). The rules re-materialize it on restore,
//     and the backfill writes the negative balance doc as-is. NOT a gate
//     failure — reported as an informational warning only. A toggle-off spend
//     negative is indistinguishable, from the ledger alone, from an old
//     overspend bug; because the rules permit it either way, blocking here would
//     just recreate the "one open debt freezes every future deploy" defect this
//     change fixes. It's surfaced in the log for a human to eyeball.
//
//   * BALANCE CORRUPTION — a negative the rules will NOT re-materialize and that
//     should never exist: the general account (never allowed negative), a 'save'
//     caixinha (a savings box can't hold a debt), or an ORPHAN id referenced by
//     the ledger with no category doc (a cascade delete that left ledger behind
//     — unrecoverable by the rules, needs manual reconciliation). This DOES fail
//     the gate. Never auto-clamped, which would hide the inconsistency.
//
// The deploy gate (scripts/deploy.sh) aborts on the marker "BALANCE CORRUPTION"
// only; legitimate debts print without it and pass.
const debts = [];
const corruptions = [];

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
  // ledger (defensive — should match the category set). catMeta only has an
  // entry for categories that STILL EXIST; a ledger-only id is an orphan.
  const catBalances = new Map();
  const catMeta = new Map();
  for (const c of categories.docs) {
    catBalances.set(c.id, 0);
    catMeta.set(c.id, {
      kind: c.get("kind") ?? "spend", // legacy null-kind behaves as spend
      allowNegative: c.get("allowNegative") === true,
    });
  }
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
    // The general account may never legitimately be negative (no allowNegative
    // for it anywhere in the rules) -> always corruption.
    corruptions.push(`user ${uid}: account=${account.toFixed(2)}`);
    console.error(`  *** BALANCE CORRUPTION: account=${account.toFixed(2)} (the general account may never go negative) ***`);
  }
  for (const [cat, bal] of catBalances) {
    console.log(`  caixinha ${cat}: ${bal.toFixed(2)}`);
    if (bal >= 0) continue;
    const meta = catMeta.get(cat);
    if (meta === undefined) {
      // Ledger references a category that no longer exists. A cascade delete
      // should have removed this ledger too; it didn't. The rules can't
      // re-materialize it (no category doc to read) -> corruption.
      corruptions.push(`user ${uid} / caixinha ${cat} (no category doc): ${bal.toFixed(2)}`);
      console.error(`  *** BALANCE CORRUPTION: orphan caixinha ${cat}=${bal.toFixed(2)} (category was deleted but ledger remains) ***`);
    } else if (meta.kind !== "spend") {
      // A 'save' caixinha can never hold a debt.
      corruptions.push(`user ${uid} / caixinha ${cat} (kind=${meta.kind}): ${bal.toFixed(2)}`);
      console.error(`  *** BALANCE CORRUPTION: ${meta.kind} caixinha ${cat}=${bal.toFixed(2)} (only spend caixinhas may hold a debt) ***`);
    } else {
      // Existing spend caixinha: a legitimate debt the rules re-materialize.
      // The toggle only tells us whether it is still OPEN or FROZEN.
      const state = meta.allowNegative ? "open, allowNegative on" : "FROZEN, allowNegative off";
      debts.push(`user ${uid} / caixinha ${cat} (${state}): ${bal.toFixed(2)}`);
      console.warn(`  open debt (${state}) caixinha ${cat}=${bal.toFixed(2)} — legitimate, not blocking deploy`);
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
  if (debts.length > 0) {
    console.warn(`\n*** ${debts.length} open caixinha debt(s) — LEGITIMATE (spend caixinha with allowNegative), NOT blocking deploy: ***`);
    for (const d of debts) console.warn(`  ${d}`);
  }
  if (corruptions.length > 0) {
    console.error(`\n*** ${corruptions.length} BALANCE CORRUPTION(S) — a negative that should not exist. Reconcile the ledger before the real run: ***`);
    for (const c of corruptions) console.error(`  ${c}`);
  }
  console.log(DRY_RUN ? "Dry run complete — nothing written." : "Backfill complete.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
