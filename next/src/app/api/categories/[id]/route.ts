import { NextRequest, NextResponse } from "next/server";
import { mutateDb } from "@/lib/db";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const deleted = await mutateDb((db) => {
    const before = db.categories.length;
    db.categories = db.categories.filter((c) => c.id !== id);
    db.allocations = db.allocations.filter((a) => a.categoryId !== id);
    db.expenses = db.expenses.filter((e) => e.categoryId !== id);
    return db.categories.length < before;
  });

  if (!deleted) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json({ ok: true });
}
