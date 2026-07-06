import { z } from "zod";

export const IncomeSourceSchema = z.enum(["Estágio", "freela", "outro"]);
export type IncomeSource = z.infer<typeof IncomeSourceSchema>;

export const CategorySchema = z.object({
  id: z.string(),
  name: z.string().min(1),
  recurring: z.boolean(),
  createdAt: z.string(),
});
export type Category = z.infer<typeof CategorySchema>;

export const IncomeSchema = z.object({
  id: z.string(),
  date: z.string(), // ISO date (YYYY-MM-DD)
  amount: z.number().positive(),
  source: IncomeSourceSchema,
  description: z.string().optional(),
});
export type Income = z.infer<typeof IncomeSchema>;

export const AllocationSchema = z.object({
  id: z.string(),
  incomeId: z.string(),
  categoryId: z.string(),
  amount: z.number().positive(),
  date: z.string(),
});
export type Allocation = z.infer<typeof AllocationSchema>;

export const ExpenseSchema = z.object({
  id: z.string(),
  date: z.string(),
  amount: z.number().positive(),
  categoryId: z.string(),
  description: z.string().optional(),
});
export type Expense = z.infer<typeof ExpenseSchema>;

export const DbSchema = z.object({
  categories: z.array(CategorySchema),
  incomes: z.array(IncomeSchema),
  allocations: z.array(AllocationSchema),
  expenses: z.array(ExpenseSchema),
});
export type Db = z.infer<typeof DbSchema>;

export const EMPTY_DB: Db = {
  categories: [],
  incomes: [],
  allocations: [],
  expenses: [],
};
