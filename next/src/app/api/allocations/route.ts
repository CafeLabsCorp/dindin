import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { mutateDb, readDb } from "@/lib/db";
import { AllocationSchema } from "@/lib/schemas";

const CreateAllocationSchema = AllocationSchema.omit({ id: true });

export async function GET() {
  const db = await readDb();
  return NextResponse.json(db.allocations);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const parsed = CreateAllocationSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const result = await mutateDb((db) => {
    const income = db.incomes.find((i) => i.id === parsed.data.incomeId);
    const category = db.categories.find((c) => c.id === parsed.data.categoryId);
    if (!income) return { error: "income not found" as const };
    if (!category) return { error: "category not found" as const };

    const alreadyAllocated = db.allocations
      .filter((a) => a.incomeId === income.id)
      .reduce((sum, a) => sum + a.amount, 0);
    if (alreadyAllocated + parsed.data.amount > income.amount + 1e-9) {
      return { error: "amount exceeds unallocated income" as const };
    }

    const allocation = { id: randomUUID(), ...parsed.data };
    db.allocations.push(allocation);
    return { allocation };
  });

  if ("error" in result) {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
  return NextResponse.json(result.allocation, { status: 201 });
}
