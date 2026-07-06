import { NextRequest, NextResponse } from "next/server";
import { mutateDb } from "@/lib/db";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const deleted = await mutateDb((db) => {
    const before = db.expenses.length;
    db.expenses = db.expenses.filter((e) => e.id !== id);
    return db.expenses.length < before;
  });

  if (!deleted) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json({ ok: true });
}
