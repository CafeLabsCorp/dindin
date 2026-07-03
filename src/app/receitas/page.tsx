"use client";

import { FormEvent, useState } from "react";
import { api, IncomeWithUnallocated } from "@/lib/api-client";
import { useCategories, useIncomes, useInvalidateAll } from "@/lib/hooks";
import { Category, IncomeSource } from "@/lib/schemas";
import { formatCurrency, todayIso } from "@/lib/format";
import { Button, Card, EmptyState, Input, Label, Select } from "@/components/ui";

const SOURCES: { value: IncomeSource; label: string }[] = [
  { value: "Estágio", label: "Estágio" },
  { value: "freela", label: "Freela" },
  { value: "outro", label: "Outro" },
];

export default function ReceitasPage() {
  const { data: incomes, isLoading } = useIncomes();
  const { data: categories } = useCategories();
  const invalidateAll = useInvalidateAll();

  const [date, setDate] = useState(todayIso());
  const [amount, setAmount] = useState("");
  const [source, setSource] = useState<IncomeSource>("Estágio");
  const [description, setDescription] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const value = Number(amount);
    if (!value || value <= 0) {
      setError("Informe um valor válido.");
      return;
    }
    try {
      await api.incomes.create({ date, amount: value, source, description: description || undefined });
      setAmount("");
      setDescription("");
      await invalidateAll();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Remover essa receita? As alocações feitas a partir dela também somem.")) return;
    await api.incomes.remove(id);
    await invalidateAll();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold">Receitas</h1>
        <p className="mt-1 text-sm" style={{ color: "var(--muted)" }}>
          Lance o quanto entrou, de onde veio, e depois separe entre as caixinhas.
        </p>
      </div>

      <Card>
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
            <Label>Origem</Label>
            <Select value={source} onChange={(e) => setSource(e.target.value as IncomeSource)}>
              {SOURCES.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </Select>
          </div>
          <div>
            <Label>Descrição (opcional)</Label>
            <Input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Ex: salário julho" />
          </div>
          <div className="col-span-2 sm:col-span-4">
            <Button type="submit">Lançar receita</Button>
          </div>
        </form>
        {error && <p className="mt-3 text-sm text-red-500">{error}</p>}
      </Card>

      <Card>
        <h2 className="mb-3 text-sm font-semibold">Receitas lançadas</h2>
        {isLoading ? (
          <EmptyState>Carregando...</EmptyState>
        ) : !incomes || incomes.length === 0 ? (
          <EmptyState>Nenhuma receita lançada ainda.</EmptyState>
        ) : (
          <ul className="flex flex-col gap-3">
            {incomes.map((income) => (
              <IncomeRow
                key={income.id}
                income={income}
                categories={categories ?? []}
                onChanged={invalidateAll}
                onDelete={() => handleDelete(income.id)}
              />
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}

function IncomeRow({
  income,
  categories,
  onChanged,
  onDelete,
}: {
  income: IncomeWithUnallocated;
  categories: Category[];
  onChanged: () => void;
  onDelete: () => void;
}) {
  const [categoryId, setCategoryId] = useState(categories[0]?.id ?? "");
  const [allocAmount, setAllocAmount] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);

  async function handleAllocate(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const value = Number(allocAmount);
    if (!value || value <= 0 || !categoryId) {
      setError("Escolha uma categoria e um valor válido.");
      return;
    }
    try {
      await api.allocations.create({ incomeId: income.id, categoryId, amount: value, date: income.date });
      setAllocAmount("");
      onChanged();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <li className="rounded-lg border p-3" style={{ borderColor: "var(--border)" }}>
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-medium">
            {formatCurrency(income.amount)}{" "}
            <span className="font-normal" style={{ color: "var(--subtle)" }}>
              · {income.source} · {income.date}
            </span>
          </p>
          {income.description && (
            <p className="text-xs" style={{ color: "var(--subtle)" }}>
              {income.description}
            </p>
          )}
        </div>
        <div className="flex items-center gap-2">
          {income.unallocated > 0.009 ? (
            <span className="text-xs font-medium" style={{ color: "#eda100" }}>
              {formatCurrency(income.unallocated)} a alocar
            </span>
          ) : (
            <span className="text-xs font-medium" style={{ color: "#0ca30c" }}>
              Totalmente alocada
            </span>
          )}
          <Button variant="ghost" onClick={() => setOpen((v) => !v)}>
            {open ? "Fechar" : "Alocar"}
          </Button>
          <Button variant="danger" onClick={onDelete}>
            Remover
          </Button>
        </div>
      </div>

      {open && (
        <form onSubmit={handleAllocate} className="mt-3 flex flex-wrap items-end gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
          <div className="min-w-[160px] flex-1">
            <Label>Caixinha</Label>
            <Select value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
              {categories.length === 0 ? (
                <option value="">Nenhuma categoria criada</option>
              ) : (
                categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))
              )}
            </Select>
          </div>
          <div className="w-32">
            <Label>Valor</Label>
            <Input
              type="number"
              step="0.01"
              min="0"
              value={allocAmount}
              onChange={(e) => setAllocAmount(e.target.value)}
              placeholder="0,00"
            />
          </div>
          <Button
            type="button"
            variant="ghost"
            onClick={() => setAllocAmount(String(income.unallocated))}
          >
            Preencher restante
          </Button>
          <Button type="submit">Confirmar</Button>
        </form>
      )}
      {error && <p className="mt-2 text-sm text-red-500">{error}</p>}
    </li>
  );
}
