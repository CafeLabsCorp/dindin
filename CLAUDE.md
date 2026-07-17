# dindin

O que o app é, stack e como rodar: `README.md`. Como funciona por dentro:
`docs/ARQUITETURA.md`. Modelo de integridade de dinheiro: `docs/BACKEND.md`.
Deploy/rollback: `docs/DEPLOY.md`. Identidade visual: `docs/DESIGN.md`.

Específico de trabalhar neste repo com um agente:

- **Nunca habilite o plano Blaze nem faça deploy de `functions/`.** A decisão
  documentada é ficar no tier gratuito Spark com regras + saldos
  denormalizados (Option B, ver `docs/BACKEND.md`); `functions/` é código de
  referência inativo (Option A), não implantado.
- **Qualquer mudança em `firestore.rules`, no schema do ledger ou nos
  documentos de saldo (`meta/account`, `balances/{categoryId}`) precisa
  passar por `scripts/deploy.sh`**, nunca um `firebase deploy --only
  firestore:rules` direto — a ordem backup → backfill → rules é obrigatória
  (ver `docs/DEPLOY.md`/`docs/BACKEND.md`).
- Mensagens de commit neste repo são em português, seguindo o histórico
  existente (`git log --oneline`).
