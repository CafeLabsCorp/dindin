/**
 * Dindin — server-side money-integrity writes (callable Cloud Functions).
 *
 * WHY THIS EXISTS
 * ---------------
 * The "can't overspend a caixinha", "an allocation can't exceed the account
 * balance", and "nothing can go negative" invariants depend on SUMMING whole
 * collections. Firestore Security Rules cannot aggregate a collection, so they
 * cannot enforce these on their own. These callable functions run with admin
 * privileges and perform the checks inside a Firestore TRANSACTION, which is
 * the robust place to guarantee them. When deployed, Phase-2 rules deny direct
 * client writes to these collections so this is the only write path.
 *
 * COST FLAG: Cloud Functions require the Firebase Blaze (pay-as-you-go) plan.
 * The Spark free tier will NOT run these. See docs/BACKEND.md for the
 * free-vs-paid trade-off and the rules-only alternative. NOTHING here deploys
 * automatically — writing this file incurs no cost.
 *
 * CLIENT CONTRACT
 * ---------------
 * Each callable takes { ...payload } and returns { id } (or { transferId }).
 * The payload field names match FirestoreService's method arguments exactly,
 * so the Flutter client can switch a method from a direct write to
 * `FirebaseFunctions.instance.httpsCallable('<name>').call(payload)` without
 * changing its public API or the UI. Error `code` is 'failed-precondition' for
 * a violated invariant, 'not-found' for a missing referenced doc,
 * 'invalid-argument' for a bad payload, 'unauthenticated' if not signed in.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();

const EPS = 1e-9;

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");
  return uid;
}

function num(v, field) {
  if (typeof v !== "number" || Number.isNaN(v)) {
    throw new HttpsError("invalid-argument", `${field} must be a number.`);
  }
  return v;
}

function str(v, field) {
  if (typeof v !== "string" || v.length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return v;
}

const userCol = (uid, name) => db.collection(`users/${uid}/${name}`);

function sum(docs, pick) {
  return docs.reduce((t, d) => t + pick(d), 0);
}

/** Account balance = income - allocated - account-only expenses, with optional
 * single-doc exclusions (used on edits). Reads happen inside `tx`. */
async function accountBalance(tx, uid, { excludeAllocationId, excludeExpenseId } = {}) {
  const [incomes, allocations, expenses] = await Promise.all([
    tx.get(userCol(uid, "incomes")),
    tx.get(userCol(uid, "allocations")),
    tx.get(userCol(uid, "expenses")),
  ]);
  const totalIncome = sum(incomes.docs, (d) => d.get("amount"));
  const totalAllocated = sum(
    allocations.docs.filter((d) => d.id !== excludeAllocationId),
    (d) => d.get("amount"),
  );
  const accountExpenses = sum(
    expenses.docs.filter((d) => d.get("categoryId") == null && d.id !== excludeExpenseId),
    (d) => d.get("amount"),
  );
  return totalIncome - totalAllocated - accountExpenses;
}

/** One caixinha's balance = allocated (incl. transfer legs) - spent. */
async function caixinhaBalance(tx, uid, categoryId, { excludeExpenseId } = {}) {
  const [allocations, expenses] = await Promise.all([
    tx.get(userCol(uid, "allocations").where("categoryId", "==", categoryId)),
    tx.get(userCol(uid, "expenses").where("categoryId", "==", categoryId)),
  ]);
  const allocated = sum(allocations.docs, (d) => d.get("amount"));
  const spent = sum(
    expenses.docs.filter((d) => d.id !== excludeExpenseId),
    (d) => d.get("amount"),
  );
  return allocated - spent;
}

async function requireCategory(tx, uid, categoryId, label = "category") {
  const snap = await tx.get(userCol(uid, "categories").doc(categoryId));
  if (!snap.exists) throw new HttpsError("not-found", `${label} not found.`);
  return snap;
}

// --------------------------------------------------------------------------
// Categories (no cross-collection integrity; shape + ownership only).
// --------------------------------------------------------------------------
export const createCategory = onCall(async (request) => {
  const uid = requireUid(request);
  const { name, recurring, monthlyBudget } = request.data ?? {};
  str(name, "name");
  if (typeof recurring !== "boolean") {
    throw new HttpsError("invalid-argument", "recurring must be a bool.");
  }
  if (monthlyBudget != null) num(monthlyBudget, "monthlyBudget");
  const ref = userCol(uid, "categories").doc();
  const data = { name, recurring, createdAt: new Date().toISOString() };
  if (monthlyBudget != null) data.monthlyBudget = monthlyBudget;
  await ref.set(data);
  return { id: ref.id };
});

export const updateCategory = onCall(async (request) => {
  const uid = requireUid(request);
  const { id, name, recurring, monthlyBudget, clearMonthlyBudget } = request.data ?? {};
  str(id, "id");
  const ref = userCol(uid, "categories").doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "category not found.");
  const data = { ...snap.data() };
  if (name != null) data.name = str(name, "name");
  if (recurring != null) data.recurring = recurring;
  if (clearMonthlyBudget) delete data.monthlyBudget;
  else if (monthlyBudget != null) data.monthlyBudget = num(monthlyBudget, "monthlyBudget");
  await ref.set(data);
  return { id };
});

export const deleteCategory = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  const [allocs, expenses] = await Promise.all([
    userCol(uid, "allocations").where("categoryId", "==", id).get(),
    userCol(uid, "expenses").where("categoryId", "==", id).get(),
  ]);
  const batch = db.batch();
  batch.delete(userCol(uid, "categories").doc(id));
  allocs.docs.forEach((d) => batch.delete(d.ref));
  expenses.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return { id };
});

// --------------------------------------------------------------------------
// Incomes.  Create/update just add to the account (only non-negativity).
// Delete must not push the account negative.
// --------------------------------------------------------------------------
function validateIncomePayload(d) {
  str(d.date, "date");
  const amount = num(d.amount, "amount");
  if (amount < 0) throw new HttpsError("failed-precondition", "amount cannot be negative.");
  str(d.source, "source");
  const out = { date: d.date, amount, source: d.source };
  if (d.description != null) out.description = str(d.description, "description");
  return out;
}

export const createIncome = onCall(async (request) => {
  const uid = requireUid(request);
  const data = validateIncomePayload(request.data ?? {});
  const ref = userCol(uid, "incomes").doc();
  await ref.set(data);
  return { id: ref.id };
});

export const updateIncome = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  const data = validateIncomePayload(request.data);
  const id2 = await db.runTransaction(async (tx) => {
    const ref = userCol(uid, "incomes").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "income not found.");
    // Lowering an income could push the account negative; verify against the
    // account balance that WOULD result after applying the new amount.
    const currentAmount = snap.get("amount");
    const currentBalance = await accountBalance(tx, uid); // includes current income
    const newBalance = currentBalance - currentAmount + data.amount;
    if (newBalance < -EPS) {
      throw new HttpsError("failed-precondition", "lowering income would overdraw the account.");
    }
    tx.set(ref, data);
    return id;
  });
  return { id: id2 };
});

export const deleteIncome = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  await db.runTransaction(async (tx) => {
    const ref = userCol(uid, "incomes").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const amount = snap.get("amount");
    const bal = await accountBalance(tx, uid);
    if (amount > bal + EPS) {
      throw new HttpsError("failed-precondition", "deleting this income would overdraw the account.");
    }
    tx.delete(ref);
  });
  return { id };
});

// --------------------------------------------------------------------------
// Allocations (account -> caixinha).
// --------------------------------------------------------------------------
export const createAllocation = onCall(async (request) => {
  const uid = requireUid(request);
  const { categoryId, amount, date } = request.data ?? {};
  str(categoryId, "categoryId");
  str(date, "date");
  const amt = num(amount, "amount");
  if (amt < 0) throw new HttpsError("failed-precondition", "amount cannot be negative.");
  const id = await db.runTransaction(async (tx) => {
    await requireCategory(tx, uid, categoryId);
    const available = await accountBalance(tx, uid);
    if (amt > available + EPS) {
      throw new HttpsError("failed-precondition", "amount exceeds account balance.");
    }
    const ref = userCol(uid, "allocations").doc();
    tx.set(ref, { categoryId, amount: amt, date });
    return ref.id;
  });
  return { id };
});

export const updateAllocation = onCall(async (request) => {
  const uid = requireUid(request);
  const { id, categoryId, amount, date } = request.data ?? {};
  str(id, "id");
  str(categoryId, "categoryId");
  str(date, "date");
  const amt = num(amount, "amount");
  if (amt < 0) throw new HttpsError("failed-precondition", "amount cannot be negative.");
  await db.runTransaction(async (tx) => {
    const ref = userCol(uid, "allocations").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "allocation not found.");
    if (snap.get("transferId") != null) {
      throw new HttpsError("failed-precondition", "cannot edit a transfer leg directly.");
    }
    await requireCategory(tx, uid, categoryId);
    const available = await accountBalance(tx, uid, { excludeAllocationId: id });
    if (amt > available + EPS) {
      throw new HttpsError("failed-precondition", "amount exceeds account balance.");
    }
    tx.set(ref, { categoryId, amount: amt, date });
  });
  return { id };
});

export const deleteAllocation = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  await db.runTransaction(async (tx) => {
    const ref = userCol(uid, "allocations").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const transferId = snap.get("transferId");
    // Removing an allocation reduces its caixinha; if money was already spent
    // there, the caixinha would go negative — reject.
    const legs =
      transferId != null
        ? (await tx.get(userCol(uid, "allocations").where("transferId", "==", transferId))).docs
        : [snap];
    for (const leg of legs) {
      const catId = leg.get("categoryId");
      const bal = await caixinhaBalance(tx, uid, catId);
      if (leg.get("amount") > bal + EPS) {
        throw new HttpsError("failed-precondition", "removing this allocation would overdraw the caixinha.");
      }
    }
    legs.forEach((leg) => tx.delete(leg.ref));
  });
  return { id };
});

// --------------------------------------------------------------------------
// Transfers (caixinha -> caixinha), stored as a pair of allocation legs.
// --------------------------------------------------------------------------
export const createTransfer = onCall(async (request) => {
  const uid = requireUid(request);
  const { fromCategoryId, toCategoryId, amount, date } = request.data ?? {};
  str(fromCategoryId, "fromCategoryId");
  str(toCategoryId, "toCategoryId");
  str(date, "date");
  const amt = num(amount, "amount");
  if (amt <= 0) throw new HttpsError("failed-precondition", "amount must be positive.");
  if (fromCategoryId === toCategoryId) {
    throw new HttpsError("invalid-argument", "source and destination must differ.");
  }
  const transferId = await db.runTransaction(async (tx) => {
    await requireCategory(tx, uid, fromCategoryId, "source category");
    await requireCategory(tx, uid, toCategoryId, "destination category");
    const sourceBalance = await caixinhaBalance(tx, uid, fromCategoryId);
    if (amt > sourceBalance + EPS) {
      throw new HttpsError("failed-precondition", "amount exceeds source caixinha balance.");
    }
    const tid = userCol(uid, "allocations").doc().id;
    const fromLeg = userCol(uid, "allocations").doc();
    const toLeg = userCol(uid, "allocations").doc();
    tx.set(fromLeg, { categoryId: fromCategoryId, amount: -amt, date, transferId: tid });
    tx.set(toLeg, { categoryId: toCategoryId, amount: amt, date, transferId: tid });
    return tid;
  });
  return { transferId };
});

export const deleteTransfer = onCall(async (request) => {
  const uid = requireUid(request);
  const { transferId } = request.data ?? {};
  str(transferId, "transferId");
  await db.runTransaction(async (tx) => {
    const legs = await tx.get(userCol(uid, "allocations").where("transferId", "==", transferId));
    // Undoing a transfer restores the source and reduces the destination; the
    // destination must not have been spent below the transferred amount.
    for (const leg of legs.docs) {
      if (leg.get("amount") > 0) {
        const bal = await caixinhaBalance(tx, uid, leg.get("categoryId"));
        if (leg.get("amount") > bal + EPS) {
          throw new HttpsError("failed-precondition", "undoing this transfer would overdraw the destination caixinha.");
        }
      }
    }
    legs.docs.forEach((d) => tx.delete(d.ref));
  });
  return { transferId };
});

// --------------------------------------------------------------------------
// Expenses (from a caixinha or straight from the account).
// --------------------------------------------------------------------------
function validateExpensePayload(d) {
  str(d.date, "date");
  const amount = num(d.amount, "amount");
  if (amount < 0) throw new HttpsError("failed-precondition", "amount cannot be negative.");
  const out = { date: d.date, amount };
  if (d.categoryId != null) out.categoryId = str(d.categoryId, "categoryId");
  if (d.description != null) out.description = str(d.description, "description");
  return out;
}

export const createExpense = onCall(async (request) => {
  const uid = requireUid(request);
  const data = validateExpensePayload(request.data ?? {});
  const id = await db.runTransaction(async (tx) => {
    const available =
      data.categoryId == null
        ? await accountBalance(tx, uid)
        : (await requireCategory(tx, uid, data.categoryId),
          await caixinhaBalance(tx, uid, data.categoryId));
    if (data.amount > available + EPS) {
      throw new HttpsError("failed-precondition", "amount exceeds available balance.");
    }
    const ref = userCol(uid, "expenses").doc();
    tx.set(ref, data);
    return ref.id;
  });
  return { id };
});

export const updateExpense = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  const data = validateExpensePayload(request.data);
  await db.runTransaction(async (tx) => {
    const ref = userCol(uid, "expenses").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "expense not found.");
    const available =
      data.categoryId == null
        ? await accountBalance(tx, uid, { excludeExpenseId: id })
        : (await requireCategory(tx, uid, data.categoryId),
          await caixinhaBalance(tx, uid, data.categoryId, { excludeExpenseId: id }));
    if (data.amount > available + EPS) {
      throw new HttpsError("failed-precondition", "amount exceeds available balance.");
    }
    tx.set(ref, data);
  });
  return { id };
});

export const deleteExpense = onCall(async (request) => {
  const uid = requireUid(request);
  const { id } = request.data ?? {};
  str(id, "id");
  // Deleting an expense only INCREASES balances — always safe.
  await userCol(uid, "expenses").doc(id).delete();
  return { id };
});
