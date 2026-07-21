// Persisted regression coverage for scripts/backfill_balances.mjs's balance
// classification (see that file's header for the LEGITIMATE DEBT vs. BALANCE
// CORRUPTION split). This makes permanent a validation that was previously
// done MANUALLY against the emulator: seed known-good and known-bad ledger
// shapes with firebase-admin (which, like the real backfill script, bypasses
// Security Rules — this is intentionally exercising the same privileged path
// `scripts/deploy.sh` uses), run the real script as a subprocess, and assert
// on its actual stdout+stderr — not a reimplementation of its logic.
//
// ISOLATION: uses its OWN Firestore project id (dindin-backfill-test),
// deliberately different from rules.test.mjs's `dindin-rules-test`. Both
// files share the same running emulator instance under `emulators:exec`, and
// a Firestore emulator keeps each project id's data fully separate — so this
// file's admin-seeded fixtures can never be wiped out by rules.test.mjs's
// `testEnv.clearFirestore()` (which only clears its own project), regardless
// of whether node's test runner executes the two files concurrently.
//
// HOW TO RUN: same as rules.test.mjs — `firebase emulators:exec --only
// firestore --project dindin-rules-test "npm test --prefix test/rules"` from
// the repo root (this file's own project id is independent of that flag;
// --project only picks the emulator's default UI project, not which project
// ids it will accept writes for — verified empirically before writing this
// harness).
//
// KNOWN GAP THIS TEST DELIBERATELY DOES NOT COVER (reported separately, not
// fixed here per QA scope — see the handoff notes): `scripts/deploy.sh`'s
// actual dry-run gate is `node backfill_balances.mjs --dry-run | tee
// "$DRY_RUN_LOG"` with NO `2>&1`. The script prints every classification line
// (including every "BALANCE CORRUPTION" marker) via `console.error`/
// `console.warn`, i.e. to STDERR — a bare `cmd | tee file` pipe only carries
// STDOUT into the pipe, so none of that ever reaches $DRY_RUN_LOG in the real
// deploy script, and `grep -q "BALANCE CORRUPTION" "$DRY_RUN_LOG"` can never
// match. The gate currently ALWAYS "passes" regardless of real corruption.
// This file captures stdout AND stderr together (the CORRECT way to read the
// script's output, and what deploy.sh should do) to test the classification
// contract on its own merits; it intentionally does not encode the buggy
// stdout-only pipe as expected behavior.

import { strict as assert } from 'node:assert';
import { spawnSync } from 'node:child_process';
import { after, before, beforeEach, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { initializeApp, applicationDefault, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'dindin-backfill-test';
const SCRIPT_PATH = fileURLToPath(
  new URL('../../scripts/backfill_balances.mjs', import.meta.url),
);

let app;
let db;

before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run this via `firebase emulators:exec` ' +
        '(see the repo-root README/this file\'s header) or export it yourself ' +
        'after starting `firebase emulators:start --only firestore`. This suite ' +
        'seeds fixtures with firebase-admin and runs the real backfill script ' +
        'against a LIVE Firestore emulator only — never production.',
    );
  }
  app = initializeApp(
    { credential: applicationDefault(), projectId: PROJECT_ID },
    'dindin-backfill-test-app',
  );
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

/** Wipes every document under this project via the emulator's clear-all-data
 * endpoint (the same mechanism `@firebase/rules-unit-testing`'s
 * `clearFirestore()` uses), scoped to OUR OWN project id only. */
async function clearAll() {
  const res = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!res.ok) {
    throw new Error(`Failed to clear the ${PROJECT_ID} emulator data: ${res.status}`);
  }
}

beforeEach(async () => {
  await clearAll();
});

// -- seeding helpers (admin writes bypass rules, matching the real script's
// privileged access and what a raw pre-backfill ledger looks like) ---------

async function seedCategory(uid, id, { kind = 'spend', allowNegative } = {}) {
  const data = { name: 'Caixinha', recurring: false, createdAt: '2026-01-01', kind };
  if (allowNegative !== undefined) data.allowNegative = allowNegative;
  await db.doc(`users/${uid}/categories/${id}`).set(data);
}
async function seedIncome(uid, id, amount) {
  await db
    .doc(`users/${uid}/incomes/${id}`)
    .set({ date: '2026-01-01', amount, source: 'freela' });
}
async function seedAllocation(uid, id, categoryId, amount) {
  await db
    .doc(`users/${uid}/allocations/${id}`)
    .set({ categoryId, amount, date: '2026-01-02' });
}
async function seedExpense(uid, id, amount, categoryId) {
  const data = { date: '2026-01-03', amount };
  if (categoryId !== undefined) data.categoryId = categoryId;
  await db.doc(`users/${uid}/expenses/${id}`).set(data);
}

/** Runs the real backfill script as a subprocess against the emulator, in
 * --dry-run mode (never writes), and returns its stdout+stderr combined —
 * the classification markers (`console.warn`/`console.error`) live on
 * stderr, so a test must look at both to see them (see file header). */
function runDryRun() {
  const result = spawnSync('node', [SCRIPT_PATH, '--dry-run'], {
    encoding: 'utf8',
    env: {
      ...process.env,
      GCLOUD_PROJECT: PROJECT_ID,
      GOOGLE_CLOUD_PROJECT: PROJECT_ID,
    },
  });
  assert.equal(
    result.status,
    0,
    `backfill_balances.mjs --dry-run exited ${result.status} (expected 0):\n` +
      `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );
  return { stdout: result.stdout, stderr: result.stderr, combined: result.stdout + result.stderr };
}

describe('backfill_balances.mjs --dry-run: legitimate debt vs. balance corruption', () => {
  test('a spend caixinha summing negative with allowNegative ON is classified as an open debt (not corruption)', async () => {
    await seedCategory('u-open-debt', 'c1', { kind: 'spend', allowNegative: true });
    // Income funds the allocation so the GENERAL ACCOUNT stays at 0 — this
    // scenario must isolate the caixinha-level debt classification only,
    // without an unrelated negative account also showing up as corruption.
    await seedIncome('u-open-debt', 'i1', 20);
    await seedAllocation('u-open-debt', 'a1', 'c1', 20);
    await seedExpense('u-open-debt', 'e1', 50, 'c1'); // 20 - 50 = -30

    const { combined } = runDryRun();
    assert.match(combined, /open debt \(open, allowNegative on\) caixinha c1=-30\.00/);
    assert.doesNotMatch(combined, /BALANCE CORRUPTION/);
  });

  test('a spend caixinha summing negative with allowNegative OFF (a frozen debt) is still classified as an open debt (not corruption)', async () => {
    await seedCategory('u-frozen-debt', 'c1', { kind: 'spend', allowNegative: false });
    await seedIncome('u-frozen-debt', 'i1', 20); // funds the allocation; keeps the account at 0
    await seedAllocation('u-frozen-debt', 'a1', 'c1', 20);
    await seedExpense('u-frozen-debt', 'e1', 50, 'c1'); // -30, frozen

    const { combined } = runDryRun();
    assert.match(combined, /open debt \(FROZEN, allowNegative off\) caixinha c1=-30\.00/);
    assert.doesNotMatch(combined, /BALANCE CORRUPTION/);
  });

  test('a legacy caixinha (no kind field at all) summing negative is treated as spend and classified as an open debt', async () => {
    // No `kind`/`allowNegative` at all — pre-migration doc shape, mirrors the
    // same legacy-defaulting the rules and the Dart client apply.
    await db
      .doc('users/u-legacy-debt/categories/c1')
      .set({ name: 'Caixinha', recurring: false, createdAt: '2026-01-01' });
    await seedIncome('u-legacy-debt', 'i1', 10); // funds the allocation; keeps the account at 0
    await seedAllocation('u-legacy-debt', 'a1', 'c1', 10);
    await seedExpense('u-legacy-debt', 'e1', 40, 'c1'); // -30

    const { combined } = runDryRun();
    assert.match(combined, /open debt \(FROZEN, allowNegative off\) caixinha c1=-30\.00/);
    assert.doesNotMatch(combined, /BALANCE CORRUPTION/);
  });

  test('a negative general account balance is flagged as BALANCE CORRUPTION', async () => {
    await seedIncome('u-bad-account', 'i1', 50);
    await seedExpense('u-bad-account', 'e1', 100); // no categoryId -> account expense; 50 - 100 = -50

    const { combined } = runDryRun();
    assert.match(
      combined,
      /BALANCE CORRUPTION: account=-50\.00 \(the general account may never go negative\)/,
    );
  });

  test('a negative \'save\' caixinha balance is flagged as BALANCE CORRUPTION', async () => {
    await seedCategory('u-bad-save', 'c1', { kind: 'save' });
    await seedIncome('u-bad-save', 'i1', 20); // funds the allocation; the account itself stays clean
    await seedAllocation('u-bad-save', 'a1', 'c1', 20);
    await seedExpense('u-bad-save', 'e1', 50, 'c1'); // 20 - 50 = -30, but 'save' can never hold a debt

    const { combined } = runDryRun();
    assert.match(
      combined,
      /BALANCE CORRUPTION: save caixinha c1=-30\.00 \(only spend caixinhas may hold a debt\)/,
    );
    // The account itself is uncorrupted here — only the save caixinha is.
    assert.doesNotMatch(combined, /BALANCE CORRUPTION: account/);
  });

  test('an orphan ledger id (no category doc) summing negative is flagged as BALANCE CORRUPTION', async () => {
    // No categories/ghost doc at all — as if a cascade delete left ledger
    // docs behind (defect scenario referenced in the script's own header).
    await seedIncome('u-orphan', 'i1', 20); // funds the allocation; the account itself stays clean
    await seedAllocation('u-orphan', 'a1', 'ghost', 20);
    await seedExpense('u-orphan', 'e1', 60, 'ghost'); // 20 - 60 = -40

    const { combined } = runDryRun();
    assert.match(
      combined,
      /BALANCE CORRUPTION: orphan caixinha ghost=-40\.00 \(category was deleted but ledger remains\)/,
    );
    assert.doesNotMatch(combined, /BALANCE CORRUPTION: account/);
  });

  test('deploy.sh gate contract: a run with ONLY legitimate debts does not match "BALANCE CORRUPTION" (the gate would pass)', async () => {
    await seedCategory('u-open-debt', 'c1', { kind: 'spend', allowNegative: true });
    await seedIncome('u-open-debt', 'i1', 20);
    await seedAllocation('u-open-debt', 'a1', 'c1', 20);
    await seedExpense('u-open-debt', 'e1', 50, 'c1');
    await seedCategory('u-frozen-debt', 'c1', { kind: 'spend', allowNegative: false });
    await seedIncome('u-frozen-debt', 'i1', 20);
    await seedAllocation('u-frozen-debt', 'a1', 'c1', 20);
    await seedExpense('u-frozen-debt', 'e1', 50, 'c1');

    const { combined } = runDryRun();
    assert.doesNotMatch(
      combined,
      /BALANCE CORRUPTION/,
      'grep -q "BALANCE CORRUPTION" must NOT match a legit-debt-only run, or deploy.sh would ' +
        'block every deploy behind an open/frozen caixinha debt — the exact defect this ' +
        'debt/corruption split was introduced to fix.',
    );
  });

  test('deploy.sh gate contract: a run containing any corruption matches "BALANCE CORRUPTION" (the gate would abort)', async () => {
    // A legitimate debt alongside real corruption: the corruption must still
    // surface and must not be masked by the legitimate-debt path being fine.
    await seedCategory('u-open-debt', 'c1', { kind: 'spend', allowNegative: true });
    await seedIncome('u-open-debt', 'i1', 20);
    await seedAllocation('u-open-debt', 'a1', 'c1', 20);
    await seedExpense('u-open-debt', 'e1', 50, 'c1');
    await seedCategory('u-bad-save', 'c1', { kind: 'save' });
    await seedIncome('u-bad-save', 'i1', 20);
    await seedAllocation('u-bad-save', 'a1', 'c1', 20);
    await seedExpense('u-bad-save', 'e1', 50, 'c1');

    const { combined } = runDryRun();
    assert.match(
      combined,
      /BALANCE CORRUPTION/,
      'grep -q "BALANCE CORRUPTION" must match whenever real corruption is present, even ' +
        'alongside an unrelated legitimate debt on another user.',
    );
    // And the legitimate debt on the OTHER user must still be reported as a
    // debt, not swept up as corruption merely because SOME user in the run
    // has real corruption.
    assert.match(combined, /open debt \(open, allowNegative on\) caixinha c1=-30\.00/);
  });

  test('--dry-run never writes: no balance docs exist after any of the above scenarios', async () => {
    await seedCategory('u-open-debt', 'c1', { kind: 'spend', allowNegative: true });
    await seedIncome('u-open-debt', 'i1', 20);
    await seedAllocation('u-open-debt', 'a1', 'c1', 20);
    await seedExpense('u-open-debt', 'e1', 50, 'c1');

    runDryRun();

    const balSnap = await db.doc('users/u-open-debt/balances/c1').get();
    assert.equal(balSnap.exists, false);
    const acctSnap = await db.doc('users/u-open-debt/meta/account').get();
    assert.equal(acctSnap.exists, false);
  });
});
