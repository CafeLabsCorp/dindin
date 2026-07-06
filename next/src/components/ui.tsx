"use client";

import { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from "react";

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-xl border p-5 ${className}`}
      style={{ background: "var(--surface)", borderColor: "var(--border)" }}
    >
      {children}
    </div>
  );
}

export function Label({ children }: { children: ReactNode }) {
  return (
    <label className="mb-1 block text-xs font-medium" style={{ color: "var(--muted)" }}>
      {children}
    </label>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={`w-full rounded-md border px-3 py-2 text-sm outline-none focus:ring-2 ${props.className ?? ""}`}
      style={{
        background: "var(--background)",
        borderColor: "var(--border)",
        color: "var(--foreground)",
      }}
    />
  );
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className={`w-full rounded-md border px-3 py-2 text-sm outline-none focus:ring-2 ${props.className ?? ""}`}
      style={{
        background: "var(--background)",
        borderColor: "var(--border)",
        color: "var(--foreground)",
      }}
    />
  );
}

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "ghost" | "danger" }) {
  const styles = {
    primary: { background: "#2a78d6", color: "#ffffff", borderColor: "#2a78d6" },
    ghost: { background: "transparent", color: "var(--muted)", borderColor: "var(--border)" },
    danger: { background: "transparent", color: "#d03b3b", borderColor: "var(--border)" },
  }[variant];

  return (
    <button
      {...props}
      className={`rounded-md border px-3 py-2 text-sm font-medium transition-opacity hover:opacity-85 disabled:opacity-50 ${className}`}
      style={styles}
    />
  );
}

export function EmptyState({ children }: { children: ReactNode }) {
  return (
    <p className="py-6 text-center text-sm" style={{ color: "var(--subtle)" }}>
      {children}
    </p>
  );
}
