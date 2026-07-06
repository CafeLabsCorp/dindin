import { NextRequest, NextResponse } from "next/server";
import { mutateDb } from "@/lib/db";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const deleted = await mutateDb((db) => {
    const before = db.incomes.length;
    db.incomes = db.incomes.filter((i) => i.id !== id);
    db.allocations = db.allocations.filter((a) => a.incomeId !== id);
    return db.incomes.length < before;
  });

  if (!deleted) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json({ ok: true });
}
