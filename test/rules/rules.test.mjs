// Firestore Security Rules tests for Dindin's Phase-2 money-integrity rules
// (see /home/felip/projetos/dindin/firestore.rules and docs/BACKEND.md).
//
// WHY THIS FILE EXISTS AS A SEPARATE NODE HARNESS: the getAfter()/null-teardown
// rules cannot be exercised from Dart/`flutter test` — they require a real
// Firestore Security Rules evaluator, which only the emulator provides. This
// harness is intentionally isolated from the Flutter app: its own
// package.json/node_modules here in test/rules/, not wired into pubspec.yaml
// or `flutter test` in any way. It talks to a *locally running* Firestore
// emulator only (never production).
//
// HOW TO RUN:
//   1. In one terminal, from the repo root:
//        firebase emulators:start --only firestore
//   2. In another terminal:
//        cd test/rules && npm install && npm test
//
// Each test simulates the exact multi-write shape FirestoreService produces
// (single-transaction commits for per-record ops, or the four separate
// batch commits used by replaceAll/deleteCategory) so a passing suite here is
// real evidence the rules accept the client's actual write patterns — not
// just some idealized version of them.

import { strict as assert } from 'node:assert';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'dindin-rules-test';
const RULES_PATH = new URL('../../firestore.rules', import.meta.url);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// -- helpers ----------------------------------------------------------------

function aliceDb() {
  return testEnv.authenticatedContext('alice').firestore();
}
function bobDb() {
  return testEnv.authenticatedContext('bob').firestore();
}

/** Seeds documents bypassing rules, for test setup only. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

const accountDoc = (db, uid) => doc(db, `users/${uid}/meta/account`);
const balDoc = (db, uid, catId) => doc(db, `users/${uid}/balances/${catId}`);
const catDoc = (db, uid, id) => doc(db, `users/${uid}/categories/${id}`);
const incomeDoc = (db, uid, id) => doc(db, `users/${uid}/incomes/${id}`);
const allocDoc = (db, uid, id) => doc(db, `users/${uid}/allocations/${id}`);
const expenseDoc = (db, uid, id) => doc(db, `users/${uid}/expenses/${id}`);

// -----------------------------------------------------------------------
// 1. Per-write delta linkage (the core Option B invariant)
// -----------------------------------------------------------------------

describe('per-write balance delta (getAfter linkage)', () => {
  test('income create with an exact matching account delta succeeds', async () => {
    const db = aliceDb();
    const batch = writeBatch(db);
    batch.set(incomeDoc(db, 'alice', 'i1'), {
      date: '2026-01-01',
      amount: 100,
      source: 'freela',
    });
    batch.set(accountDoc(db, 'alice'), { balance: 100 }); // 0 (absent) + 100
    await assertSucceeds(batch.commit());
  });

  test('income create with a WRONG account delta is rejected', async () => {
    const db = aliceDb();
    const batch = writeBatch(db);
    batch.set(incomeDoc(db, 'alice', 'i1'), {
      date: '2026-01-01',
      amount: 100,
      source: 'freela',
    });
    batch.set(accountDoc(db, 'alice'), { balance: 50 }); // should be 100, not 50
    await assertFails(batch.commit());
  });

  test('expense against a caixinha cannot push its balance negative', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 30 });
    });

    // 50 > 30 available -> the balance doc would go negative -> rejected.
    const overspend = writeBatch(db);
    overspend.set(expenseDoc(db, 'alice', 'e1'), {
      date: '2026-01-02',
      amount: 50,
      categoryId: 'c1',
    });
    overspend.set(balDoc(db, 'alice', 'c1'), { balance: -20 });
    await assertFails(overspend.commit());

    // 20 <= 30 available -> succeeds, balance moves to exactly 10.
    const okSpend = writeBatch(db);
    okSpend.set(expenseDoc(db, 'alice', 'e2'), {
      date: '2026-01-02',
      amount: 20,
      categoryId: 'c1',
    });
    okSpend.set(balDoc(db, 'alice', 'c1'), { balance: 10 });
    await assertSucceeds(okSpend.commit());
  });

  test('deleting a ledger doc without moving its linked balance doc is rejected', async () => {
    // Regression for "can a client silently drift a balance by only touching
    // the ledger?" — no: the balance doc must move by the exact delta in the
    // SAME commit, or the write is rejected outright.
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 50 });
      await setDoc(allocDoc(sdb, 'alice', 'a1'), {
        categoryId: 'c1',
        amount: 50,
        date: '2026-01-01',
      });
    });

    await assertFails(deleteDoc(allocDoc(db, 'alice', 'a1')));
  });
});

// -----------------------------------------------------------------------
// 2. Cross-user isolation (the one guarantee that is unconditional)
// -----------------------------------------------------------------------

describe('cross-user isolation', () => {
  test("a user cannot read another user's balance doc", async () => {
    await seed(async (sdb) => setDoc(accountDoc(sdb, 'alice'), { balance: 500 }));
    await assertFails(getDoc(accountDoc(bobDb(), 'alice')));
  });

  test("a user cannot write another user's balance doc", async () => {
    await assertFails(setDoc(accountDoc(bobDb(), 'alice'), { balance: 999 }));
  });

  test("a user cannot write another user's ledger doc", async () => {
    await assertFails(
      setDoc(incomeDoc(bobDb(), 'alice', 'i1'), {
        date: '2026-01-01',
        amount: 10,
        source: 'freela',
      }),
    );
  });
});

// -----------------------------------------------------------------------
// 3. Documented residual limitation: standalone balance-doc writes
// -----------------------------------------------------------------------

describe('balance doc direct-write guard (documented residual limitation)', () => {
  test(
    'a standalone write to your OWN balance doc, with no linked ledger op, ' +
      'succeeds as long as it is shape-valid and non-negative — this is the ' +
      'documented "self-inflicted drift" trade-off in docs/BACKEND.md, not a ' +
      'bug: the balance doc\'s own rule only checks shape/non-negativity, ' +
      "the getAfter() delta check is attached to LEDGER writes, not to the " +
      'balance doc itself. Single-tenant data means this only lets a user ' +
      'corrupt their own displayed cache (which the UI recomputes from the ' +
      'ledger anyway); it can never touch another user.',
    async () => {
      await assertSucceeds(setDoc(accountDoc(aliceDb(), 'alice'), { balance: 9999 }));
    },
  );

  test('a balance doc write is still rejected if negative or wrong-shaped', async () => {
    await assertFails(setDoc(accountDoc(aliceDb(), 'alice'), { balance: -1 }));
    await assertFails(
      setDoc(accountDoc(aliceDb(), 'alice'), { balance: 10, extra: 'nope' }),
    );
  });
});

// -----------------------------------------------------------------------
// 4. Genesis/teardown: full JSON restore (mirrors FirestoreService.replaceAll)
// -----------------------------------------------------------------------

describe('restore flow (replaceAll genesis/teardown path)', () => {
  async function seedExistingUser(db) {
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Casa',
        recurring: true,
        createdAt: '2026-01-01',
      });
      await setDoc(incomeDoc(sdb, 'alice', 'i1'), {
        date: '2026-01-01',
        amount: 1000,
        source: 'freela',
      });
      await setDoc(allocDoc(sdb, 'alice', 'a1'), {
        categoryId: 'c1',
        amount: 600,
        date: '2026-01-02',
      });
      await setDoc(expenseDoc(sdb, 'alice', 'e1'), {
        date: '2026-01-03',
        amount: 100,
        categoryId: 'c1',
      });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 400 }); // 1000 - 600
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 500 }); // 600 - 100
    });
  }

  test('delete balances -> delete ledger -> write new ledger -> write new balances, all pass', async () => {
    const db = aliceDb();
    await seedExistingUser(db);

    // Step 1: delete the derived balance docs first (as replaceAll does).
    const step1 = writeBatch(db);
    step1.delete(accountDoc(db, 'alice'));
    step1.delete(balDoc(db, 'alice', 'c1'));
    await assertSucceeds(step1.commit());

    // Step 2: delete existing ledger docs — balance docs are now absent, so
    // the per-doc delta check is skipped (getAfter(...) == null).
    const step2 = writeBatch(db);
    step2.delete(catDoc(db, 'alice', 'c1'));
    step2.delete(incomeDoc(db, 'alice', 'i1'));
    step2.delete(allocDoc(db, 'alice', 'a1'));
    step2.delete(expenseDoc(db, 'alice', 'e1'));
    await assertSucceeds(step2.commit());

    // Step 3: write the restored ledger (different amounts than before —
    // proves this isn't secretly still delta-checked against old values).
    const step3 = writeBatch(db);
    step3.set(catDoc(db, 'alice', 'c2'), {
      name: 'Lazer',
      recurring: false,
      createdAt: '2026-02-01',
    });
    step3.set(incomeDoc(db, 'alice', 'i2'), {
      date: '2026-02-01',
      amount: 2000,
      source: 'estagio',
    });
    step3.set(allocDoc(db, 'alice', 'a2'), {
      categoryId: 'c2',
      amount: 300,
      date: '2026-02-02',
    });
    await assertSucceeds(step3.commit());

    // Step 4: recompute and write the balance docs last.
    const step4 = writeBatch(db);
    step4.set(accountDoc(db, 'alice'), { balance: 1700 }); // 2000 - 300
    step4.set(balDoc(db, 'alice', 'c2'), { balance: 300 });
    await assertSucceeds(step4.commit());

    // Sanity: the restored ledger reads back as written.
    const restoredIncome = await getDoc(incomeDoc(db, 'alice', 'i2'));
    assert.equal(restoredIncome.data().amount, 2000);
  });

  test('skipping the teardown step (balances left in place) makes the bulk ledger rewrite fail', async () => {
    const db = aliceDb();
    await seedExistingUser(db);

    // Attempt step "3" directly, without deleting the balance docs first —
    // this is exactly the ordering mistake docs/BACKEND.md warns about.
    const badRestore = writeBatch(db);
    badRestore.delete(catDoc(db, 'alice', 'c1'));
    badRestore.delete(incomeDoc(db, 'alice', 'i1'));
    badRestore.delete(allocDoc(db, 'alice', 'a1'));
    badRestore.delete(expenseDoc(db, 'alice', 'e1'));
    badRestore.set(catDoc(db, 'alice', 'c2'), {
      name: 'Lazer',
      recurring: false,
      createdAt: '2026-02-01',
    });
    badRestore.set(incomeDoc(db, 'alice', 'i2'), {
      date: '2026-02-01',
      amount: 2000,
      source: 'estagio',
    });
    await assertFails(badRestore.commit());
  });
});

// -----------------------------------------------------------------------
// 5. Genesis/teardown: category cascade delete (mirrors deleteCategory)
// -----------------------------------------------------------------------

describe('deleteCategory cascade', () => {
  test('deleting a caixinha + its balance doc + its allocations/expenses in one commit succeeds', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 100 });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 400 });
      await setDoc(allocDoc(sdb, 'alice', 'a1'), {
        categoryId: 'c1',
        amount: 100,
        date: '2026-01-02',
      });
    });

    // Mirrors FirestoreService.deleteCategory: one commit deletes the
    // category, its balance doc, and its allocations, and restores the
    // reversed allocation sum to the account balance — all atomically.
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(balDoc(db, 'alice', 'c1'));
    batch.delete(allocDoc(db, 'alice', 'a1'));
    batch.set(accountDoc(db, 'alice'), { balance: 500 }); // 400 + 100 reversed
    await assertSucceeds(batch.commit());
  });

  test('deleting a caixinha\'s allocation WITHOUT tearing down its balance doc is rejected', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 100 });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 400 });
      await setDoc(allocDoc(sdb, 'alice', 'a1'), {
        categoryId: 'c1',
        amount: 100,
        date: '2026-01-02',
      });
    });

    // Same cascade, but the balance doc is left untouched (a buggy client
    // that forgot to delete it) — must be rejected, not silently accepted.
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(allocDoc(db, 'alice', 'a1'));
    batch.set(accountDoc(db, 'alice'), { balance: 500 });
    await assertFails(batch.commit());
  });
});

// -----------------------------------------------------------------------
// 6. allowNegative ("dívida" toggle) — the getAfter()/catAllowsNeg() paths
//    that CANNOT be exercised outside the emulator. This is the actual
//    reason this feature needs rules-level coverage at all: catDeltaOk's
//    floor relaxation and catAllowsNeg's live category read.
// -----------------------------------------------------------------------

describe('allowNegative (caixinha debt)', () => {
  async function seedCategory(uid, id, { kind = 'spend', allowNegative, balance = 0 } = {}) {
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, uid, id), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind,
        ...(allowNegative === undefined ? {} : { allowNegative }),
      });
      await setDoc(balDoc(sdb, uid, id), { balance });
      await setDoc(accountDoc(sdb, uid), { balance: 1000 });
    });
  }

  // -- case 1: allowNegative ON + kind spend -> deepening a debt is allowed --
  test('spend caixinha with allowNegative ON: an expense that deepens an existing debt succeeds', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: true, balance: -20 });

    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 30, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -50 }); // -20 - 30
    await assertSucceeds(batch.commit());
  });

  test('spend caixinha with allowNegative ON: a standalone balance-doc write going (further) negative also succeeds', async () => {
    // Exercises catDeltaOk's OTHER caller: the balances/{categoryId} doc's
    // own rule (line ~143 of firestore.rules), not just the ledger-linked path.
    await seedCategory('alice', 'c1', { allowNegative: true, balance: -20 });
    await assertSucceeds(setDoc(balDoc(aliceDb(), 'alice', 'c1'), { balance: -999 }));
  });

  // -- case 2: toggle OFF + already negative -> further deepening blocked ----
  test('spend caixinha with allowNegative OFF and already negative: a further expense is rejected (ledger AND balance-doc layers)', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: false, balance: -20 });

    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 5, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -25 });
    await assertFails(batch.commit());

    // Same floor, direct balance-doc write with no ledger op at all.
    await assertFails(setDoc(balDoc(db, 'alice', 'c1'), { balance: -25 }));
  });

  test('legacy category with no allowNegative field at all behaves as OFF (defaults false)', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        // no `kind`, no `allowNegative` at all — pre-migration doc shape.
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: -10 });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 1000 });
    });
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 5, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -15 });
    await assertFails(batch.commit());
  });

  // -- case 3: toggle OFF, paying a debt down PARTIALLY (still negative) -----
  test('spend caixinha with allowNegative OFF: an allocation that partially pays down a debt succeeds even while still negative', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: false, balance: -50 });

    const batch = writeBatch(db);
    batch.set(allocDoc(db, 'alice', 'a1'), { categoryId: 'c1', amount: 20, date: '2026-01-06' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -30 }); // -50 + 20, delta >= 0
    batch.set(accountDoc(db, 'alice'), { balance: 980 }); // 1000 - 20
    await assertSucceeds(batch.commit());
  });

  // -- case 4: paying down to >= 0, then a normal expense works again --------
  test('after an allocation brings a frozen debt back to >= 0, a normal expense against it succeeds', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: false, balance: -30 });

    const payoff = writeBatch(db);
    payoff.set(allocDoc(db, 'alice', 'a1'), { categoryId: 'c1', amount: 40, date: '2026-01-06' });
    payoff.set(balDoc(db, 'alice', 'c1'), { balance: 10 }); // -30 + 40
    payoff.set(accountDoc(db, 'alice'), { balance: 960 });
    await assertSucceeds(payoff.commit());

    const spend = writeBatch(db);
    spend.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-07', amount: 5, categoryId: 'c1' });
    spend.set(balDoc(db, 'alice', 'c1'), { balance: 5 }); // 10 - 5, non-negative, no flag needed
    await assertSucceeds(spend.commit());
  });

  // -- case 5: a `save` caixinha never goes negative, even with the flag set -
  test("a 'save' caixinha with allowNegative:true stored on it still cannot go negative (product decision #2)", async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { kind: 'save', allowNegative: true, balance: 10 });

    // A withdrawal (expense against the caixinha) exceeding its balance.
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 20, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -10 });
    await assertFails(batch.commit());

    // And the standalone balance-doc write is blocked too — catAllowsNeg
    // requires kind == 'spend', which a 'save' doc never satisfies.
    await assertFails(setDoc(balDoc(db, 'alice', 'c1'), { balance: -10 }));
  });

  // -- case 6: transfer-out respects the flag ---------------------------------
  test('transfer-out from an allowNegative spend caixinha that deepens its debt succeeds', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: true, balance: -10 });
    await seedCategory('alice', 'c2', { allowNegative: false, balance: 0 });

    const batch = writeBatch(db);
    batch.set(allocDoc(db, 'alice', 'leg-from'), {
      categoryId: 'c1',
      amount: -15,
      date: '2026-01-08',
      transferId: 't1',
    });
    batch.set(allocDoc(db, 'alice', 'leg-to'), {
      categoryId: 'c2',
      amount: 15,
      date: '2026-01-08',
      transferId: 't1',
    });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -25 }); // -10 - 15
    batch.set(balDoc(db, 'alice', 'c2'), { balance: 15 });
    await assertSucceeds(batch.commit());
  });

  test('transfer-out from a NON-eligible caixinha (allowNegative OFF) that would push it negative is rejected', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: false, balance: 10 });
    await seedCategory('alice', 'c2', { allowNegative: false, balance: 0 });

    const batch = writeBatch(db);
    batch.set(allocDoc(db, 'alice', 'leg-from'), {
      categoryId: 'c1',
      amount: -15,
      date: '2026-01-08',
      transferId: 't1',
    });
    batch.set(allocDoc(db, 'alice', 'leg-to'), {
      categoryId: 'c2',
      amount: 15,
      date: '2026-01-08',
      transferId: 't1',
    });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -5 }); // 10 - 15
    batch.set(balDoc(db, 'alice', 'c2'), { balance: 15 });
    await assertFails(batch.commit());
  });

  // -- case 7: the account itself never gets the relaxation ------------------
  test('the general account balance can never go negative, regardless of any caixinha allowNegative flag', async () => {
    const db = aliceDb();
    // An allowNegative caixinha in play elsewhere must not affect account math.
    await seedCategory('alice', 'c1', { allowNegative: true, balance: 0 });
    await seed(async (sdb) => setDoc(accountDoc(sdb, 'alice'), { balance: 50 }));

    // A direct account-level expense (no categoryId) exceeding the account.
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 100 });
    batch.set(accountDoc(db, 'alice'), { balance: -50 });
    await assertFails(batch.commit());
  });

  test('a caixinha expense never touches the account balance, even when the caixinha itself allows negative', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: true, balance: -10 });
    await seed(async (sdb) => setDoc(accountDoc(sdb, 'alice'), { balance: 300 }));

    // accountDeltaOk(uid, 0) is required for a caixinha expense: the account
    // doc must stay EXACTLY as it is. Trying to also nudge it must fail even
    // though the caixinha-side write alone would be fine.
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 5, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -15 });
    batch.set(accountDoc(db, 'alice'), { balance: 301 }); // must be untouched (300)
    await assertFails(batch.commit());
  });

  // -- case 8: the anti-race delta linkage is unconditional, even with the flag on --
  test('allowNegative does NOT relax the delta linkage: a ledger op still must move the balance doc by EXACTLY its own amount', async () => {
    const db = aliceDb();
    await seedCategory('alice', 'c1', { allowNegative: true, balance: 50 }); // currently positive

    // A 30-unit expense claims a balance doc move to -1000 — the delta
    // (-1050) doesn't match the ledger op's own amount (-30). Must be
    // rejected regardless of catAllowsNeg being true; catAllowsNeg only
    // relaxes the >= 0 FLOOR, never the getAfter == before + delta equality.
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 30, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -1000 });
    await assertFails(batch.commit());
  });

  // -- case 9: genesis/teardown short-circuit is unaffected by the flag ------
  test('deleting an allowNegative caixinha (cascade) still tears down cleanly via the null-getAfter short-circuit', async () => {
    const db = aliceDb();
    // Regression fix (found while adding catDebtFree coverage below): this
    // scenario used to seed balance: -40 (an open debt) and still expect the
    // single-commit cascade delete to succeed. That is no longer correct —
    // the categories/{categoryId} delete rule now requires catDebtFree, so a
    // single-commit delete of an INDEBTED caixinha is (correctly) rejected;
    // see 'categories: catDebtFree guard' below for that DENY case. Balance
    // is 0 here (debt-free) so this test keeps testing what it actually says
    // it tests: that the allocation's null-getAfter teardown short-circuit
    // still works for an allowNegative category, independent of the debt
    // guard, which this fixture no longer triggers.
    await seedCategory('alice', 'c1', { allowNegative: true, balance: 0 });
    await seed(async (sdb) => {
      await setDoc(allocDoc(sdb, 'alice', 'a1'), { categoryId: 'c1', amount: 10, date: '2026-01-02' });
    });

    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(balDoc(db, 'alice', 'c1'));
    batch.delete(allocDoc(db, 'alice', 'a1'));
    // No account-balance adjustment needed: this allocation's reversal isn't
    // being summed here (mirrors the existing deleteCategory cascade tests);
    // account stays untouched.
    await assertSucceeds(batch.commit());
  });
});

// -----------------------------------------------------------------------
// 7. F1 fix: genesis re-materialization of a frozen caixinha debt
//    (catMayHoldNeg — the balances/{categoryId} rule's 4th branch, fired
//    ONLY when resource == null, i.e. the balance doc is being CREATED).
//    Regression coverage for the restore-with-frozen-debt bug fix.
// -----------------------------------------------------------------------

describe('genesis re-materialization of a frozen debt (catMayHoldNeg, F1 fix)', () => {
  test('genesis create of a SPEND caixinha balance doc at -50 with allowNegative OFF (frozen debt) succeeds', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: 'spend',
        allowNegative: false, // frozen: the toggle is off, but the debt must survive a restore
      });
      // No balances/c1 doc exists yet — this write CREATES it (resource == null).
    });

    await assertSucceeds(setDoc(balDoc(db, 'alice', 'c1'), { balance: -50 }));
  });

  test('genesis create of a caixinha balance doc at -50 whose CATEGORY was deleted (no category doc) is rejected', async () => {
    const db = aliceDb();
    // No category doc at all for 'c1' — catMayHoldNeg requires exists(catDoc).
    await assertFails(setDoc(balDoc(db, 'alice', 'c1'), { balance: -50 }));
  });

  test("genesis create of a 'save' caixinha balance doc at -50 is rejected (a save caixinha can never hold a debt)", async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Reserva',
        recurring: false,
        createdAt: '2026-01-01',
        kind: 'save',
      });
    });

    await assertFails(setDoc(balDoc(db, 'alice', 'c1'), { balance: -50 }));
  });

  test('genesis create of meta/account at a negative balance is rejected (the account is never eligible, regardless of catMayHoldNeg)', async () => {
    const db = aliceDb();
    // No meta/account doc exists yet for alice — this write CREATES it.
    await assertFails(setDoc(accountDoc(db, 'alice'), { balance: -50 }));
  });

  test('UPDATE (doc already exists) of a frozen spend caixinha deepening further negative via a ledger-linked expense is still rejected: the genesis branch does not leak into live writes', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: 'spend',
        allowNegative: false, // frozen
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: -50 }); // balance doc ALREADY EXISTS
    });

    // A gasto that would deepen the frozen debt from -50 to -60: resource !=
    // null here (the doc exists across the commit), so catMayHoldNeg's
    // "resource == null" guard must NOT fire — only catAllowsNeg (which
    // requires the toggle ON) governs an update, and the toggle is off here.
    const batch = writeBatch(db);
    batch.set(expenseDoc(db, 'alice', 'e1'), { date: '2026-01-05', amount: 10, categoryId: 'c1' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -60 });
    await assertFails(batch.commit());

    // Same for a standalone (no ledger op) balance-doc write on the existing doc.
    await assertFails(setDoc(balDoc(db, 'alice', 'c1'), { balance: -60 }));
  });

  test('paying down a frozen debt (delta >= 0, doc already exists) still succeeds — the F1 fix does not disturb the pre-existing floor relaxation', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: 'spend',
        allowNegative: false, // frozen
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: -50 });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 1000 });
    });

    const batch = writeBatch(db);
    batch.set(allocDoc(db, 'alice', 'a1'), { categoryId: 'c1', amount: 20, date: '2026-01-06' });
    batch.set(balDoc(db, 'alice', 'c1'), { balance: -30 }); // -50 + 20, delta >= 0
    batch.set(accountDoc(db, 'alice'), { balance: 980 });
    await assertSucceeds(batch.commit());
  });

  test('a legacy caixinha (no kind field at all) is still eligible for genesis re-materialization (kind defaults to spend)', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        // no `kind`, no `allowNegative` — pre-migration doc shape.
      });
    });

    await assertSucceeds(setDoc(balDoc(db, 'alice', 'c1'), { balance: -50 }));
  });

  test('full replaceAll-shaped restore of a frozen spend debt: teardown -> ledger rewrite -> genesis balance write at -50, all in the documented step order', async () => {
    const db = aliceDb();
    // Seed a pre-existing (different) state to be wiped, mirroring seedExistingUser.
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Casa',
        recurring: true,
        createdAt: '2026-01-01',
      });
      await setDoc(balDoc(sdb, 'alice', 'c1'), { balance: 500 });
      await setDoc(accountDoc(sdb, 'alice'), { balance: 400 });
    });

    // Step 1: delete the derived balance docs first.
    const step1 = writeBatch(db);
    step1.delete(accountDoc(db, 'alice'));
    step1.delete(balDoc(db, 'alice', 'c1'));
    await assertSucceeds(step1.commit());

    // Step 2: delete existing ledger docs.
    const step2 = writeBatch(db);
    step2.delete(catDoc(db, 'alice', 'c1'));
    await assertSucceeds(step2.commit());

    // Step 3: write the restored ledger — a spend caixinha with the debt
    // toggle now OFF (frozen), matching a backup taken after the user turned
    // allowNegative off while still in debt.
    const step3 = writeBatch(db);
    step3.set(catDoc(db, 'alice', 'c2'), {
      name: 'Lazer',
      recurring: false,
      createdAt: '2026-02-01',
      kind: 'spend',
      allowNegative: false,
    });
    await assertSucceeds(step3.commit());

    // Step 4: write the recomputed balance docs last — the caixinha's frozen
    // debt (-50) is re-materialized via catMayHoldNeg; the account (0) is fine.
    const step4 = writeBatch(db);
    step4.set(accountDoc(db, 'alice'), { balance: 0 });
    step4.set(balDoc(db, 'alice', 'c2'), { balance: -50 });
    await assertSucceeds(step4.commit());
  });
});

// -----------------------------------------------------------------------
// 8. categories: catDebtFree guard — refusing to strand an open debt via a
//    spend->save conversion or a delete (firestore.rules' `catDebtFree` +
//    `convertsSpendToSave`, wired into the categories/{categoryId} update
//    and delete rules). Mirrors FirestoreService.updateCategory's and
//    .deleteCategory's own StateError guards — see
//    test/services/firestore_service_test.dart for the client-side half of
//    this same invariant.
// -----------------------------------------------------------------------

describe('categories: catDebtFree guard (spend->save conversion & delete refused while indebted)', () => {
  async function seedCatWithBalance(uid, id, { kind = 'spend', allowNegative, balance } = {}) {
    await seed(async (sdb) => {
      const data = { name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind };
      if (allowNegative !== undefined) data.allowNegative = allowNegative;
      await setDoc(catDoc(sdb, uid, id), data);
      if (balance !== undefined) {
        await setDoc(balDoc(sdb, uid, id), { balance });
      }
    });
  }

  // -- spend -> save conversion (convertsSpendToSave + catDebtFree) --------

  test('DENY: converting a spend caixinha to save while it holds a real debt (-0.01)', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: -0.01 });
    await assertFails(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );
  });

  test('ALLOW: converting a spend caixinha to save with balance exactly 0', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: 0 });
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );
  });

  test('ALLOW: converting a spend caixinha to save with a positive balance', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: 50 });
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );
  });

  test('ALLOW: other edits to an indebted spend caixinha (rename, budget, the allowNegative toggle itself) that keep kind spend', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', allowNegative: true, balance: -20 });

    // Rename — not a conversion, so convertsSpendToSave short-circuits and
    // catDebtFree is never evaluated; the debt doesn't block this at all.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Novo nome', recurring: false, createdAt: '2026-01-01', kind: 'spend', allowNegative: true,
      }),
    );
    // Add/change a monthlyBudget.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Novo nome', recurring: false, createdAt: '2026-01-01', kind: 'spend',
        allowNegative: true, monthlyBudget: 100,
      }),
    );
    // Toggle allowNegative OFF — freezes the debt, still allowed while indebted.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Novo nome', recurring: false, createdAt: '2026-01-01', kind: 'spend',
        allowNegative: false, monthlyBudget: 100,
      }),
    );
    // Toggle it back ON.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Novo nome', recurring: false, createdAt: '2026-01-01', kind: 'spend',
        allowNegative: true, monthlyBudget: 100,
      }),
    );
  });

  test("ALLOW: save -> spend conversion, and any edit of a 'save' caixinha, regardless of its balance", async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'save', balance: 30 });

    // Rename while staying 'save'.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Outro nome', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );
    // save -> spend: convertsSpendToSave requires before.kind == 'spend', so
    // this direction never even evaluates catDebtFree.
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Outro nome', recurring: false, createdAt: '2026-01-01', kind: 'spend', allowNegative: false,
      }),
    );
  });

  // -- delete (catDebtFree alone) ------------------------------------------

  test('DENY: deleting a category with a real debt (-0.01) on its balance doc', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', allowNegative: true, balance: -0.01 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(balDoc(db, 'alice', 'c1'));
    await assertFails(batch.commit());
  });

  test('ALLOW: deleting a category with balance exactly 0', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: 0 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(balDoc(db, 'alice', 'c1'));
    await assertSucceeds(batch.commit());
  });

  test('ALLOW: deleting a category with a positive balance', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: 50 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c1'));
    batch.delete(balDoc(db, 'alice', 'c1'));
    await assertSucceeds(batch.commit());
  });

  test('ALLOW: deleting a category whose balance doc was never created (a missing doc reads as debt-free)', async () => {
    const db = aliceDb();
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'spend',
      });
    });
    await assertSucceeds(deleteDoc(catDoc(db, 'alice', 'c1')));
  });

  test(
    'regression: a restore-shaped teardown (balance doc deleted in an EARLIER batch) still lets the ' +
      'category delete pass even though the pre-restore balance was negative',
    async () => {
      const db = aliceDb();
      await seedCatWithBalance('alice', 'c1', { kind: 'spend', allowNegative: false, balance: -40 });

      // Step 1 (as replaceAll does): tear down the balance doc first, in its
      // own already-committed batch.
      await assertSucceeds(deleteDoc(balDoc(db, 'alice', 'c1')));

      // Step 2: delete the category doc in a LATER, separate batch.
      // catDebtFree reads the balance doc's CURRENT (pre-THIS-commit) state,
      // which is already absent -> reads as 0 -> debt-free -> allowed, even
      // though the caixinha held a real -40 debt moments ago.
      await assertSucceeds(deleteDoc(catDoc(db, 'alice', 'c1')));
    },
  );

  test('float-dust boundary: a balance of -0.0000000005 (inside the 1e-9 tolerance) does not block conversion or delete', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: -0.0000000005 });
    await assertSucceeds(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );

    await seedCatWithBalance('alice', 'c2', { kind: 'spend', balance: -0.0000000005 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c2'));
    batch.delete(balDoc(db, 'alice', 'c2'));
    await assertSucceeds(batch.commit());
  });

  test('float-dust boundary: a balance of -0.01 (a real debt, not float dust) still blocks both conversion and delete', async () => {
    const db = aliceDb();
    await seedCatWithBalance('alice', 'c1', { kind: 'spend', balance: -0.01 });
    await assertFails(
      setDoc(catDoc(db, 'alice', 'c1'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'save',
      }),
    );

    await seedCatWithBalance('alice', 'c2', { kind: 'spend', balance: -0.01 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c2'));
    batch.delete(balDoc(db, 'alice', 'c2'));
    await assertFails(batch.commit());
  });

  test('genesis re-materialization of a frozen debt (catMayHoldNeg) still works with the catDebtFree guard active on a DIFFERENT category', async () => {
    const db = aliceDb();
    // A frozen-debt caixinha being re-created via genesis (as in a restore)...
    await seed(async (sdb) => {
      await setDoc(catDoc(sdb, 'alice', 'c-frozen'), {
        name: 'Lazer', recurring: false, createdAt: '2026-01-01', kind: 'spend', allowNegative: false,
      });
    });
    await assertSucceeds(setDoc(balDoc(db, 'alice', 'c-frozen'), { balance: -50 }));

    // ...coexists in the same run with an ordinary debt-free category
    // delete, proving the new catDebtFree guard on categories/{categoryId}
    // doesn't interfere with the separate balances/{categoryId} genesis path.
    await seedCatWithBalance('alice', 'c-clean', { kind: 'spend', balance: 0 });
    const batch = writeBatch(db);
    batch.delete(catDoc(db, 'alice', 'c-clean'));
    batch.delete(balDoc(db, 'alice', 'c-clean'));
    await assertSucceeds(batch.commit());
  });
});

