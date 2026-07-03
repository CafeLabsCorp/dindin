import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { mutateDb, readDb } from "@/lib/db";
import { CategorySchema } from "@/lib/schemas";

const CreateCategorySchema = CategorySchema.pick({ name: true, recurring: true });

export async function GET() {
  const db = await readDb();
  return NextResponse.json(db.categories);
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const parsed = CreateCategorySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const category = await mutateDb((db) => {
    const newCategory = {
      id: randomUUID(),
      name: parsed.data.name,
      recurring: parsed.data.recurring,
      createdAt: new Date().toISOString(),
    };
    db.categories.push(newCategory);
    return newCategory;
  });

  return NextResponse.json(category, { status: 201 });
}
