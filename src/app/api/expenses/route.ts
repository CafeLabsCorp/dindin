import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { mutateDb, readDb } from "@/lib/db";
import { ExpenseSchema } from "@/lib/schemas";
import { categoryBalances } from "@/lib/aggregations";

const CreateExpenseSchema = ExpenseSchema.omit({ id: true });

export async function GET() {
  const db = await readDb();
  return NextResponse.json(
    [...db.expenses].sort((a, b) => b.date.localeCompare(a.date))
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const parsed = CreateExpenseSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const result = await mutateDb((db) => {
    const category = db.categories.find((c) => c.id === parsed.data.categoryId);
    if (!category) return { error: "category not found" as const };

    const balances = categoryBalances(db);
    const available = balances[category.id] ?? 0;
    if (parsed.data.amount > available + 1e-9) {
      return { error: "amount exceeds caixinha balance" as const };
    }

    const expense = { id: randomUUID(), ...parsed.data };
    db.expenses.push(expense);
    return { expense };
  });

  if ("error" in result) {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
  return NextResponse.json(result.expense, { status: 201 });
}
