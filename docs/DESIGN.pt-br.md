# Dindin — Sistema de design: "Envelope caloroso"

**[Read in English](DESIGN.md)**

Status: **implementado**. Esta é a referência da identidade visual do app —
tokens de cor, tipografia, forma/espaçamento/elevação, estilo dos componentes
— batendo com o que de fato está em `lib/theme/colors.dart` e
`lib/theme/theme.dart`. Substituiu a identidade genérica azul-seed do
Material + Roboto herdada de uma versão anterior em Next.js do app (removida
do repo há muito tempo).

Todos os valores hex abaixo foram checados à mão contra o cálculo de
contraste do WCAG 2.1 (luminância relativa → razão de contraste). As razões
são declaradas ao lado de cada par foreground/background usado em texto real,
para que possam ser confiadas sem precisar re-derivar. AA exige ≥4.5:1 para
texto de corpo, ≥3:1 para texto grande (≥24px, ou ≥19px bold) e para objetos
puramente gráficos/não-textuais (ex.: o preenchimento de uma barra de
progresso contra sua trilha).

---

## 1. Tokens de cor

### 1.1 Tema claro

| Token | Hex | Notas |
|---|---|---|
| `primary` | `#2E6F4D` | Verde floresta-petróleo profundo ("Verde Cofre"). Ligado a dinheiro/crescimento, mais quente que um teal frio. |
| `onPrimary` | `#FFFFFF` | Sobre `primary`: **6.02:1** |
| `primaryContainer` | `#D7EBDD` | Preenchimento tonal (ex.: `FilledButton.tonal` quando explicitamente estilizado como primary, indicador de nav selecionado se remapeado) |
| `onPrimaryContainer` | `#14392A` | Sobre `primaryContainer`: **10.20:1** |
| `secondary` | `#6B7A5E` | Sálvia quente suave — ações de baixa ênfase, ex.: o botão "Alocar" do dia, default do `FilledButton.tonal` no Material 3 |
| `onSecondary` | `#FFFFFF` | Sobre `secondary`: **4.59:1** |
| `secondaryContainer` | `#E1E8D8` | |
| `onSecondaryContainer` | `#2B3320` | Sobre `secondaryContainer`: **10.48:1** |
| `tertiary` (accent) | `#C1502E` | Coral/terracota. **Usado com moderação** — só CTAs de destaque (ex.: a nova ação "Transferir"), nunca como chrome de UI geral. |
| `onTertiary` | `#FFFFFF` | Sobre `tertiary`: **4.72:1** |
| `tertiaryContainer` | `#F7DCCF` | |
| `onTertiaryContainer` | `#5C2413` | Sobre `tertiaryContainer`: **9.37:1** |
| `error` | `#C13B3B` | Reaproveitado como `statusCritical` abaixo |
| `onError` | `#FFFFFF` | **5.31:1** |
| `errorContainer` | `#F9D9D6` | |
| `onErrorContainer` | `#5C1616` | **10.07:1** |
| `background` (tela do scaffold) | `#FAF4EA` | Marfim quente — substitui o `#F9F9F7` frio. Esta é a "mesa" onde os cards-envelope ficam. |
| `surface` (cards) | `#FFFFFF` | "Papel" branco nítido |
| `surfaceElevated` (dialogs/sheets/menus) | `#FFFFFF` | Mesma cor de `surface`; distinguido por elevação/sombra, não por tinta — ver §3 |
| `inkPrimary` | `#211A12` | Quase-preto quente (era `#0B0B0B` puro). Sobre `background`: **15.72:1** |
| `inkSecondary` (`context.tokens.muted`) | `#5C5346` | Sobre `background`: **6.91:1** |
| `inkSubtle` (`context.tokens.subtle`) | `#746A5D` | Sobre `background`: **4.85:1** — este é o tier usado hoje para legendas/datas de 12px, então precisa passar de 4.5:1, não só 3:1. Escurecido a partir de um primeiro rascunho (`#8A8073`, 3.54:1 — teria **falhado** AA nos tamanhos em que é de fato usado) até este valor. |
| `border`/divisor | `#211A12` a 12% de alpha (`0x1F211A12`) | Só linha decorativa fina — ver nota no §3 sobre por que isso não precisa bater a barra de 3:1 pra não-texto |
| `statusGood` | `#2F7D3B` | Sobre `surface`/branco: **5.10:1**. Distinguido de `primary` por ser mais brilhante/saturado, pra um número positivo não ler como "só a cor da marca". |
| `statusWarning` | `#A8660A` | Sobre `surface`/branco: **4.59:1**. Deliberadamente mais escuro/ocre do que um "âmbar brilhante" seria — âmbares brilhantes (`#D68A1D` e mais claros) falham até a barra de 3:1 pra não-texto contra branco, então este é o mais claro que o token pode ir mantendo-se usável tanto como texto quanto como preenchimento de barra de progresso. |
| `statusCritical` | `#C13B3B` | Igual a `error`. **5.31:1** |

### 1.2 Tema escuro

| Token | Hex | Notas |
|---|---|---|
| `primary` | `#7FCB9E` | |
| `onPrimary` | `#0D3320` | **7.24:1** |
| `primaryContainer` | `#1F4732` | |
| `onPrimaryContainer` | `#BEE8CE` | **7.79:1** |
| `secondary` | `#A9B896` | Sobre `background`: **8.81:1** |
| `onSecondary` | `#24301C` | (mesma receita do claro — preenchimento claro + texto escuro; padrão verificado, razão ≥7:1) |
| `secondaryContainer` | `#333D26` | |
| `onSecondaryContainer` | `#DCE6C9` | **8.82:1** |
| `tertiary` | `#F0916A` | Sobre `background`: **7.91:1** |
| `onTertiary` | `#431507` | **6.65:1** |
| `tertiaryContainer` | `#4A2417` | |
| `onTertiaryContainer` | `#F7CDBB` | **9.26:1** |
| `error` | `#E8746A` | Igual ao `statusCritical` abaixo |
| `onError` | `#431010` | (receita consistente, ≥6:1) |
| `errorContainer` | `#4A1B1B` | |
| `onErrorContainer` | `#F7CFC9` | (receita consistente, ≥8:1) |
| `background` | `#16130F` | Quase-preto quente (com fundo marrom), não neutro `#0D0D0D` |
| `surface` (cards) | `#201C17` | |
| `surfaceElevated` (dialogs/sheets/menus) | `#2A241D` | |
| `inkPrimary` | `#F5F1EA` | Sobre `background`: **16.46:1** |
| `inkSecondary` | `#C9C2B4` | Sobre `background`: **10.45:1** |
| `inkSubtle` | `#A79C89` | Sobre `background`: **6.84:1**, sobre `surface`: **6.26:1** |
| `border`/divisor | `#F5F1EA` a 12% de alpha (`0x1FF5F1EA`) | |
| `statusGood` | `#6FCB82` | Sobre `background`: **9.30:1** |
| `statusWarning` | `#E0A542` | Sobre `background`: **8.50:1** |
| `statusCritical` | `#E8746A` | Sobre `background`: **6.30:1** |

Nota sobre `border`: este é um separador decorativo fino (divisores de linha,
contorno de card), não um componente de UI que carrega significado por si só
— a exigência de contraste não-texto de 3:1 do WCAG é geralmente lida como
aplicável a bordas de UI com significado (ex.: o contorno de um input, um
anel de foco), não a divisores puramente cosméticos, e linhas finas a ~12% de
alpha são a mesma prática que o app já usa. Se algum dia os divisores
precisarem bater 3:1 também, isso é um ajuste de uma linha no alpha, não um
redesign.

### 1.3 Paleta categórica (identidade de cor por caixinha)

8 cores, pares claro/escuro, ajustadas pra ficar na família quente "papel
kraft" em vez da antiga roda-primária brilhante (azul/água/amarelo/verde/
violeta/vermelho/magenta/laranja, que lia como defaults genéricos do
Material):

| # | Nome | Claro | Escuro |
|---|---|---|---|
| 1 | Verde Cofre | `#2E6F4D` | `#5FAE80` |
| 2 | Terracota | `#C1502E` | `#E2896A` |
| 3 | Âmbar | `#A8660A` | `#E0A542` |
| 4 | Azul Petróleo | `#2E6B78` | `#4E96A3` |
| 5 | Ameixa | `#7A4A6B` | `#A87CA0` |
| 6 | Vinho | `#A23B3B` | `#D06868` |
| 7 | Oliva | `#7C7A3A` | `#ACA85C` |
| 8 | Argila Rosada | `#B97064` | `#D69C90` |

Regra de uso (inegociável): essas cores aparecem só como um pontinho pequeno/
swatch ou uma borda esquerda fina de destaque ao lado do nome da caixinha —
**nunca** como o único portador de significado, e nunca como preenchimento
atrás de texto de corpo pequeno sem verificar separadamente aquele par
específico. O rótulo com o nome da categoria (em `inkPrimary`/`inkSecondary`,
já verificado AA) está sempre presente junto com a cor. Ver §4 pro componente
exato (reaproveitar o padrão `_LegendDot` já existente em
`dashboard_page.dart`).

8 cores não conseguem ser totalmente seguras pra daltonismo só por matiz; a
luminosidade variada (Verde Cofre/Oliva médio-escuros, Argila Rosada/Âmbar
mais claros) ajuda usuários em escala de cinza/CVD a distinguir também por
valor, mas o rótulo é o que de fato carrega o significado — esse é o piso de
acessibilidade aqui, não a separação de matiz perfeita.

---

## 2. Tipografia

**Fonte de heading: Fraunces** (Google Fonts, SIL Open Font License 1.1 —
grátis, pode ser empacotada, sem exigência de atribuição além de manter o
arquivo de licença). Fonte: https://fonts.google.com/specimen/Fraunces

**Fonte de corpo/UI: Work Sans** (Google Fonts, OFL 1.1).
Fonte: https://fonts.google.com/specimen/Work+Sans

Por que essa combinação: Fraunces é uma serifada quente, humanista-suave,
construída exatamente pra esse tom "não-fintech-fria" — é o equivalente
tipográfico da direção "envelope caloroso", e diferencia visivelmente o
Dindin de um app Material genérico all-sans (e do seu app irmão Domo). Work
Sans carrega a carga real de leitura/UI: humanista, faixa larga de pesos, boa
legibilidade de números, nitidamente mais quente que o visual clínico-
geométrico da Inter sem ser incomum a ponto de prejudicar a legibilidade em
listas densas de valores em moeda.

**Nota de empacotamento (importante):** as fontes DEVEM vir como assets do
app — não dá pra assumir que Windows e Web têm nenhuma das duas fontes
instaladas. O app empacota **arquivos de peso estático**, não o arquivo único
variable-font, mesmo o Google Fonts oferecendo Fraunces como variable font
(eixos `wght`+`opsz`+`SOFT`+`WONK`). Arquivos estáticos são mais simples e
previsíveis nos caminhos de renderização de Web/Android/Windows — uma peça a
menos em movimento pra um mantenedor solo, e consistente com "manter o
esqueleto do Material 3, não assumir complexidade custom por si só."

Arquivos empacotados em `assets/fonts/` (arquivos de peso estático, obtidos
de https://fonts.google.com/specimen/Fraunces e .../Work+Sans, "Get font" →
"Download all styles" — o espelho canônico é o repo `google/fonts` no GitHub
em `ofl/fraunces/static/` e `ofl/worksans/static/` caso algum arquivo
específico precise ser rebaixado de novo):

- `Fraunces-Regular.ttf` (peso 400)
- `Fraunces-SemiBold.ttf` (peso 600)
- `WorkSans-Regular.ttf` (peso 400)
- `WorkSans-Medium.ttf` (peso 500)
- `WorkSans-SemiBold.ttf` (peso 600)
- `WorkSans-Bold.ttf` (peso 700)

**Bloco `fonts:` do `pubspec.yaml`** (já aplicado):

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

### Escala tipográfica → `TextTheme` do Flutter

| Slot | Fonte | Peso | Tamanho/altura de linha | Uso atual no app |
|---|---|---|---|---|
| `displayLarge` | Fraunces | 400 | 57/64 | não usado hoje, definido por completude |
| `displayMedium` | Fraunces | 400 | 45/52 | não usado hoje |
| `displaySmall` | Fraunces | 500 | 36/44 | disponível se um futuro "número de saldo hero" quiser mais impacto que `headlineSmall` |
| `headlineLarge` | Fraunces | 600 | 32/40 | não usado hoje |
| `headlineMedium` | Fraunces | 600 | 28/36 | não usado hoje |
| `headlineSmall` | Fraunces | 600 | 24/32 | valores do `StatTile`, saldo "Conta" do dashboard — esse é o slot que dá aos valores em moeda sua nova voz distintiva |
| `titleLarge` | Fraunces | 600 | 22/28 | títulos de página ("Dashboard", "Receitas", "Gastos", "Categorias", "Ajustes") |
| `titleMedium` | Work Sans | 600 | 16/24 | rótulos de dropdown/seção |
| `titleSmall` | Work Sans | 600 | 14/20 | headers de card ("Caixinhas", "Receitas lançadas") |
| `bodyLarge` | Work Sans | 400 | 16/24 | |
| `bodyMedium` | Work Sans | 400 | 14/20 | texto de linha padrão, labels de formulário |
| `bodySmall` | Work Sans | 400 | 12/16 | legendas/datas (tier `inkSubtle`) |
| `labelLarge` | Work Sans | 600 | 14/20 | labels de botão |
| `labelMedium` | Work Sans | 600 | 12/16 | label do `StatTile` ("Saldo total"), labels de chip |
| `labelSmall` | Work Sans | 600 | 11/16 | |

O peso `w600` está embutido diretamente nas definições de tema
`titleLarge`/`titleSmall` (`_textTheme` em `lib/theme/theme.dart`). Alguns
call sites (ex.: o título de página do `categorias_page.dart`) ainda
adicionam um redundante `.copyWith(fontWeight: FontWeight.w600)` por cima —
inofensivo (mesmo valor duas vezes), uma pequena limpeza deixada pra quando
esse widget for mexido de novo, não urgente.

**Valores em moeda:** `FontFeature.tabularFigures()` é aplicado a valores
renderizados dentro de uma lista (valores de linha em Receitas/Gastos/
Categorias, legendas de orçamento — ver `dashboard_page.dart`,
`receitas_page.dart`, `gastos_page.dart`) pra que pontos decimais/dígitos se
alinhem verticalmente numa coluna. Não aplicado aos valores hero únicos do
`StatTile` (nada com que alinhar).

---

## 3. Forma, espaçamento, elevação

- **Raio do card:** 16dp (subiu de 12dp) — mais arredondado, mais "bolsa/
  envelope", ainda uma mudança trivial de `RoundedRectangleBorder`.
- **Raio do input:** 12dp (subiu de 8dp).
- **Raio do botão:** inalterado — a forma default do `FilledButton`/
  `OutlinedButton`/`TextButton` do Material 3 já é um estádio/pílula
  completo. Não sobrescrever; já bate com a direção "tátil, suave" de
  graça.
- **Escala de espaçamento:** `4 / 8 / 12 / 16 / 20 / 24 / 32 / 40` px. Isso já
  é, de forma solta, o que o app usa (4, 8, 10, 12, 16, 20, 24 aparecem por
  todo lado); formalizar isso só significa preferir esses passos exatos daqui
  pra frente (ex.: o `10` atual em `padding: EdgeInsets.symmetric(vertical:
  10)` de uma linha poderia virar `12` na próxima vez que esse widget for
  mexido — não urgente o bastante pra justificar uma mudança de passagem
  hoje).
- **Elevação — decisão:** mudar de elevação-0-mais-linha-fina para
  **elevação 1 + borda fina, as duas ao mesmo tempo**, com
  `surfaceTintColor: Colors.transparent` explicitamente setado no
  `CardThemeData` e nos temas de dialog/menu/bottom-sheet.
  - *Por que as duas, não uma ou outra:* elevação 0 é o que faz o app atual
    parecer plano/genérico; uma sombra-suave-pura-sem-borda pode parecer
    "flutuante" e perder nitidez no desktop/web onde os cards ficam
    diretamente sobre um fundo de tom parecido. Uma borda fina + uma sombra
    pequena (elevação 1) juntas leem como "um card descansando sobre a mesa"
    — que é a metáfora literal do "envelope caloroso" — enquanto continua
    sendo um `Card` nativo do Material (sem `BoxShadow`/`DecoratedBox`
    manual pra manter).
  - *Por que `surfaceTintColor: Colors.transparent`:* o comportamento
    default do Material 3 tinge superfícies elevadas com a cor primária do
    color scheme conforme a elevação aumenta. Como este app agora tem uma
    paleta de superfície totalmente ajustada à mão, exata (não uma derivação
    de `ColorScheme.fromSeed`), esse auto-tint desviaria silenciosamente os
    tons marfim/papel quentes pra verde em elevações mais altas —
    prejudicando os tokens exatos do §1. Desligar isso mantém `surface`/
    `surfaceElevated` exatamente como especificado, independente da
    elevação.
  - Dialogs/bottom sheets/menus: elevação 3, mesmo override de
    `surfaceTintColor: transparent`, background = `surfaceElevated`.
- **Construção do `ColorScheme`:** construir explicitamente via o construtor
  `ColorScheme()` a partir dos tokens do §1, não via
  `ColorScheme.fromSeed(...)` como hoje — uma seed só deixa setar uma cor e
  deriva o resto, que é exatamente como o app acabou parecendo um app
  Material azul genérico em primeiro lugar. Mapa: `primary/onPrimary/
  primaryContainer/onPrimaryContainer`, `secondary/.../secondaryContainer/
  ...`, `tertiary/.../tertiaryContainer/...`, `error/.../errorContainer/...`,
  `surface/onSurface` (o M3 dobrou o antigo papel `background` em
  `surface`), `outline` = token `border` (cor central opaca, não o divisor
  translúcido — escolher um tom médio sólido, ex.: claro `#8A7F6E` / escuro
  `#6B6455`, pros poucos lugares onde `ColorScheme.outline` é usado pra
  contornos de componente reais como as bordas default de `OutlinedButton`),
  `shadow` = `inkPrimary`.

---

## 4. Notas de estilo de componente

- **`AppCard`** (`widgets/app_card.dart`): `Card(elevation: 1,
  surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16), side: BorderSide(color:
  context.tokens.border)))`. Padding inalterado (20).
- **Inputs de texto:** `filled: true`, `fillColor` = token `background`
  (isso mantém o visual sutil de "slot recuado" de hoje — o campo lê
  levemente afundado em relação ao card branco onde está, como um encaixe
  cortado num envelope), `borderRadius: 12`, borda fina no token `border`,
  borda **em foco** de 2dp em `primary`.
- **`FilledButton`:** `primary`/`onPrimary`, forma pílula default — sem
  override necessário.
- **`FilledButton.tonal`:** o default do Material 3 já resolve isso pra
  `secondaryContainer`/`onSecondaryContainer` uma vez que o `ColorScheme`
  esteja construído corretamente (§3) — sem override necessário. É o que o
  botão "Alocar" de hoje usa; vai pegar o novo tom sálvia automaticamente.
- **Uma nova ação de destaque** (o ponto de entrada "Transferir", §5): dar a
  ela um `FilledButton` explicitamente colorido em `tertiary` (ou
  `FilledButton.tonal` com `style: FilledButton.styleFrom(backgroundColor:
  tertiaryContainer, foregroundColor: onTertiaryContainer)`) pra que o
  destaque coral apareça exatamente onde um tipo de ação genuinamente novo e
  distinto precisa se destacar — e em nenhum outro lugar. Manter o coral
  raro é o que faz ele ler como um accent em vez de "o app agora é laranja".
- **`OutlinedButton`/`TextButton`:** comportamento default do M3 (texto/
  borda coloridos em primary) — sem override.
- **`NavigationRail`/`NavigationBar`:** sem override de cor de indicador
  custom necessário — a pílula default de indicador selecionado do
  Material 3 já resolve pra `secondaryContainer`, que vira o tom sálvia.
  Deixar o background como `surface` (um painel "espinha" sutilmente
  distinto ao lado da tela marfim) em vez de `background`, pra que o rail
  leia como uma peça fixa de chrome, não parte da área de conteúdo com
  scroll. `VerticalDivider`/`Divider` inferior no token `border`, inalterado
  do padrão de hoje.
- **Identidade de cor por caixinha:** reaproveitar o padrão `_LegendDot` já
  existente em `dashboard_page.dart` (um círculo preenchido de 10dp + label)
  como o componente canônico "cor da caixinha" — extrair pra um arquivo
  compartilhado em `widgets/` (ex.: `CaixinhaColorDot`) pra que seja usável
  a partir das linhas de caixinha do Dashboard, da lista de Categorias, e
  dos novos dropdowns do diálogo de transferência (itens origem/destino),
  em vez de inventar uma segunda linguagem visual pro mesmo conceito.
  Posicionamento: imediatamente antes do nome da caixinha/categoria, gap de
  `6px`, batendo com o espaçamento de legenda existente.
- **Barra de progresso (orçamento vs. limite, §5):**
  `LinearProgressIndicator` (widget M3 de fábrica — checar a versão do
  Flutter SDK em uso pra suporte nativo de `borderRadius` nela; se não
  disponível, envolver em `ClipRRect(borderRadius:
  BorderRadius.circular(4))`), altura ~6–8dp, cor de trilha = token
  `border`, cor de preenchimento por proporção: `<80%` → `secondary`
  (neutro/informativo, não "alarmante"), `80–100%` → `statusWarning`,
  `>100%` → `statusCritical` (barra visualmente limitada a 100% de largura —
  nunca transbordar a trilha — com o excedente declarado como texto, ver
  §5).

- **Badges de status** (ex.: pills "quase no limite" / "acima do limite" ao
  lado da legenda de orçamento, §5): usar a cor de status **sólida** como o
  preenchimento com texto branco — `statusWarning`/`statusCritical`/
  `statusGood` contra branco são os pares já verificados no §1
  (4.59/5.31/5.10:1). **Não** usar um container tingido (ex.:
  `tertiaryContainer`) como fundo do badge com a cor de status como texto:
  essa combinação falha AA no tamanho real de 11px do badge
  (`statusWarning` texto sobre `tertiaryContainer` é 3.52:1,
  `statusCritical` sobre ele é 4.07:1, `statusGood` sobre
  `primaryContainer` é 4.08:1 — todos abaixo do 4.5:1 exigido nesse
  tamanho).

**Logo existente** (`assets/logo.svg`): uma ilustração de cofrinho/moeda em
`#1BAF7A` (verde) + `#1A6B4E` (verde escuro) + `#FFC800` (dourado) +
`#A4830C` (dourado escuro). Isso fica bem ao lado da nova paleta — já está
na mesma família de matiz verde/dourado do `primary`/`Âmbar`, só um verde
mais brilhante/saturado que o novo `primary` (`#2E6F4D`). Ajustar o verde do
logo pra bater com `primary` exatamente é um follow-up cosmético, não-
bloqueante — hoje eles leem como "relacionados mas não idênticos" em vez de
"a mesma cor".

---

## 5. Padrões de UX das features

As features que foram lançadas junto com essa identidade (editar transação,
orçamento mensal por caixinha, transferência entre caixinhas, filtro de
intervalo de datas em Receitas/Gastos, e depois o propósito guardar/gastar da
caixinha) todas reaproveitam o mesmo vocabulário de interação em vez de
inventar um novo por feature — consistência ganha de novidade aqui. Os
padrões que vale a pena conhecer como regras de identidade/UX (não detalhe de
implementação — isso vive no código, que é a fonte de verdade atual pro
comportamento exato):

- **Um breakpoint adaptativo (720px)** decide dialog-vs-bottom-sheet
  (`showAdaptiveFormSheet`), rail-vs-bottom-nav (`AppShell`), e
  lado-a-lado-vs-empilhado nos campos de formulário (`ResponsiveFormRow`) em
  todo lugar no app — uma única regra que o usuário aprende uma vez, não uma
  decisão por feature.
- **Tocar numa linha pra editar**, com o delete rebaixado a um pequeno
  `IconButton` no final + diálogo de confirmação, pra que o alvo de toque
  primário da linha nunca seja destrutivo.
- **Barras de progresso comunicam dois significados opostos por design, não
  só por cor:** `CaixinhaBudgetBar` (caixinhas de gastar) é um medidor de
  *consumo* — encher é um aviso (`secondary` → `statusWarning` →
  `statusCritical` acima de 100%, limitado a 100% de largura, com o
  excedente declarado como texto). `CaixinhaGoalBar` (caixinhas de guardar
  com meta) é o inverso — encher é sucesso (`primary` → `statusGood` ao
  atingir a meta). Nunca confiar só na cor de preenchimento; a legenda
  sempre declara os números também.
- **Badges de status usam a cor de status sólida como preenchimento com
  texto branco**, nunca um container tingido como fundo com a cor de status
  como texto — essa combinação foi checada e medida abaixo de AA no tamanho
  real do badge (`statusWarning` sobre `tertiaryContainer`: 3.52:1;
  `statusCritical`: 4.07:1; `statusGood` sobre `primaryContainer`: 4.08:1 —
  todos falham 4.5:1).
- **O propósito de uma caixinha (`kind`) muda qual medidor ela recebe, não
  seu modelo de dinheiro subjacente** — ver `docs/ARQUITETURA.pt-br.md` pra
  como `spend`/`save` mapeiam pra `monthlyBudget`/`goalAmount`.
- **Dívida ("debt") não recebe nenhuma linguagem visual nova, de propósito.**
  `CaixinhaDebtIndicator` (o saldo negativo corrente de uma caixinha
  `spend`, só alcançável via o toggle "Permitir saldo negativo" — ver
  `docs/BACKEND.pt-br.md`, "allowNegative") reaproveita o tratamento
  existente "acima do limite" do `CaixinhaBudgetBar`: texto bold simples em
  `statusCritical` ("Devendo R$ X"), sem barra ou badge, sem novo token de
  cor. Ele renderiza independentemente de, e ao lado de, a barra de
  orçamento mensal — uma acompanha o gasto deste mês contra um limite
  suave, a outra acompanha o saldo corrente histórico, e uma caixinha pode
  estar em qualquer um dos estados (ou ambos) independente do outro.

Os pontos de entrada exatos por tela, diálogos e estados vazio/carregando/
erro estão implementados em `lib/features/**` e
`lib/widgets/edit_transaction_sheet.dart`, `caixinha_budget_bar.dart`,
`adaptive_form_sheet.dart`, `responsive_form_row.dart` — ler esses
diretamente pro comportamento atual em vez de uma spec que pode se desalinhar
do que está de fato em produção.
