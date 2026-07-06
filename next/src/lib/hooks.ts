import useSWR, { useSWRConfig } from "swr";
import { api, IncomeWithUnallocated, Summary } from "./api-client";
import { Category, Expense } from "./schemas";

export function useCategories() {
  return useSWR<Category[]>("/api/categories", api.categories.list);
}

export function useIncomes() {
  return useSWR<IncomeWithUnallocated[]>("/api/incomes", api.incomes.list);
}

export function useExpenses() {
  return useSWR<Expense[]>("/api/expenses", api.expenses.list);
}

export function useSummary() {
  return useSWR<Summary>("/api/summary", api.summary.get);
}

/** Revalidates every cached /api/* key — used after any create/delete mutation. */
export function useInvalidateAll() {
  const { mutate } = useSWRConfig();
  return () => mutate((key) => typeof key === "string" && key.startsWith("/api/"));
}
