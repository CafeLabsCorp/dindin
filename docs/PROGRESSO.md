# Progress log

[Leia em Português](PROGRESSO.pt-br.md)

## Resume here

- **Phase:** documentation pass for version 1.2.1+7 (sent to Google Play on
  2026-11-16, awaiting review). All docs in `docs/` and both READMEs were
  reconciled against the code on 2026-11-16; nothing committed yet.
- **Next step:** the maintainer reviews the working-tree diff and commits. When
  Google approves 1.2.1, record it in the published-versions table of
  `docs/DEPLOY.md` (and `.pt-br`) and in `README.md`'s status block. Then close
  or move items in `docs/PENDENCIAS.md`.
- **Waiting on the user:** trader-status declaration in Play Console (by
  2027-02-01); real-device check of onboarding, opening animation, in-app update
  indicator and the theme selector on a narrow screen.

## Units

| Unit | State | Output |
|---|---|---|
| README (en/pt-br) | feito | `README.md`, `README.pt-br.md` |
| Architecture, incl. Trace C (onboarding) | feito | `docs/ARQUITETURA*.md` |
| Backend / rules / integration surface | feito | `docs/BACKEND*.md` |
| Deploy, release flow, published versions | feito | `docs/DEPLOY*.md` |
| Play Console status | feito | `docs/PLAY_CONSOLE*.md` |
| Design (theme selector, manual, onboarding visuals) | feito | `docs/DESIGN*.md` |
| Onboarding design vs. what was built | feito | `docs/onboarding-design.md` (section 10) |
| Open items | feito | `docs/PENDENCIAS*.md` |

## Decisions and conventions

- English is the primary language of the doc set; Portuguese siblings use the
  `.pt-br.md` suffix. `docs/onboarding-design.md` and the HTML mockup are
  Portuguese only.
- The brand manual lives in `cafelabs-vault` and is only referenced here.
- Facts that could not be read from the repo (Play Console state, dates of
  approval) come from the maintainer's board and are labeled as such; unknowns are
  `TODO: confirmar`, listed in `docs/PENDENCIAS.md`.

## History

- 2026-11-16, docs: reconciled the doc set with 1.2.1+7 (tests: 715 Flutter, 128 +
  9 rules counted in the files), created `PENDENCIAS` and `PROGRESSO`.
