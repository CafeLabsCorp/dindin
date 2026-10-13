/**
 * Dindin — READ-ONLY diagnosis: does one user's stored account balance
 * (`users/{uid}/meta/account`) match what the ledger adds up to?
 *
 * WHY: the app's "Disponível" is re-summed from the ledger, but the Firestore
 * rules validate a write against the STORED balance doc. If the two ever
 * diverge, a save can be refused ("Não foi possível salvar") even though the
 * screen shows enough money.
 *
 * Only reads. Never writes. Prints amounts, dates and ids only — no
 * descriptions or names.
 *
 *   cd scripts
 *   node diagnose_account_balance.mjs someone@example.com   # ou o uid direto
 *
 * Needs `gcloud auth application-default login` (same as backfill_balances.mjs).
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

const email = process.argv[2];
if (!email) {
  console.error("uso: node diagnose_account_balance.mjs <email-ou-uid>");
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: "dindin-cafelabs" });
// Aceita o e-mail OU o uid direto (copiado de Firebase Console -> Authentication).
// Com o uid não precisa da API de Auth, que exige "quota project" no ADC.
let uid = email;
if (email.includes("@")) {
  const user = await getAuth().getUserByEmail(email);
  uid = user.uid;
  console.log(`criado: ${user.metadata.creationTime} | último login: ${user.metadata.lastSignInTime}`);
}
console.log(`uid: ${uid}`);

const db = getFirestore();
const base = db.collection("users").doc(uid);
const num = (v) => (typeof v === "number" && !Number.isNaN(v) ? v : 0);

const [incomes, allocations, expenses, categories, account, balances] = await Promise.all([
  base.collection("incomes").get(),
  base.collection("allocations").get(),
  base.collection("expenses").get(),
  base.collection("categories").get(),
  base.collection("meta").doc("account").get(),
  base.collection("balances").get(),
]);

const sum = (snap) => snap.docs.reduce((t, d) => t + num(d.get("amount")), 0);
const accountExpenses = expenses.docs
  .filter((d) => d.get("categoryId") == null)
  .reduce((t, d) => t + num(d.get("amount")), 0);
const recomputed = sum(incomes) - sum(allocations) - accountExpenses;

console.log("");
console.log(`docs: receitas ${incomes.size} | alocações ${allocations.size} | gastos ${expenses.size} | caixinhas ${categories.size}`);
console.log(`meta/account existe: ${account.exists}`);
const stored = account.exists ? account.get("balance") : null;
console.log(`saldo GUARDADO (meta/account.balance): ${stored}`);
console.log(`saldo RECALCULADO do ledger:           ${recomputed}`);
if (stored !== null) {
  const diff = stored - recomputed;
  console.log(`diferença (guardado - recalculado):    ${diff}`);
  console.log(Math.abs(diff) < 0.005 ? "=> batem (até o centavo)" : "=> NÃO BATEM");
  console.log(`guardado < 8650 (valor do gasto que falhou)? ${stored < 8650}`);
}

// Per-caixinha stored vs recomputed, ids only.
const catBal = new Map();
for (const a of allocations.docs) {
  const c = a.get("categoryId");
  if (c != null) catBal.set(c, (catBal.get(c) ?? 0) + num(a.get("amount")));
}
for (const e of expenses.docs) {
  const c = e.get("categoryId");
  if (c != null) catBal.set(c, (catBal.get(c) ?? 0) - num(e.get("amount")));
}
const mismatches = [];
for (const b of balances.docs) {
  const rec = catBal.get(b.id) ?? 0;
  if (Math.abs(num(b.get("balance")) - rec) >= 0.005) {
    mismatches.push(`${b.id}: guardado ${b.get("balance")} vs recalculado ${rec}`);
  }
}
console.log("");
console.log(`caixinhas com saldo guardado divergente: ${mismatches.length}`);
for (const m of mismatches) console.log(`  ${m}`);

const last = expenses.docs
  .map((d) => ({ data: d.get("date"), valor: d.get("amount"), destino: d.get("categoryId") ?? "(conta)", criado: d.get("createdAt") ?? null }))
  .sort((a, b) => String(b.data).localeCompare(String(a.data)))
  .slice(0, 5);
console.log("");
console.log("últimos 5 gastos (data, valor, destino):");
for (const l of last) console.log(`  ${l.data}  ${l.valor}  ${l.destino}  criado=${l.criado}`);
console.log("");
console.log("Do print: 'Disponível' 13027.84, gasto tentado 8650.");
