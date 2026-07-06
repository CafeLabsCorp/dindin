import { Card } from "./ui";

export function StatTile({
  label,
  value,
  color,
}: {
  label: string;
  value: string;
  color?: string;
}) {
  return (
    <Card className="flex flex-col gap-1">
      <span className="text-xs font-medium" style={{ color: "var(--muted)" }}>
        {label}
      </span>
      <span className="text-2xl font-semibold tabular-nums" style={{ color: color ?? "var(--foreground)" }}>
        {value}
      </span>
    </Card>
  );
}
