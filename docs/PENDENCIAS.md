# Open items

[Leia em Português](PENDENCIAS.pt-br.md)

What is still open in Dindin, written 2026-11-16 (version 1.2.1+7). The
maintainer's task board lives outside this repo; this file keeps what a
developer needs to know. Other docs link here instead of repeating items.

## Open

- [ ] **Not verified on a real device:** the onboarding tutorials (7 pages,
  guided empty states, first-steps card, navigation chip), the opening
  animation, the Play in-app update indicator (badge/menu item, only the
  snackbar has been seen), and the theme selector on a narrow phone screen.
  Covered only by widget tests (715 pass), the rules emulator and rendered
  captures. _origem:_ docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Version 1.2.1+7 is awaiting Google's review** (sent 2026-11-16).
  1.2.0+6 is the last version confirmed live. _origem:_ docs, 2026-11-16.
  _gravidade:_ menor.
- [ ] **Play Console: declare trader (comerciante) status by 2027-02-01.**
  Without it the developer profile and its apps are removed from Play
  worldwide. Maintainer's decision. See `docs/PLAY_CONSOLE.md`. _origem:_ docs,
  2026-11-16. _gravidade:_ bloqueia lançamento (a partir de 2027-02-01).
- [ ] **App Check "Enforce" is not on** for Firestore/Authentication; the Google
  Cloud project linked to Play Integrity is still to be confirmed. Enforce would
  also reject the web client (no web App Check). See `docs/BACKEND.md`, "App
  Check". _origem:_ docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Brand-manual conformance not checked** for the Dashboard charts,
  Receitas, Gastos, Assinaturas, Parcelamentos, the login page and dialogs
  (only Ajustes and Categorias were rendered against the manual). See
  `docs/DESIGN.md`, section 6. _origem:_ docs, 2026-11-16. _gravidade:_ menor.
- [ ] **Operation scripts run as the maintainer's personal Google account**
  (`scripts/deploy.sh`, `scripts/sweep_orphans.mjs`), not a scoped service
  account (the org policy blocks service-account keys; the path is keyless
  impersonation). Left open on purpose. _origem:_ board, 2026-09-23.
  _gravidade:_ menor.
- [ ] **No separate dev/prod Firebase project**; only `dindin-cafelabs`.
  _origem:_ board. _gravidade:_ menor.
- [ ] **A stream error looks like "still loading"** in the UI (no dedicated
  error state; none is planned, maintainer 2026-11-16). See `docs/BACKEND.md`, integration surface. _origem:_ docs,
  2026-11-16. _gravidade:_ menor.
- [ ] **Inconsistent spelling:** Android label and Play title use "Dindin",
  `web/index.html`'s `<title>` is still `dindin`. _origem:_ docs, 2026-11-16.
  _gravidade:_ menor.
- [ ] **Public store listing screenshots show real account data** of the
  maintainer; redo with a demo account if that is a problem, and upload the final
  assets to the company Drive. See `docs/play-store-assets/README.md`.
  _origem:_ board. _gravidade:_ menor.
- [ ] **Firebase fingerprint `28:E1:77...`** of unknown origin still registered
  in the console; decide whether to remove it. _origem:_ board. _gravidade:_
  menor.

## Accepted risks

- **Firestore rules cannot rate-limit or fully stop a client rewriting its own
  balance docs** (Option B, free Spark tier, no Cloud Functions). Accepted by the
  maintainer; displayed balances are re-summed from the ledger, so the damage
  stays within the user's own account. See `docs/BACKEND.md`, "Option B residual
  limitations".
- **The Dashboard reads the whole ledger every session** (re-sums instead of
  trusting the cached balance docs). Accepted cost against the Spark read quota;
  revisit with accounts of tens of thousands of rows. `docs/BACKEND.md`.
- **No automated test runs on a real device or against the real Play update
  plugin.**
- **Web has no App Check** (decision 2026-09-21: reCAPTCHA Enterprise would need
  billing).

## Dependencies

- **Firebase project `dindin-cafelabs`** (Auth, Firestore in São Paulo,
  Hosting, App Check, Analytics), Spark plan. `functions/` is inactive reference
  code and must not be deployed (needs Blaze).
- **Google Play Console** (developer account is an individual account) for the
  Android release; upload keystore stored outside the repo
  (`android/key.properties`).
- **`dindin-landing`** site hosts the public legal pages
  (`/privacidade`, `/termos`, `/excluir-conta`) whose source text is `legal/`.
- **`cafelabs-vault`** (company knowledge repo) holds the brand manual
  (`marca/dindin/`), the source of truth for the visual identity.
- Tooling: Flutter 3.44.4 (pinned in CI), Node for `scripts/` and
  `test/rules/`, Firebase CLI and the Firestore emulator for the rules tests.

## To confirm

Answered by the maintainer on 2026-11-16 and already applied: `/privacidade`,
`/termos` and `/excluir-conta` resolve in production; the `windows/` folder was
deleted; no dedicated stream-error UI is planned.

- `docs/DEPLOY.md`: whether each Play release used a staged rollout (the
  maintainer doesn't remember; check Play Console → Test and release →
  Production → release history); the exact history of `versionCode` 1-2 (unknown,
  only a record).
