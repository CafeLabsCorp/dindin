# Dindin — Identity refactor & v1 feature UX spec ("Envelope caloroso")

Status: approved direction, ready for implementation by the mobile specialist.
Scope owner: UX/UI design. Implementation owner: mobile (Flutter) specialist.
Data model owner: backend specialist (flagged inline wherever this doc needs a
new field/collection).

This replaces the generic Material-seed-blue + Roboto identity (ported 1:1
from the old Next.js app) with a warm, tactile "envelope" identity, and
specifies the UX for the four v1 features: edit transaction, monthly
budget/limit per caixinha, transfer between caixinhas, and date-range
filtering on the transaction lists.

All hex values below were checked against WCAG 2.1 contrast math by hand
(relative luminance → contrast ratio). Ratios are stated next to every
foreground/background pair used for real text so the mobile specialist can
trust them without re-deriving. AA requires ≥4.5:1 for body text, ≥3:1 for
large text (≥24px, or ≥19px bold) and for purely graphical/non-text objects
(e.g. a progress bar fill against its track).

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
already uses. Flagging this explicitly rather than silently skipping it:
if the mobile specialist disagrees and wants dividers to hit 3:1 too, that's
a one-line alpha bump, not a design fight.

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
Web cannot be assumed to have either font installed. I recommend bundling
**static weight files**, not the variable-font single file, even though
Google Fonts offers Fraunces as a variable font (`wght`+`opsz`+`SOFT`+`WONK`
axes). Static files are simpler and more predictable across Web/Android/
Windows rendering paths — one less moving part for a solo maintainer, and
consistent with "keep Material 3 bones, don't take on custom complexity for
its own sake."

Exact files needed (I could not fetch these binaries myself — see note
below — so the mobile specialist should download and add them):

- `Fraunces-Regular.ttf` (weight 400)
- `Fraunces-SemiBold.ttf` (weight 600)
- `WorkSans-Regular.ttf` (weight 400)
- `WorkSans-Medium.ttf` (weight 500)
- `WorkSans-SemiBold.ttf` (weight 600)
- `WorkSans-Bold.ttf` (weight 700)

Source: on https://fonts.google.com/specimen/Fraunces and
.../Work+Sans, use "Get font" → "Download all styles", which gives a zip
with a `static/` subfolder containing individually-named weight files (for
Fraunces, static files are nested by optical size — pick the ones named
without an optical-size-family suffix mismatch, i.e. the default/`72pt`-ish
regular-width regular-optical-size files; Work Sans's static files are flat,
one file per weight, no nesting). If in doubt, the canonical mirror is the
`google/fonts` GitHub repo under `ofl/fraunces/static/` and
`ofl/worksans/static/`.

Target location: `/home/felip/projetos/dindin/assets/fonts/` (directory
already created by me, currently empty — see "What I actually did" below).

**`pubspec.yaml` `fonts:` block to add** (mobile specialist applies this —
I did not edit `pubspec.yaml` per my file-ownership boundary):

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

Bake the `w600` weight directly into the `titleLarge`/`titleSmall` theme
definitions instead of requiring every screen to `.copyWith(fontWeight:
FontWeight.w600)` as they do today (e.g. `dashboard_page.dart:34`,
`categorias_page.dart:70`) — small cleanup, removes repeated boilerplate,
purely additive/non-breaking since existing `.copyWith()` calls will just be
redundant, not wrong.

**Currency figures:** apply `FontFeature.tabularFigures()` to any `TextStyle`
rendering an amount inside a list (row amounts in Receitas/Gastos/Categorias,
budget captions) so decimal points/digits align vertically down a column.
Not needed for the single hero `StatTile` values (nothing to align against).

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
- **A new standout action** (the "Transferir" entry point, §5.3): give it an
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
- **Progress bar (budget vs. limit, §5.2):** `LinearProgressIndicator`
  (stock M3 widget — check the Flutter SDK version in use for native
  `borderRadius` support on it; if unavailable, wrap in `ClipRRect(
  borderRadius: BorderRadius.circular(4))`), height ~6–8dp, track color =
  `border` token, fill color by ratio: `<80%` → `secondary` (neutral/
  informative, not "alarming"), `80–100%` → `statusWarning`, `>100%` →
  `statusCritical` (bar visually capped at 100% width — never overflow the
  track — with the overage stated as text, see §5.2).

- **Status badges** (e.g. "quase no limite" / "acima do limite" pills next to
  the budget caption in §5.2): use the **solid** status color as the fill
  with white text — `statusWarning`/`statusCritical`/`statusGood` against
  white are the pairs already verified in §1 (4.59/5.31/5.10:1). **Do not**
  use a tinted container (e.g. `tertiaryContainer`) as the badge background
  with the status color as the text color — I built exactly that in the
  first draft of the mockup below and it fails AA at the badge's actual
  11px size (checked: `statusWarning` text on `tertiaryContainer` is
  3.52:1, `statusCritical` on it is 4.07:1, `statusGood` on
  `primaryContainer` is 4.08:1 — all below the 4.5:1 required at that
  size). Fixed in the final mockup; flagging so the same mistake isn't
  repeated when this gets implemented for real.

**Existing logo** (`assets/logo.svg`): a piggy-bank/coin illustration in
`#1BAF7A` (green) + `#1A6B4E` (dark green) + `#FFC800` (gold) + `#A4830C`
(dark gold). This sits fine next to the new palette — it's already in the
same green/gold hue family as `primary`/`Âmbar`, just a brighter/more
saturated green than the new `primary` (`#2E6F4D`). Not asking for a logo
redesign in this pass; flagging as a nice-to-have for a later pass to bring
the logo's green in line with the new `primary` exactly, since right now
they'll read as "related but not identical" rather than "the same color."

---

## 5. Feature UX — screen-level notes for the 4 new features

All four reuse the app's existing interaction vocabulary (the same
`AppCard`/`ResponsiveFormRow`/row-with-divider/`EmptyState`/inline-`_error`
patterns already in `receitas_page.dart`, `gastos_page.dart`,
`categorias_page.dart`, `dashboard_page.dart`) rather than introducing new
ones — consistency with what's already shipped beats novelty here.

### 5.1 Edit a transaction (income / expense / allocation)

**Today:** list rows (`_IncomeRow` and the equivalent inline expense/
category rows) only have a trailing "Remover" text button; there's no way to
edit.

**Entry point:** make the whole row tappable (`InkWell` wrapping the row's
content) → opens an edit sheet/dialog. Change the current "Remover" text
button to a small trailing `IconButton(icon: Icons.delete_outline)` with a
tooltip, so there's room for the tap target and the row doesn't get more
cluttered. This keeps destructive action gated behind a deliberate, separate
tap (the small delete icon, then the existing confirm dialog) — tapping the
row itself only ever opens edit, never deletes. Matches "error prevention
over error messages" and "recognition over recall" (tap-a-row-to-edit is a
near-universal list convention).

**Edit UI — reuses the existing create forms:**
- **Wide layout** (≥720px, the same breakpoint `app_shell.dart` already
  uses): a `Dialog`/`AlertDialog` containing the same fields as the relevant
  create form (Data/Valor/Origem-or-Categoria/Descrição for income/expense;
  Categoria/Valor/Data for allocation), pre-filled, with "Cancelar"/"Salvar".
- **Narrow layout:** `showModalBottomSheet(isScrollControlled: true)` with a
  drag handle, the same fields stacked, "Salvar" pinned at the bottom —
  bottom sheets are the mobile-native affordance for a short edit form,
  whereas dialogs are the desktop/web-native one; branching the same way
  `AppShell` already branches keeps one consistent rule for "wide vs.
  narrow" across the whole app instead of a second one just for this
  feature.
- A single shared `showEditTransactionSheet(context, {wide})`-style helper
  can host all three transaction-type variants, so this is one component to
  build, not three.

**States:**
- *Loading:* disable "Salvar" + inline spinner, same `_submitting` pattern
  already used everywhere in this codebase.
- *Validation error:* inline red text under the fields, same `_error`
  pattern. If the edited amount would exceed the available balance (the
  same server-side guard `createExpense`/`createAllocation` already enforce
  on create), the same `StateError` message surfaces — I'd flag mapping
  `e.toString()` to a friendlier Portuguese string as a small pre-existing
  rough edge worth fixing while this code is being touched anyway, not a
  new problem this feature introduces.
- *Concurrent deletion edge case* (row edited on one device while deleted on
  another — relevant since this is a multi-platform personal app): low
  priority for v1, but worth a one-line inline banner ("Esse lançamento não
  existe mais") + auto-close if it comes up cheaply; not blocking.

### 5.2 Monthly budget/limit per caixinha

**Model dependency (flag, not my call):** `Category` currently has only
`name`/`recurring`/`createdAt` (`lib/models/category.dart`) — this feature
needs a new optional field, e.g. `monthlyLimit: double?`. I did not touch
`lib/models/**`; this is for the backend/mobile specialists to add.
Aggregation is already halfway there: `MonthSummary.expenseByCategory`
(`aggregation_service.dart`) already computes "spent this month per
category" — the budget feature is "spent this month" (existing) vs.
"monthlyLimit" (new field), nothing else new to compute.

**Where it's set:**
- On the existing category-creation `AppCard` form (`categorias_page.dart`):
  add one more optional field, "Limite mensal (opcional)", next to the name
  field and the "Recorrente" checkbox.
- On an **existing** category: reuse the same tap-row-to-edit sheet from
  §5.1 (Nome / Recorrente / Limite mensal) — one interaction pattern for
  "change anything about a category," not a second bespoke UI just for
  limits.

**Visualization — same small component in two places:**
- **Categorias page**, under each row's existing name/recurring/date line: a
  slim `LinearProgressIndicator` (see §4) + caption "R$ X de R$ Y este mês".
- **Dashboard "Caixinhas" card**, under each caixinha row: the identical bar
  + caption, so a user learns the pattern once and recognizes it in both
  places.
- Extract as one shared `CaixinhaBudgetBar` widget used from both screens.

**States:**
- *No limit set (the empty state for this feature):* no bar at all — just
  today's plain spent-total line. A caixinha simply looks like it does
  today until the user opts into a limit.
- *Limit set, nothing spent yet:* bar shown at 0% (confirms to the user the
  limit "took" — visibility of system status).
- *Under 80%:* `secondary`-colored fill (neutral/informative).
- *80–100%:* `statusWarning` fill.
- *Over 100%:* `statusCritical` fill, capped at 100% width, with an explicit
  "+R$ Z acima do limite" caption — never let the bar overflow its track or
  rely on color alone to say "you're over."

### 5.3 Transfer between caixinhas

**Entry point:** mirror the existing "Alocar" button pattern exactly.
Dashboard's "Caixinhas" `AppCard` header gets a second button, "Transferir"
(tertiary-styled per §4, to visually rank it as a distinct action type, not
a variant of "Alocar"), next to/near the existing `FilledButton.tonal`
"Alocar". Same disabled-when-impossible guard the existing button already
has (`onPressed: categories.isEmpty || summary.accountBalance <= 0 ? null :
...`) — here: disabled when no caixinha has a positive balance to transfer
*from*. Showing a working button that opens onto an empty/broken form is a
worse experience than the button simply not being tappable yet.

**Flow (new dialog, same shape as `_AllocateDialog` in
`dashboard_page.dart`):**
1. **Origem** — dropdown of caixinhas with balance > 0 (each item using the
   shared `CaixinhaColorDot`, §4).
2. **Destino** — dropdown of all *other* caixinhas (excludes whatever's
   currently selected as Origem, updates live if Origem changes) — this
   structurally prevents "transfer to itself" rather than validating it
   after the fact.
3. **Valor** — capped by Origem's available balance, identical
   balance-capped-amount pattern as `_AllocateDialog`.
4. "Cancelar"/"Confirmar", identical `_submitting`/`_error` pattern.

**Data model dependency (flag, not my call):** needs either a new
`transfers` collection (`{sourceCategoryId, targetCategoryId, amount,
date}`, net-zero against the account balance — analogous to how
`Allocation` moves account→category, this moves category→category) or two
linked `Allocation`-like entries. Backend/mobile specialists' call; flagging
the dependency, not deciding it.

**States:** empty-eligible-origem state handled by the disabled button
(above, not an in-dialog empty state); validation errors identical to
`_AllocateDialog`'s `_error` pattern (amount > 0, amount ≤ origem balance).

### 5.4 Search / filter by date on Receitas and Gastos lists

**Controls:** a filter row above each list's existing "X lançados" `AppCard`
header — two date fields, "De" / "Até", built with the *exact* existing
`InkWell` + `showDatePicker` + `InputDecorator` pattern already used for the
single "Data" field in both create forms (so this is a visually and
behaviorally familiar control, not a new one), wrapped in the existing
`ResponsiveFormRow` widget so wide/narrow behavior is inherited for free. A
"Limpar filtro" `TextButton` sits at the end of the row, **only rendered
when a filter is active** — its presence/absence is itself the "is a filter
currently applied?" status indicator (visibility of system status).

**Default state:** no filter = today's unfiltered full list, unchanged.
Purely additive.

**Filtered-empty state:** distinct from today's single generic `EmptyState`
("Nenhuma receita lançada ainda.") — needs its own message, e.g. "Nenhuma
receita entre {de} e {até}.", **with a "Limpar filtro" action inside the
empty state itself**, not only in the filter row above it — a user who
lands on a filtered-empty result shouldn't have to scroll back up to find
the way out. Recommend giving `EmptyState` (`widgets/app_card.dart`) an
optional `action: Widget?` slot to support this without a second widget.

**Scope note (flag, not a unilateral cut):** the task names this
"Search / filter by date" — I've read that as one mechanism (filter by date
range), not two separate features (date filter + separate free-text
search). Given the app's realistic personal-scale list lengths and that the
searchable fields are thin (amount, date, source/category, optional
description), full-text search is meaningfully more surface (matching
logic, likely a new dependency for anything beyond a naive substring scan)
for a feature this task otherwise scopes as "date filter." I'd suggest
shipping date-range filtering now and treating free-text search as a
v1.1 candidate if real usage shows list length becomes a problem — but
this is a scope call for the orchestrator/owner to confirm, not something
I'm deciding unilaterally by narrowing it here.

---

## What I actually did vs. what's left for mobile

- **Wrote this spec** at `/home/felip/projetos/dindin/docs/DESIGN.md`.
- **Created** `/home/felip/projetos/dindin/assets/fonts/` (empty) — I do not
  have network access in this environment (confirmed: `curl`/any outbound
  Bash network call is denied by the permission system here, and `WebFetch`
  can summarize a page but can't reliably pass through exact binary font
  bytes). Rather than fabricate font files or guess at exact CDN URLs I
  can't verify, I've left the directory empty and listed the exact 6 files
  + source + `pubspec.yaml` block above for the mobile specialist to add.
- **Did not touch** `lib/**`, `pubspec.yaml`, or any Firestore/data-model
  file, per the file-ownership boundary for this task.
- **Produced an interactive HTML mockup** (see final response) covering
  Dashboard, Categorias with budget bars, the Transfer dialog, the Edit
  sheet, and the date-filtered Gastos list, in both light and dark, to make
  these tokens/decisions concretely checkable before implementation.

## Open questions for the orchestrator/owner (not invented answers)

1. **Transfer data model** (§5.3): new `transfers` collection vs. two linked
   `Allocation` entries — this changes `aggregation_service.dart` and
   Firestore rules, so it needs a backend-specialist decision, not a design
   one.
2. **`Category.monthlyLimit` field** (§5.2): confirms as a new nullable
   `double` on the model — flagging so it's an explicit decision, not an
   assumption baked in silently by whoever implements it first.
3. **Search/filter scope** (§5.4): confirm date-range-only is the intended
   v1 reading of "Search / filter by date," per the scope note above.
4. **Logo color follow-up:** cosmetic, non-blocking — whether to eventually
   nudge the logo's green to match the new `primary` exactly is a "when we
   get to it" call, not something needed for this phase.
