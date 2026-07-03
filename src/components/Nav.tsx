"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/", label: "Dashboard" },
  { href: "/receitas", label: "Receitas" },
  { href: "/gastos", label: "Gastos" },
  { href: "/categorias", label: "Categorias" },
];

export function Nav() {
  const pathname = usePathname();

  return (
    <header
      className="sticky top-0 z-10 border-b"
      style={{ background: "var(--surface)", borderColor: "var(--border)" }}
    >
      <div className="mx-auto flex max-w-4xl items-center gap-1 px-4 py-3">
        <span className="mr-4 text-base font-semibold">dindin</span>
        <nav className="flex gap-1">
          {LINKS.map((link) => {
            const active = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-md px-3 py-1.5 text-sm transition-colors"
                style={{
                  background: active ? "var(--background)" : "transparent",
                  color: active ? "var(--foreground)" : "var(--muted)",
                  fontWeight: active ? 600 : 400,
                }}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>
      </div>
    </header>
  );
}
