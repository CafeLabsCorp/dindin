import { NextRequest, NextResponse } from "next/server";
import { mutateDb } from "@/lib/db";

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const deleted = await mutateDb((db) => {
    const before = db.allocations.length;
    db.allocations = db.allocations.filter((a) => a.id !== id);
    return db.allocations.length < before;
  });

  if (!deleted) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json({ ok: true });
}
