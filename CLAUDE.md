# dindin

What the app is, the stack, and how to run it: `README.md`. How it works
internally: `docs/ARQUITETURA.md`. Money-integrity model: `docs/BACKEND.md`.
Deploy/rollback: `docs/DEPLOY.md`. Visual identity: `docs/DESIGN.md`.

Specific to working in this repo with an agent:

- **Never enable the Blaze plan or deploy `functions/`.** The documented
  decision is to stay on the free Spark tier with rules + denormalized
  balances (Option B, see `docs/BACKEND.md`); `functions/` is inactive
  reference code (Option A), not deployed.
- **Any change to `firestore.rules`, the ledger schema, or the balance
  documents (`meta/account`, `balances/{categoryId}`) must go through
  `scripts/deploy.sh`**, never a direct `firebase deploy --only
  firestore:rules` — the backup → backfill → rules order is mandatory (see
  `docs/DEPLOY.md`/`docs/BACKEND.md`).
- Commit messages in this repo are in Portuguese, following the existing
  history (`git log --oneline`).
- **Significant future changes to this project should go through the Forge**
  (the specialized agent team in the `forge` repo) rather than being made
  ad-hoc in a plain session — it routes the work to the right specialists
  (backend, mobile, docs, etc.) and keeps this doc set in sync with the code.
