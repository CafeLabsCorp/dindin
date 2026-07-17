# Dindin — Design system: "Envelope caloroso"

Status: **implemented**. This is the reference for the app's visual identity
— color tokens, typography, shape/spacing/elevation, component styling —
matching what actually ships in `lib/theme/colors.dart` and
`lib/theme/theme.dart`. It replaced the generic Material-seed-blue + Roboto
identity inherited from an earlier Next.js version of the app (long since
removed from the repo).

All hex values below were checked against WCAG 2.1 contrast math by hand
(relative luminance → contrast ratio). Ratios are stated next to every
foreground/background pair used for real text so they can be trusted without
re-deriving. AA requires ≥4.5:1 for body text, ≥3:1 for large text (≥24px, or
≥19px bold) and for purely graphical/non-text objects (e.g. a progress bar
fill against its track).

---

## 1. Color tokens

### 1.1 Light theme

| Token | Hex | Notes |
|---|---|---|
| `primary` | `#2E6F4D` | Deep forest-teal green ("Verde Cofre" — vault green). Tied to money/growth, warmer-leaning than a cold teal. |
| `onPrimary` | `#FFFFFF` | On `primary`: **6.02:1** |
| `primaryContainer` | `#D7EBDD` | Tonal fill (e.g. `FilledButton.tonal` when explicitly primary-styled, selected nav indicator if remapped) |
| `onPrimaryContainer` | `#14392A` | On `primaryContainer`: **10.20:1** |
| `secondary` | `#6B7A5E` | Muted warm sage — low-emphasis actions, e.g. today's "Alocar" button, `FilledButton.tonal` default in Material 3 |
| `onSecondary` | `#FFFFFF` | On `secondary`: **4.59:1** |
| `secondaryContainer` | `#E1E8D8` | |
| `onSecondaryContainer` | `#2B3320` | On `secondaryContainer`: **10.48:1** |
| `tertiary` (accent) | `#C1502E` | Coral/terracotta. **Used sparingly** — standout CTAs only (e.g. the new "Transferir" action), never blanket UI chrome. |
| `onTertiary` | `#FFFFFF` | On `tertiary`: **4.72:1** |
| `tertiaryContainer` | `#F7DCCF` | |
| `onTertiaryContainer` | `#5C2413` | On `tertiaryContainer`: **9.37:1** |
| `error` | `#C13B3B` | Reused as `statusCritical` below |
| `onError` | `#FFFFFF` | **5.31:1** |
| `errorContainer` | `#F9D9D6` | |
| `onErrorContainer` | `#5C1616` | **10.07:1** |
| `background` (scaffold canvas) | `#FAF4EA` | Warm ivory — replaces the cool `#F9F9F7`. This is the "desk" the envelope cards sit on. |
| `surface` (cards) | `#FFFFFF` | Crisp white "paper" |
| `surfaceElevated` (dialogs/sheets/menus) | `#FFFFFF` | Same color as `surface`; distinguished by elevation/shadow, not tint — see §3 |
| `inkPrimary` | `#211A12` | Warm near-black (was pure `#0B0B0B`). On `background`: **15.72:1** |
| `inkSecondary` (`context.tokens.muted`) | `#5C5346` | On `background`: **6.91:1** |
| `inkSubtle` (`context.tokens.subtle`) | `#746A5D` | On `background`: **4.85:1** — this is the tier used today for 12px captions/dates, so it must clear 4.5:1, not just 3:1. Darkened from a first draft (`#8A8073`, 3.54:1 — would have **failed** AA at the sizes it's actually used at) to this value. |
| `border`/divider | `#211A12` at 12% alpha (`0x1F211A12`) | Decorative hairline only — see note in §3 on why this doesn't need to hit the 3:1 non-text bar |
| `statusGood` | `#2F7D3B` | On `surface`/white: **5.10:1**. Distinguished from `primary` by being brighter/more saturated so a positive number doesn't read as "just the brand color." |
| `statusWarning` | `#A8660A` | On `surface`/white: **4.59:1**. Deliberately darker/more ochre than a "bright amber" would be — bright ambers (`#D68A1D` and lighter) fail even the 3:1 non-text bar against white, so this is as light as the token can go while staying usable both as text and as a progress-bar fill. |
| `statusCritical` | `#C13B3B` | Same as `error`. **5.31:1** |

### 1.2 Dark theme

| Token | Hex | Notes |
|---|---|---|
| `primary` | `#7FCB9E` | |
| `onPrimary` | `#0D3320` | **7.24:1** |
| `primaryContainer` | `#1F4732` | |
| `onPrimaryContainer` | `#BEE8CE` | **7.79:1** |
| `secondary` | `#A9B896` | On `background`: **8.81:1** |
| `onSecondary` | `#24301C` | (same recipe as light — light fill + dark text; verified pattern, ratio ≥7:1) |
| `secondaryContainer` | `#333D26` | |
| `onSecondaryContainer` | `#DCE6C9` | **8.82:1** |
| `tertiary` | `#F0916A` | On `background`: **7.91:1** |
| `onTertiary` | `#431507` | **6.65:1** |
| `tertiaryContainer` | `#4A2417` | |
| `onTertiaryContainer` | `#F7CDBB` | **9.26:1** |
| `error` | `#E8746A` | Same as `statusCritical` below |
| `onError` | `#431010` | (recipe-consistent, ≥6:1) |
| `errorContainer` | `#4A1B1B` | |
| `onErrorContainer` | `#F7CFC9` | (recipe-consistent, ≥8:1) |
| `background` | `#16130F` | Warm near-black (brown undertone), not neutral `#0D0D0D` |
| `surface` (cards) | `#201C17` | |
| `surfaceElevated` (dialogs/sheets/menus) | `#2A241D` | |
| `inkPrimary` | `#F5F1EA` | On `background`: **16.46:1** |
| `inkSecondary` | `#C9C2B4` | On `background`: **10.45:1** |
| `inkSubtle` | `#A79C89` | On `background`: **6.84:1**, on `surface`: **6.26:1** |
| `border`/divider | `#F5F1EA` at 12% alpha (`0x1FF5F1EA`) | |
| `statusGood` | `#6FCB82` | On `background`: **9.30:1** |
| `statusWarning` | `#E0A542` | On `background`: **8.50:1** |
| `statusCritical` | `#E8746A` | On `background`: **6.30:1** |

Note on `border`: this is a decorative hairline separator (row dividers,
card outline), not a UI component that conveys meaning on its own — WCAG's
3:1 non-text contrast requirement is generally read as applying to
meaningful UI boundaries (e.g. an input's outline, a focus ring), not purely
cosmetic dividers, and hairlines at ~12% alpha are the same practice the app
already uses. If dividers ever need to hit 3:1 too, that's a one-line alpha
bump, not a redesign.

### 1.3 Categorical palette (per-caixinha color identity)

8 colors, light/dark pairs, tuned to sit in the warm "kraft paper" family
rather than the old bright primary-wheel (blue/aqua/yellow/green/violet/red/
magenta/orange, which read as generic Material defaults):

| # | Name | Light | Dark |
|---|---|---|---|
| 1 | Verde Cofre | `#2E6F4D` | `#5FAE80` |
| 2 | Terracota | `#C1502E` | `#E2896A` |
| 3 | Âmbar | `#A8660A` | `#E0A542` |
| 4 | Azul Petróleo | `#2E6B78` | `#4E96A3` |
| 5 | Ameixa | `#7A4A6B` | `#A87CA0` |
| 6 | Vinho | `#A23B3B` | `#D06868` |
| 7 | Oliva | `#7C7A3A` | `#ACA85C` |
| 8 | Argila Rosada | `#B97064` | `#D69C90` |

Usage rule (non-negotiable): these colors appear only as a small dot/swatch
or a thin left-border accent next to the caixinha's name — **never** as the
sole carrier of meaning, and never as the fill behind small body text without
separately verifying that specific pairing. The category name label (in
`inkPrimary`/`inkSecondary`, already AA-verified) is always present alongside
the color. See §4 for the exact component (reuse the existing `_LegendDot`
pattern from `dashboard_page.dart`).

8 colors can't be fully colorblind-safe on hue alone; the varied lightness
(Verde Cofre/Oliva mid-dark, Argila Rosada/Âmbar lighter) helps grayscale/CVD
users distinguish by value too, but the label is what actually carries the
meaning — that's the accessibility floor here, not perfect hue separation.

---

## 2. Typography

**Heading font: Fraunces** (Google Fonts, SIL Open Font License 1.1 — free,
bundlable, no attribution required beyond keeping the license file).
Source: https://fonts.google.com/specimen/Fraunces

**Body/UI font: Work Sans** (Google Fonts, OFL 1.1).
Source: https://fonts.google.com/specimen/Work+Sans

Why this pairing: Fraunces is a warm, soft-humanist serif built for exactly
this kind of "not-cold-fintech" tone — it's the typographic equivalent of the
"envelope caloroso" direction, and it visibly differentiates Dindin from a
generic all-sans Material app (and from its sibling app Domo). Work Sans
carries the actual reading/UI load: humanist, wide weight range, good number
legibility, distinctly warmer than Inter's clinical-geometric look without
being unusual enough to hurt legibility in dense lists of currency figures.

**Bundling note (important):** fonts MUST ship as app assets — Windows and
Web cannot be assumed to have either font installed. The app bundles
**static weight files**, not the variable-font single file, even though
Google Fonts offers Fraunces as a variable font (`wght`+`opsz`+`SOFT`+`WONK`
axes). Static files are simpler and more predictable across Web/Android/
Windows rendering paths — one less moving part for a solo maintainer, and
consistent with "keep Material 3 bones, don't take on custom complexity for
its own sake."

Files shipped in `assets/fonts/` (static weight files, sourced from
https://fonts.google.com/specimen/Fraunces and .../Work+Sans, "Get font" →
"Download all styles" — the canonical mirror is the `google/fonts` GitHub
repo under `ofl/fraunces/static/` and `ofl/worksans/static/` if a specific
file ever needs re-downloading):

- `Fraunces-Regular.ttf` (weight 400)
- `Fraunces-SemiBold.ttf` (weight 600)
- `WorkSans-Regular.ttf` (weight 400)
- `WorkSans-Medium.ttf` (weight 500)
- `WorkSans-SemiBold.ttf` (weight 600)
- `WorkSans-Bold.ttf` (weight 700)

**`pubspec.yaml` `fonts:` block** (already applied):

```yaml
flutter:
  fonts:
    - family: Fraunces
      fonts:
        - asset: assets/fonts/Fraunces-Regular.ttf
          weight: 400
        - asset: assets/fonts/Fraunces-SemiBold.ttf
          weight: 600
    - family: Work Sans
      fonts:
        - asset: assets/fonts/WorkSans-Regular.ttf
          weight: 400
        - asset: assets/fonts/WorkSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/WorkSans-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/WorkSans-Bold.ttf
          weight: 700
```

### Type scale → Flutter `TextTheme`

| Slot | Font | Weight | Size/line-height | Current use in app |
|---|---|---|---|---|
| `displayLarge` | Fraunces | 400 | 57/64 | unused today, defined for completeness |
| `displayMedium` | Fraunces | 400 | 45/52 | unused today |
| `displaySmall` | Fraunces | 500 | 36/44 | available if a future "hero balance" figure wants more punch than `headlineSmall` |
| `headlineLarge` | Fraunces | 600 | 32/40 | unused today |
| `headlineMedium` | Fraunces | 600 | 28/36 | unused today |
| `headlineSmall` | Fraunces | 600 | 24/32 | `StatTile` values, dashboard "Conta" balance — this is the slot that gives currency figures their new distinctive voice |
| `titleLarge` | Fraunces | 600 | 22/28 | page titles ("Dashboard", "Receitas", "Gastos", "Categorias", "Ajustes") |
| `titleMedium` | Work Sans | 600 | 16/24 | dropdown/section labels |
| `titleSmall` | Work Sans | 600 | 14/20 | card headers ("Caixinhas", "Receitas lançadas") |
| `bodyLarge` | Work Sans | 400 | 16/24 | |
| `bodyMedium` | Work Sans | 400 | 14/20 | default row text, form labels |
| `bodySmall` | Work Sans | 400 | 12/16 | captions/dates (`inkSubtle` tier) |
| `labelLarge` | Work Sans | 600 | 14/20 | button labels |
| `labelMedium` | Work Sans | 600 | 12/16 | `StatTile` label ("Saldo total"), chip labels |
| `labelSmall` | Work Sans | 600 | 11/16 | |

The `w600` weight is baked directly into the `titleLarge`/`titleSmall` theme
definitions (`_textTheme` in `lib/theme/theme.dart`). Some call sites (e.g.
`categorias_page.dart`'s page title) still add a redundant
`.copyWith(fontWeight: FontWeight.w600)` on top — harmless (same value twice),
a small cleanup left for whenever that widget is touched next, not urgent.

**Currency figures:** `FontFeature.tabularFigures()` is applied to amounts
rendered inside a list (row amounts in Receitas/Gastos/Categorias, budget
captions — see `dashboard_page.dart`, `receitas_page.dart`,
`gastos_page.dart`) so decimal points/digits align vertically down a column.
Not applied to the single hero `StatTile` values (nothing to align against).

---

## 3. Shape, spacing, elevation

- **Card radius:** 16dp (up from 12dp) — rounder, more "pouch/envelope",
  still a trivial `RoundedRectangleBorder` change.
- **Input radius:** 12dp (up from 8dp).
- **Button radius:** unchanged — Material 3's default `FilledButton`/
  `OutlinedButton`/`TextButton` shape is already a full stadium/pill. Don't
  override it; it already matches the "tactile, soft" direction for free.
- **Spacing scale:** `4 / 8 / 12 / 16 / 20 / 24 / 32 / 40` px. This is
  already loosely what the app uses (4, 8, 10, 12, 16, 20, 24 appear
  throughout); formalizing it just means preferring these exact steps going
  forward (e.g. the current `10` in row `padding: EdgeInsets.symmetric(
  vertical: 10)` could become `12` next time that widget is touched — not
  urgent enough to justify a drive-by change today).
- **Elevation — decision:** move from flat elevation-0-plus-hairline to
  **elevation 1 + hairline border, both at once**, with
  `surfaceTintColor: Colors.transparent` explicitly set on `CardThemeData`
  and on dialog/menu/bottom-sheet themes.
  - *Why both, not one or the other:* elevation 0 is what makes the current
    app look flat/generic; a pure soft-shadow-with-no-border can look
    "floaty" and lose crispness on desktop/web where cards sit directly on a
    similarly-toned background. A hairline border + a small (elevation 1)
    shadow together read as "a card resting on the desk" — which is the
    literal "envelope caloroso" metaphor — while staying a native Material
    `Card` (no custom `BoxShadow`/`DecoratedBox` hand-rolling to maintain).
  - *Why `surfaceTintColor: Colors.transparent`:* Material 3's default
    behavior tints elevated surfaces with the color scheme's primary as
    elevation increases. Since this app now has a fully hand-tuned, exact
    surface palette (not a single `ColorScheme.fromSeed` derivation), that
    auto-tint would quietly shift the warm ivory/paper tones toward green at
    higher elevations — undermining the exact tokens in §1. Turning it off
    keeps `surface`/`surfaceElevated` exactly as specified regardless of
    elevation.
  - Dialogs/bottom sheets/menus: elevation 3, same `surfaceTintColor:
    transparent` override, background = `surfaceElevated`.
- **`ColorScheme` construction:** build it explicitly via the `ColorScheme()`
  constructor from the tokens in §1, not `ColorScheme.fromSeed(...)` as
  today — a seed only lets you set one color and derives the rest, which is
  exactly how the app ended up looking like a generic blue Material app in
  the first place. Map: `primary/onPrimary/primaryContainer/
  onPrimaryContainer`, `secondary/.../secondaryContainer/...`,
  `tertiary/.../tertiaryContainer/...`, `error/.../errorContainer/...`,
  `surface/onSurface` (M3 folded the old `background` role into `surface`),
  `outline` = `border` token (opaque core color, not the translucent
  divider — pick a solid mid-tone, e.g. light `#8A7F6E` / dark `#6B6455`, for
  the handful of places `ColorScheme.outline` is used for real component
  outlines like default `OutlinedButton` borders), `shadow` = `inkPrimary`.

---

## 4. Component styling notes

- **`AppCard`** (`widgets/app_card.dart`): `Card(elevation: 1,
  surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16), side: BorderSide(color:
  context.tokens.border)))`. Padding unchanged (20).
- **Text inputs:** `filled: true`, `fillColor` = `background` token (this
  keeps today's subtle "recessed slot" look — the field reads slightly
  sunken relative to the white card it sits in, like a slot cut into an
  envelope), `borderRadius: 12`, hairline border in `border` token,
  **focused** border 2dp in `primary`.
- **`FilledButton`:** `primary`/`onPrimary`, default pill shape — no
  override needed.
- **`FilledButton.tonal`:** Material 3's default already resolves this to
  `secondaryContainer`/`onSecondaryContainer` once `ColorScheme` is built
  correctly (§3) — no override needed. This is what today's "Alocar" button
  uses; it'll pick up the new sage tone automatically.
- **A new standout action** (the "Transferir" entry point, §5): give it an
  explicit `tertiary`-colored `FilledButton` (or `FilledButton.tonal` with
  `style: FilledButton.styleFrom(backgroundColor: tertiaryContainer,
  foregroundColor: onTertiaryContainer)`) so the coral accent shows up
  exactly where a genuinely new, distinct action type needs to stand out —
  and nowhere else. Keeping coral rare is what makes it read as an accent
  instead of "the app is now orange."
- **`OutlinedButton`/`TextButton`:** default M3 behavior (primary-colored
  text/border) — no override.
- **`NavigationRail`/`NavigationBar`:** no custom indicator color override
  needed — Material 3's default selected-indicator pill already resolves to
  `secondaryContainer`, which becomes the sage tone. Leave background as
  `surface` (a subtly distinct "spine" panel next to the ivory canvas) rather
  than `background`, so the rail reads as a fixed piece of chrome, not part
  of the scrolling content area. `VerticalDivider`/bottom `Divider` in
  `border` token, unchanged from today's pattern.
- **Per-caixinha color identity:** reuse the existing `_LegendDot` pattern
  already in `dashboard_page.dart` (a small 10dp filled circle + label) as
  the canonical "caixinha color" component — extract it to a shared
  `widgets/` file (e.g. `CaixinhaColorDot`) so it's usable from the Dashboard
  caixinha rows, the Categorias list, and the new transfer-dialog dropdowns
  (origem/destino items), instead of inventing a second visual language for
  the same concept. Placement: immediately before the caixinha/category
  name, `6px` gap, matching the existing legend spacing.
- **Progress bar (budget vs. limit, §5):** `LinearProgressIndicator`
  (stock M3 widget — check the Flutter SDK version in use for native
  `borderRadius` support on it; if unavailable, wrap in `ClipRRect(
  borderRadius: BorderRadius.circular(4))`), height ~6–8dp, track color =
  `border` token, fill color by ratio: `<80%` → `secondary` (neutral/
  informative, not "alarming"), `80–100%` → `statusWarning`, `>100%` →
  `statusCritical` (bar visually capped at 100% width — never overflow the
  track — with the overage stated as text, see §5).

- **Status badges** (e.g. "quase no limite" / "acima do limite" pills next to
  the budget caption, §5): use the **solid** status color as the fill
  with white text — `statusWarning`/`statusCritical`/`statusGood` against
  white are the pairs already verified in §1 (4.59/5.31/5.10:1). **Do not**
  use a tinted container (e.g. `tertiaryContainer`) as the badge background
  with the status color as the text color: that combination fails AA at the
  badge's actual 11px size (`statusWarning` text on `tertiaryContainer` is
  3.52:1, `statusCritical` on it is 4.07:1, `statusGood` on
  `primaryContainer` is 4.08:1 — all below the 4.5:1 required at that size).

**Existing logo** (`assets/logo.svg`): a piggy-bank/coin illustration in
`#1BAF7A` (green) + `#1A6B4E` (dark green) + `#FFC800` (gold) + `#A4830C`
(dark gold). This sits fine next to the new palette — it's already in the
same green/gold hue family as `primary`/`Âmbar`, just a brighter/more
saturated green than the new `primary` (`#2E6F4D`). Nudging the logo's green
to match `primary` exactly is a cosmetic, non-blocking follow-up — they
currently read as "related but not identical" rather than "the same color."

---

## 5. Feature UX patterns

The features that shipped alongside this identity (edit transaction, monthly
budget per caixinha, transfer between caixinhas, date-range filter on
Receitas/Gastos, and later the guardar/gastar caixinha purpose) all reuse the
same interaction vocabulary rather than inventing a new one per feature —
consistency beats novelty here. The patterns worth knowing as identity/UX
rules (not implementation detail — that lives in the code, which is the
current source of truth for exact behavior):

- **One adaptive breakpoint (720px)** decides dialog-vs-bottom-sheet
  (`showAdaptiveFormSheet`), rail-vs-bottom-nav (`AppShell`), and
  side-by-side-vs-stacked form fields (`ResponsiveFormRow`) everywhere in the
  app — a single rule a user learns once, not a per-feature judgment call.
- **Tap-a-row-to-edit**, with delete demoted to a small trailing
  `IconButton` + confirm dialog, so the row's primary tap target is never
  destructive.
- **Progress bars communicate two opposite meanings by design, not just by
  color:** `CaixinhaBudgetBar` (spend caixinhas) is a *consumption* meter —
  filling up is a warning (`secondary` → `statusWarning` → `statusCritical`
  past 100%, capped at 100% width, with the overage stated as text).
  `CaixinhaGoalBar` (save caixinhas with a goal) is the inverse — filling up
  is success (`primary` → `statusGood` on reaching the goal). Never rely on
  fill color alone; the caption always states the numbers too.
- **Status badges use the solid status color as the fill with white text**,
  never a tinted container as the background with the status color as text
  — that combination was checked and measured below AA at the badge's actual
  size (`statusWarning` on `tertiaryContainer`: 3.52:1; `statusCritical`:
  4.07:1; `statusGood` on `primaryContainer`: 4.08:1 — all fail 4.5:1).
- **A caixinha's purpose (`kind`) changes which meter it gets, not its
  underlying money model** — see `docs/ARQUITETURA.md` for how `spend`/`save`
  map to `monthlyBudget`/`goalAmount`.

The exact per-screen entry points, dialogs, and empty/loading/error states
are implemented in `lib/features/**` and `lib/widgets/edit_transaction_sheet.dart`,
`caixinha_budget_bar.dart`, `adaptive_form_sheet.dart`, `responsive_form_row.dart`
— read those directly for current behavior rather than a spec that can drift
from what's shipped.
