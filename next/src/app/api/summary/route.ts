import { NextResponse } from "next/server";
import { readDb } from "@/lib/db";
import {
  categoryBalances,
  totalBalance,
  monthlyHistory,
  monthSummary,
  currentMonthKey,
} from "@/lib/aggregations";

export async function GET() {
  const db = await readDb();
  const balances = categoryBalances(db);

  return NextResponse.json({
    total: totalBalance(db),
    balancesByCategory: balances,
    currentMonth: monthSummary(db, currentMonthKey()),
    history: monthlyHistory(db),
  });
}
