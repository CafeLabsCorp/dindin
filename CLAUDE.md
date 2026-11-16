# dindin

What the app is, the stack, and how to run it: `README.md`. How it works
internally: `docs/ARQUITETURA.md`. Money-integrity model: `docs/BACKEND.md`.
Deploy/release/rollback: `docs/DEPLOY.md`. Visual identity: `docs/DESIGN.md`.
Play Console status: `docs/PLAY_CONSOLE.md`. Open items and what is not verified
on a real device: `docs/PENDENCIAS.md`. Where the work stands:
`docs/PROGRESSO.md`. Docs are bilingual (`X.md` English, `X.pt-br.md`
Portuguese): keep both in sync when you change one.
Open items and what is unverified: `docs/PENDENCIAS.md`. Play Console state:
`docs/PLAY_CONSOLE.md`. Docs also exist in Portuguese (`*.pt-br.md`); keep both in sync.

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
- **Never publish a version, create a `vX.Y.Z` tag, or run `scripts/deploy.sh`
  (or any `firebase deploy`) without the maintainer's explicit go-ahead.**
  `scripts/release_android.sh` is the only release path and it does not commit,
  tag or upload.
- **Do not claim something works "on the phone" from tests alone.** The
  onboarding, theme selector, opening animation and the in-app update indicator
  are only verified in widget tests/emulators; say so (see
  `docs/PENDENCIAS.md`).
- `flutter test` needs nothing extra; `test/rules` needs the Firestore emulator
  running (see `README.md`, "Running tests").
