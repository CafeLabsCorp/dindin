import { Db } from "./schemas";

export function monthKey(date: string): string {
  return date.slice(0, 7); // "YYYY-MM"
}

export function categoryBalances(db: Db): Record<string, number> {
  const balances: Record<string, number> = {};
  for (const cat of db.categories) balances[cat.id] = 0;
  for (const a of db.allocations) balances[a.categoryId] = (balances[a.categoryId] ?? 0) + a.amount;
  for (const e of db.expenses) balances[e.categoryId] = (balances[e.categoryId] ?? 0) - e.amount;
  return balances;
}

export function totalBalance(db: Db): number {
  return Object.values(categoryBalances(db)).reduce((sum, v) => sum + v, 0);
}

export function unallocatedByIncome(db: Db): Record<string, number> {
  const allocatedPerIncome: Record<string, number> = {};
  for (const a of db.allocations) {
    allocatedPerIncome[a.incomeId] = (allocatedPerIncome[a.incomeId] ?? 0) + a.amount;
  }
  const result: Record<string, number> = {};
  for (const inc of db.incomes) {
    result[inc.id] = inc.amount - (allocatedPerIncome[inc.id] ?? 0);
  }
  return result;
}

export interface MonthSummary {
  month: string; // "YYYY-MM"
  totalIncome: number;
  totalExpense: number;
  net: number;
  incomeBySource: Record<string, number>;
  expenseByCategory: Record<string, number>;
}

export function monthSummary(db: Db, month: string): MonthSummary {
  const incomes = db.incomes.filter((i) => monthKey(i.date) === month);
  const expenses = db.expenses.filter((e) => monthKey(e.date) === month);

  const incomeBySource: Record<string, number> = {};
  for (const i of incomes) {
    incomeBySource[i.source] = (incomeBySource[i.source] ?? 0) + i.amount;
  }

  const expenseByCategory: Record<string, number> = {};
  for (const e of expenses) {
    expenseByCategory[e.categoryId] = (expenseByCategory[e.categoryId] ?? 0) + e.amount;
  }

  const totalIncome = incomes.reduce((sum, i) => sum + i.amount, 0);
  const totalExpense = expenses.reduce((sum, e) => sum + e.amount, 0);

  return {
    month,
    totalIncome,
    totalExpense,
    net: totalIncome - totalExpense,
    incomeBySource,
    expenseByCategory,
  };
}

export function allMonths(db: Db): string[] {
  const set = new Set<string>();
  for (const i of db.incomes) set.add(monthKey(i.date));
  for (const e of db.expenses) set.add(monthKey(e.date));
  return Array.from(set).sort();
}

export function monthlyHistory(db: Db): MonthSummary[] {
  return allMonths(db).map((m) => monthSummary(db, m));
}

export function currentMonthKey(): string {
  return new Date().toISOString().slice(0, 7);
}
