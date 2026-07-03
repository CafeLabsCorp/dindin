import { Allocation, Category, Expense, Income } from "./schemas";
import { MonthSummary } from "./aggregations";

export type IncomeWithUnallocated = Income & { unallocated: number };

export interface Summary {
  total: number;
  balancesByCategory: Record<string, number>;
  currentMonth: MonthSummary;
  history: MonthSummary[];
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error ? JSON.stringify(body.error) : `Request failed: ${res.status}`);
  }
  return res.json();
}

export const api = {
  categories: {
    list: () => request<Category[]>("/api/categories"),
    create: (data: { name: string; recurring: boolean }) =>
      request<Category>("/api/categories", { method: "POST", body: JSON.stringify(data) }),
    remove: (id: string) => request<{ ok: true }>(`/api/categories/${id}`, { method: "DELETE" }),
  },
  incomes: {
    list: () => request<IncomeWithUnallocated[]>("/api/incomes"),
    create: (data: { date: string; amount: number; source: string; description?: string }) =>
      request<Income>("/api/incomes", { method: "POST", body: JSON.stringify(data) }),
    remove: (id: string) => request<{ ok: true }>(`/api/incomes/${id}`, { method: "DELETE" }),
  },
  allocations: {
    list: () => request<Allocation[]>("/api/allocations"),
    create: (data: { incomeId: string; categoryId: string; amount: number; date: string }) =>
      request<Allocation>("/api/allocations", { method: "POST", body: JSON.stringify(data) }),
    remove: (id: string) => request<{ ok: true }>(`/api/allocations/${id}`, { method: "DELETE" }),
  },
  expenses: {
    list: () => request<Expense[]>("/api/expenses"),
    create: (data: { date: string; amount: number; categoryId: string; description?: string }) =>
      request<Expense>("/api/expenses", { method: "POST", body: JSON.stringify(data) }),
    remove: (id: string) => request<{ ok: true }>(`/api/expenses/${id}`, { method: "DELETE" }),
  },
  summary: {
    get: () => request<Summary>("/api/summary"),
  },
};
