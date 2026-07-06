# dindin

App pessoal de controle financeiro por "caixinhas": receitas entram, são alocadas
entre categorias, e os gastos saem de cada categoria.

O app está em migração de Next.js para **Flutter + Firebase** (Web, Android e
Windows). Veja [FLUTTER_MIGRATION.md](FLUTTER_MIGRATION.md) para a arquitetura e o
roadmap completo.

- `lib/`, `pubspec.yaml`, `android/`, `windows/`, `web/` — app Flutter (novo).
- `next/` — app Next.js original, mantido até a migração terminar.
