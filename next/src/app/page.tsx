"use client";

import { useMemo } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useCategories, useSummary } from "@/lib/hooks";
import { formatCurrency, formatCurrencyCompact, formatDate, formatMonthLabel } from "@/lib/format";
import { palette } from "@/lib/palette";
import { Card, EmptyState } from "@/components/ui";
import { StatTile } from "@/components/StatTile";

export default function DashboardPage() {
  const { data: summary, isLoading: summaryLoading } = useSummary();
  const { data: categories } = useCategories();
  const loading = summaryLoading || !summary;

  const caixinhas = useMemo(() => {
    if (!summary || !categories) return [];
    return categories
      .map((c) => ({
        id: c.id,
        name: c.name,
        value: summary.balancesByCategory[c.id] ?? 0,
        createdAt: c.createdAt,
      }))
      .sort((a, b) => b.value - a.value);
  }, [summary, categories]);

  const history = useMemo(() => {
    if (!summary) return [];
    return summary.history.map((m) => ({
      month: formatMonthLabel(m.month),
      Recebido: m.totalIncome,
      Gasto: m.totalExpense,
    }));
  }, [summary]);

  if (loading || !summary) {
    return (
      <Card>
        <EmptyState>Carregando...</EmptyState>
      </Card>
    );
  }

  const netColor = summary.currentMonth.net >= 0 ? palette.status.good : palette.status.critical;

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <p className="mt-1 text-sm" style={{ color: "var(--muted)" }}>
          Visão geral da conta e do mês atual.
        </p>
      </div>

      <StatTile label="Saldo total (todas as caixinhas)" value={formatCurrency(summary.total)} />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatTile label="Recebido este mês" value={formatCurrency(summary.currentMonth.totalIncome)} />
        <StatTile label="Gasto este mês" value={formatCurrency(summary.currentMonth.totalExpense)} />
        <StatTile label="Saldo do mês" value={formatCurrency(summary.currentMonth.net)} color={netColor} />
      </div>

      <Card>
        <h2 className="mb-4 text-sm font-semibold">Caixinhas</h2>
        {caixinhas.length === 0 ? (
          <EmptyState>Crie categorias e aloque receitas para ver suas caixinhas aqui.</EmptyState>
        ) : (
          <ul className="flex flex-col">
            {caixinhas.map((c, i) => (
              <li
                key={c.id}
                className="flex items-center justify-between py-2.5 text-sm"
                style={{ borderTop: i > 0 ? "1px solid var(--border)" : "none" }}
              >
                <div>
                  <span className="font-medium">{c.name}</span>{" "}
                  <span className="text-xs" style={{ color: "var(--subtle)" }}>
                    desde {formatDate(c.createdAt)}
                  </span>
                </div>
                <span className="tabular-nums" style={{ color: "var(--muted)" }}>
                  {formatCurrency(c.value)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card>
        <h2 className="mb-4 text-sm font-semibold">Histórico mensal — recebido x gasto</h2>
        {history.length === 0 ? (
          <EmptyState>Lance receitas e gastos para ver o histórico por mês.</EmptyState>
        ) : (
          <div style={{ width: "100%", height: 280 }}>
            <ResponsiveContainer>
              <BarChart data={history} barGap={2} margin={{ left: -12 }}>
                <CartesianGrid vertical={false} stroke={palette.ink.grid} />
                <XAxis
                  dataKey="month"
                  tick={{ fontSize: 12, fill: palette.ink.muted }}
                  axisLine={{ stroke: palette.ink.grid }}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 12, fill: palette.ink.muted }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) => formatCurrencyCompact(v)}
                  width={88}
                />
                <Tooltip
                  formatter={(value) => formatCurrency(Number(value))}
                  contentStyle={{
                    background: "var(--surface)",
                    border: "1px solid var(--border)",
                    borderRadius: 8,
                    fontSize: 12,
                  }}
                />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <Bar dataKey="Recebido" fill={palette.categorical[0]} radius={[4, 4, 0, 0]} maxBarSize={28} />
                <Bar dataKey="Gasto" fill={palette.categorical[1]} radius={[4, 4, 0, 0]} maxBarSize={28} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>
    </div>
  );
}
