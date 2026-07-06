"use client";

import { FormEvent, useState } from "react";
import { api } from "@/lib/api-client";
import { useCategories, useInvalidateAll } from "@/lib/hooks";
import { formatDate } from "@/lib/format";
import { Button, Card, EmptyState, Input, Label } from "@/components/ui";

export default function CategoriasPage() {
  const { data: categories, isLoading } = useCategories();
  const invalidateAll = useInvalidateAll();

  const [name, setName] = useState("");
  const [recurring, setRecurring] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!name.trim()) return;
    try {
      await api.categories.create({ name: name.trim(), recurring });
      setName("");
      setRecurring(true);
      await invalidateAll();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Remover categoria? Isso também apaga alocações e gastos ligados a ela.")) return;
    await api.categories.remove(id);
    await invalidateAll();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold">Categorias</h1>
        <p className="mt-1 text-sm" style={{ color: "var(--muted)" }}>
          Cada categoria vira uma caixinha onde você guarda dinheiro todo mês.
        </p>
      </div>

      <Card>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4 sm:flex-row sm:items-end">
          <div className="flex-1">
            <Label>Nome da categoria</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ex: Aluguel, Mercado, Investimento..."
            />
          </div>
          <label className="flex items-center gap-2 pb-2 text-sm">
            <input
              type="checkbox"
              checked={recurring}
              onChange={(e) => setRecurring(e.target.checked)}
            />
            Recorrente (repete todo mês)
          </label>
          <Button type="submit">Adicionar</Button>
        </form>
        {error && <p className="mt-3 text-sm text-red-500">{error}</p>}
      </Card>

      <Card>
        {isLoading ? (
          <EmptyState>Carregando...</EmptyState>
        ) : !categories || categories.length === 0 ? (
          <EmptyState>Nenhuma categoria ainda. Crie a primeira acima.</EmptyState>
        ) : (
          <ul className="flex flex-col">
            {categories.map((c, i) => (
              <li
                key={c.id}
                className="flex items-center justify-between py-3"
                style={{ borderTop: i > 0 ? "1px solid var(--border)" : "none" }}
              >
                <div>
                  <p className="text-sm font-medium">{c.name}</p>
                  <p className="text-xs" style={{ color: "var(--subtle)" }}>
                    {c.recurring ? "Recorrente" : "Pontual"} · desde {formatDate(c.createdAt)}
                  </p>
                </div>
                <Button variant="danger" onClick={() => handleDelete(c.id)}>
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
