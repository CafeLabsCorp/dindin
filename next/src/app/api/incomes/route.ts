import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { mutateDb, readDb } from "@/lib/db";
import { IncomeSchema } from "@/lib/schemas";
import { unallocatedByIncome } from "@/lib/aggregations";

const CreateIncomeSchema = IncomeSchema.omit({ id: true });

export async function GET() {
  const db = await readDb();
  const unallocated = unallocatedByIncome(db);
  const incomes = db.incomes
    .map((i) => ({ ...i, unallocated: unallocated[i.id] ?? 0 }))
    .sort((a, b) => b.date.localeCompare(a.date));
  return NextResponse.json(incomes);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const parsed = CreateIncomeSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const income = await mutateDb((db) => {
    const newIncome = { id: randomUUID(), ...parsed.data };
    db.incomes.push(newIncome);
    return newIncome;
  });

  return NextResponse.json(income, { status: 201 });
}
