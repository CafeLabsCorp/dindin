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
