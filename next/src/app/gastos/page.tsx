"use client";

import { FormEvent, useMemo, useState } from "react";
import { api } from "@/lib/api-client";
import { useCategories, useExpenses, useInvalidateAll, useSummary } from "@/lib/hooks";
import { formatCurrency, todayIso } from "@/lib/format";
import { Button, Card, EmptyState, Input, Label, Select } from "@/components/ui";

export default function GastosPage() {
  const { data: expenses, isLoading } = useExpenses();
  const { data: categories } = useCategories();
  const { data: summary } = useSummary();
  const invalidateAll = useInvalidateAll();

  const [date, setDate] = useState(todayIso());
  const [amount, setAmount] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [description, setDescription] = useState("");
  const [error, setError] = useState<string | null>(null);

  const effectiveCategoryId = categoryId || categories?.[0]?.id || "";

  const categoryName = useMemo(() => {
    const map: Record<string, string> = {};
    for (const c of categories ?? []) map[c.id] = c.name;
    return map;
  }, [categories]);

  const availableBalance = effectiveCategoryId
    ? summary?.balancesByCategory[effectiveCategoryId] ?? 0
    : 0;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const value = Number(amount);
    if (!value || value <= 0 || !effectiveCategoryId) {
      setError("Escolha uma categoria e um valor válido.");
      return;
    }
    try {
      await api.expenses.create({
        date,
        amount: value,
        categoryId: effectiveCategoryId,
        description: description || undefined,
      });
      setAmount("");
      setDescription("");
      await invalidateAll();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Remover esse gasto?")) return;
    await api.expenses.remove(id);
    await invalidateAll();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold">Gastos</h1>
        <p className="mt-1 text-sm" style={{ color: "var(--muted)" }}>
          Registre saídas de dinheiro de uma caixinha específica.
        </p>
      </div>

      <Card>
        {!categories || categories.length === 0 ? (
          <EmptyState>Crie uma categoria antes de lançar gastos.</EmptyState>
        ) : (
          <form onSubmit={handleSubmit} className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <div>
              <Label>Data</Label>
              <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            </div>
            <div>
              <Label>Valor</Label>
              <Input
                type="number"
                step="0.01"
                min="0"
                placeholder="0,00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
              />
            </div>
            <div>
              <Label>Caixinha</Label>
              <Select value={effectiveCategoryId} onChange={(e) => setCategoryId(e.target.value)}>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
              <p className="mt-1 text-xs" style={{ color: "var(--subtle)" }}>
                Disponível: {formatCurrency(availableBalance)}
              </p>
            </div>
            <div>
              <Label>Descrição (opcional)</Label>
              <Input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Ex: supermercado" />
            </div>
            <div className="col-span-2 sm:col-span-4">
              <Button type="submit">Lançar gasto</Button>
            </div>
          </form>
        )}
        {error && <p className="mt-3 text-sm text-red-500">{error}</p>}
      </Card>

      <Card>
        <h2 className="mb-3 text-sm font-semibold">Gastos lançados</h2>
        {isLoading ? (
          <EmptyState>Carregando...</EmptyState>
        ) : !expenses || expenses.length === 0 ? (
          <EmptyState>Nenhum gasto lançado ainda.</EmptyState>
        ) : (
          <ul className="flex flex-col">
            {expenses.map((exp, i) => (
              <li
                key={exp.id}
                className="flex items-center justify-between py-3"
                style={{ borderTop: i > 0 ? "1px solid var(--border)" : "none" }}
              >
                <div>
                  <p className="text-sm font-medium">
                    {formatCurrency(exp.amount)}{" "}
                    <span className="font-normal" style={{ color: "var(--subtle)" }}>
                      · {categoryName[exp.categoryId] ?? "categoria removida"} · {exp.date}
                    </span>
                  </p>
                  {exp.description && (
                    <p className="text-xs" style={{ color: "var(--subtle)" }}>
                      {exp.description}
                    </p>
                  )}
                </div>
                <Button variant="danger" onClick={() => handleDelete(exp.id)}>
                  Remover
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
