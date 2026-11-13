# Dindin: proposta de design do onboarding

Status: **proposta**, ainda não implementada. Nada aqui é código do app.
Mockup visual estático (claro e escuro, 360 e 320 px, estados vazios, Ajustes):
[`onboarding-mockup.html`](onboarding-mockup.html). Abra no navegador a partir
desta pasta (ele carrega as fontes de `../assets/fonts/`).

Base: `docs/DESIGN.md` (tokens, tipografia, raios), `lib/widgets/`
(`AppCard`, `EmptyState` (que mora dentro de `app_card.dart`), `PageHeader`,
`AppShell`), as páginas de `lib/features/*` e o manual de marca
(`cafelabs-vault/marca/dindin/manual/dindin-manual.md`, v1.1).

## 0. O que o código mostra sobre o problema

Antes da proposta, quatro fatos do app que explicam a reclamação:

1. **O app abre no Dashboard, que não tem nenhum botão de lançar.** Receita e
   gasto são lançados num formulário fixo no topo de Receitas e de Gastos. Quem
   não descobre o menu nunca chega ao formulário.
2. **O menu é o título da página** (`PageHeader`), com um chevron `expand_more`
   em `tokens.subtle` (#746A5D no claro). Ele parece um título com um ícone
   decorativo, não um botão. No celular não existe outra forma de navegar.
3. **Os estados vazios são uma linha cinza** (`EmptyState`, `bodyMedium` em
   `subtle`), sem ação na maioria das páginas. O do Dashboard diz "Crie
   categorias e aloque receitas para ver suas caixinhas aqui", mas não leva a
   nenhum desses lugares.
4. **O vazio de Receitas e Gastos fica abaixo do formulário.** Então o botão de
   ação do estado vazio não precisa abrir nada novo: ele sobe até o formulário e
   foca o campo Valor. Isso ensina onde fica o cadastro sem criar um segundo
   caminho.

O tutorial resolve o momento da primeira visita. Os itens 2 a 4 continuam
valendo para quem pula o tutorial, por isso as seções 4 e 6 são parte da
solução, não enfeite.

### Referências consultadas

- **NN/g, "Instructional overlays and coach marks on mobile"**: dicas são lidas
  por cima e dispensadas rápido; cada dica deve tratar de uma coisa, com texto
  curtíssimo, no momento em que a função importa, e com visual que se distinga
  da interface real (senão a dica parece um controle). Ideia tomada: balão com
  cara de "anotação" (Fraunces, número de passo), e passos ancorados em
  elementos que existem naquela página.
- **Appcues, guia de tooltips**: diferença entre tour "clica em próximo" e tour
  "guiado pela ação" (o passo avança quando a pessoa usa o elemento); mostrar
  progresso ("1 de 3"); sempre ter saída. Ideia tomada: contador de passos e a
  Direção B inteira (guiada pela ação).
- **O próprio manual Dindin**: o "cartão de passo" (número em Fraunces verde +
  frase curta, só quando a ordem importa) e a etiqueta como objeto de papelaria.
  Ideia tomada: o balão é um cartão de passo; o vazio do Dashboard é uma lista
  de primeiros passos.
- A página de tooltips do Material 3 não carregou o conteúdo pela ferramenta,
  então não entrou.

---

## 1. Duas direções

As duas usam o elemento real e 2 a 4 passos por página. Elas diferem na ideia,
não só no visual: uma **para a tela e aponta**, a outra **deixa a tela viva e
pede que você faça**.

### Direção A: "Lanterna" (spotlight com recorte, tour de próximo)

- A tela escurece com um véu na cor do papel/tinta; o elemento real aparece num
  recorte com anel verde cofre de 2 dp. Um balão em forma de cartão de passo
  ("1." em Fraunces verde, título, uma frase) aponta para ele com uma seta.
- É modal: o resto da tela não responde enquanto o tutorial está aberto. Avança
  com "Próximo"; sai com "Pular".
- **Prós:** atenção garantida, que é exatamente o que faltou (as pessoas não
  enxergaram o menu); a moldura escura diz "isto é uma explicação", então o
  balão nunca é confundido com um controle (o alerta da NN/g); um passo por vez
  é fácil de seguir; previsível pra testar e pra leitor de tela (é uma rota
  modal como qualquer diálogo); pacotes de coach mark do Flutter fazem isso
  sem código sob medida.
- **Contras:** interrompe; a pessoa lê sobre o botão em vez de apertar o botão;
  no tema escuro o véu quase não escurece um fundo que já é #16130F, então o
  anel precisa carregar o destaque (resolvido na anatomia abaixo); tour de
  próximo é fácil de atravessar sem ler.

### Direção B: "Etiqueta" (sem escurecer, guiado pela ação) — a arriscada

- Nada escurece. O elemento ganha um anel verde com halo suave, e uma etiqueta
  de papelaria (cor envelope #F3EADB, um furo com contorno folha, presa por um
  fio tracejado) diz o que fazer: "Toque em Lançar receita".
- A tela continua usável. Tocar no elemento destacado faz a ação de verdade e
  avança o passo. Tocar em outro lugar não fecha a etiqueta.
- **Prós:** ensina fazendo (o lançamento real é o tutorial); a etiqueta é um
  objeto do manual, então o onboarding fica com a cara do Dindin e de nenhum
  outro app; não bloqueia quem já sabe o que está fazendo.
- **Contras:** o passo depende de a pessoa conseguir fazer a ação (lançar
  receita exige valor preenchido; Alocar fica desabilitado sem caixinha), então
  cada passo vira uma pequena máquina de estados com caminho alternativo; sem
  véu, a etiqueta disputa atenção com o formulário inteiro, e o público que
  reclamou é justamente o que não percebe sinais discretos; a cor envelope é
  clara nos dois temas, então no escuro vira um bloco claro sobre fundo escuro
  (o manual permite em ilustração, mas como superfície de texto precisa de
  checagem própria); custa mais pra implementar, testar e manter, e quase
  nenhum pacote faz isso pronto.

### Recomendação: Direção A, com um passo guiado pela ação

A "Lanterna", por três motivos: o problema relatado é de **não ver** (A garante
o olhar), o público é o menos experiente do app, e é a que um mantenedor solo
consegue sustentar. Duas coisas da B entram nela:

- **O balão é um cartão de passo do manual**, não um tooltip genérico: número
  em Fraunces verde cofre, título em Fraunces. Isso dá a identidade e cumpre a
  regra da NN/g de a dica não parecer um controle.
- **Um passo guiado pela ação, só um:** o passo do menu, no Dashboard. O
  recorte deixa o toque passar: se a pessoa tocar no nome da página, o menu
  real abre e o tutorial do Dashboard termina como visto. É o único ponto em
  que fazer vale mais que ler, e o menu é autoexplicativo depois de aberto.

Se o Felipe preferir a B mesmo assim, ela funciona melhor restrita a Receitas e
Gastos (onde a ação é o objetivo), com a A no resto. Ver decisões na seção 7.

---

## 2. Anatomia e comportamento (Direção A)

### 2.1 Véu e destaque

| Parte | Claro | Escuro |
|---|---|---|
| Véu (scrim) | `inkPrimary` #211A12 a 60% | `background` #16130F a 72% |
| Anel do recorte | `primary` #2E6F4D, 2 dp | `primary` #7FCB9E, 2 dp |
| Folga do recorte | 4 dp em volta do elemento (6 dp se o elemento tiver menos de 48 dp de altura) | igual |
| Raio do recorte | raio do elemento + 4 (card 16 → 20; botão pílula → pílula; título 8 → 12) | igual |

- Nada de preto puro: o véu usa a tinta ou o papel do próprio app, como o
  manual pede. (O menu atual usa `Colors.black54` como barreira; vale alinhar
  depois, mas não é escopo.)
- No escuro o véu escurece pouco porque o fundo já é quase preto. Por isso o
  anel é obrigatório nos dois temas: ele é o destaque de verdade.
  `primary` escuro sobre o fundo dá 9,6:1, bem acima dos 3:1 de objeto gráfico.

### 2.2 Balão

| Parte | Especificação |
|---|---|
| Fundo | `surfaceElevated` (#FFFFFF claro, #2A241D escuro) |
| Borda | `border` (tinta a 12% no claro, #F5F1EA a 12% no escuro), 1 dp |
| Raio | 16 dp (o mesmo do `AppCard`) |
| Sombra | elevação 3, `surfaceTintColor` transparente (como diálogos em `DESIGN.md` §3) |
| Largura | `min(328, largura da tela − 32)`; em 320 px, tela − 24 (12 de cada lado) |
| Padding | 16 dp nas laterais e em cima, 8 embaixo (os botões já trazem altura) |
| Número | Fraunces 600, 22/26, `primary` ("1.", "2.") |
| Título | Fraunces 600, 18/24, `inkPrimary`. Uma linha de preferência, no máximo duas |
| Texto | Work Sans 400, 15/22, `inkSecondary` (6,9:1 claro; 10,5:1 escuro). No máximo duas frases |
| Contador | Work Sans 600, 12/16, `inkSubtle`, "1 de 4" / "1 of 4" |
| Pular | `TextButton` em `inkSecondary` (não em verde: é a saída, não a ação) |
| Próximo | `FilledButton` `primary`. No último passo vira "Entendi" / "Got it" |
| Alvo de toque | 48 dp de altura nos dois botões |
| Seta | triângulo de 16 × 8 dp, mesma cor e borda do balão, apontando pro centro do alvo, a pelo menos 20 dp dos cantos arredondados |

Contraste de todos os textos já verificado no `DESIGN.md`: os pares são os
mesmos de card e diálogo.

**Posição:** abaixo do alvo se couber, senão acima; nunca ao lado no celular.
Se nem acima nem abaixo couber (alvo grande, tela pequena, fonte grande), o
balão encaixa no rodapé da tela, com 12 dp de margem, **sem seta**, e o anel
continua no alvo (ver o mockup a 320 px). Em tela larga (≥ 720 px) o balão pode
ficar ao lado do alvo, com a seta na lateral, e o passo do menu aponta pra barra
lateral (`NavigationRail`).

**Sem folhinha no balão.** O manual coloca folhinha nas laterais de
ilustração, nunca atrás de texto; num balão de 300 px ela só disputaria espaço.
Os elementos de marca ficam nos estados vazios e no selo de Ajustes.

### 2.3 Quando aparece

- Na primeira vez que a página fica visível **depois de os dados carregarem**
  (nunca por cima do `DataLoadingView` nem de um estado de erro), com uns
  400 ms de folga pra tela assentar.
- Fila com o que já existe: se o diálogo de verificação de e-mail abrir, o
  tutorial espera ele fechar. O snackbar de atualização e o de cobranças
  lançadas podem coexistir, mas o balão não pode ficar por cima deles; se o
  snackbar ocupar o rodapé, o balão de rodapé sobe.
- Uma página por vez. Se a pessoa trocar de tela durante o tutorial (só dá pelo
  passo do menu ou pelo voltar), o tutorial da página que saiu fecha **sem**
  marcar visto, a não ser no passo do menu (lá, marca).
- Os alvos escolhidos existem com ou sem dados (título, formulário, botão de
  lançar, cartão da lista). Alocar e Transferir aparecem mesmo desabilitados.
  Nenhum passo depende de a conta ter conteúdo.

### 2.4 Movimento

Mesma linguagem do menu que já existe (220 ms, `easeOutCubic`):

- Entrada: véu em fade de 200 ms; balão sobe 8 dp com fade em 180 ms, 60 ms
  depois do véu.
- Entre passos: o recorte e o anel **deslizam** de um alvo pro outro em
  280 ms `easeOutCubic` (a pessoa acompanha com o olho pra onde foi), o balão
  some e reaparece no lugar novo.
- Alvo fora da tela: rolar até ele (`ensureVisible`, alinhado a ~30% do topo)
  em 300 ms antes de mostrar o recorte. O pacote precisa suportar isso (ver
  requisitos).
- Saída: tudo em fade de 150 ms.
- **Reduzir movimento** (`MediaQuery.disableAnimations` / "remover animações"
  do sistema): sem deslize nem subida; troca direta (ou fade de até 100 ms) e
  rolagem instantânea.
- Nada pulsa, nada fica em loop.

### 2.5 Teclado, rotação, tamanho

- **Teclado:** o tutorial não começa com teclado aberto; se o teclado estiver
  aberto quando a página fica visível, ele espera fechar. Nenhum passo foca
  campo. Se a área visível mudar durante o tutorial (teclado de outro app,
  janela redimensionada), reposicionar.
- **Rotação e redimensionamento:** recalcular a posição do alvo a cada mudança
  de tamanho. Se a largura cruzar os 720 px (troca entre menu no título e barra
  lateral), manter o passo atual e trocar o alvo para o equivalente.
- **320 px:** balão com tela − 24; o rodapé do balão quebra em duas linhas se
  precisar (contador em cima, botões embaixo à direita). Nenhum texto corta com
  reticências.
- **Fonte x1.3 (e até x2):** o balão cresce na altura; se não couber junto do
  alvo, vai pro rodapé sem seta. Acima de x1.5, o título pode quebrar em duas
  linhas. Nunca rolagem interna no balão abaixo de x2; em x2, rolagem interna é
  aceitável com os botões sempre visíveis fora dela.
- **Inglês:** os textos em inglês são mais curtos; o português é o caso mais
  longo e foi o usado no mockup.

### 2.6 Leitor de tela (TalkBack / VoiceOver)

- O tutorial é uma rota modal: o foco vai pro balão, e o que está atrás fica
  fora da árvore de acessibilidade, como num diálogo.
- Anúncio ao abrir cada passo: "Tutorial de Receitas, passo 1 de 3. Lance o
  que entrou. Preencha o valor e de onde veio." Ordem de foco: título, texto,
  Próximo, Pular.
- O texto de cada passo descreve onde está o elemento ("o nome da página, aqui
  em cima"), porque quem não vê o recorte precisa achar o elemento sozinho
  depois.
- Com leitor de tela ativo, o passo do menu não depende do recorte deixar o
  toque passar: "Próximo" funciona normalmente.
- Voltar (gesto ou botão do sistema) = Pular (fecha e marca visto). Ver
  decisão 3.

### 2.7 Progresso e regras de "visto"

- Uma marca por página no perfil do usuário (vale entre dispositivos), com o
  modo: `concluído` ou `pulado`. Os dois contam como visto.
- Gravado ao terminar, ao pular ou ao sair pelo passo do menu.
- Precisa funcionar offline: guarda localmente na hora e sincroniza depois,
  pra o tutorial não reaparecer na mesma sessão nem no mesmo aparelho se a
  gravação no perfil falhar.
- Conta já existente: vê o tutorial de cada página na próxima vez que abri-la.
- Sugestão: guardar também a **versão** do tutorial de cada página, pra que
  uma mudança grande numa página possa reexibir só aquele tutorial. Ver
  decisão 5.

### 2.8 Requisitos para o pacote (sem indicar qual)

1. Destacar um widget pela sua chave/posição real, inclusive dentro de lista
   rolável, rolando até ele antes de mostrar.
2. Recorte com raio configurável por passo e anel de cor configurável.
3. Balão com widget livre (não só texto), pra montar o cartão de passo.
4. Posicionamento automático acima/abaixo e modo "encaixado no rodapé sem
   seta" quando não couber.
5. Deixar o toque passar pelo recorte num passo específico (passo do menu) e
   bloquear nos outros.
6. Recalcular em mudança de tamanho, rotação e teclado.
7. Respeitar `disableAnimations`, ou permitir desligar as animações.
8. Semântica de rota modal (foco no balão, fundo fora da árvore).
9. Funcionar no Android e na web (a plataforma viva do app), com mouse e
   teclado na web (Tab entre os botões, Esc = Pular).
10. Callback de concluído/pulado pra gravar o progresso.

Se nenhum pacote atender 1, 4 e 8 juntos, vale mais escrever uma rota modal
própria com `CustomPainter` pro recorte do que forçar um pacote.

---

## 3. Textos dos passos

Regras usadas: frases curtas, "você", nomes do app, sem promessa, sem
exclamação, sem emoji. Cada passo diz o elemento real que fica no recorte.
Ordem dos passos = ordem de importância, não da tela, pra que quem pular cedo
ainda tenha visto o essencial.

### Dashboard (4 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Título da página + chevron (`PageHeader`). Tela larga: a barra lateral. **Toque passa:** tocar abre o menu e encerra o tutorial como visto | **Aqui você troca de tela** · Toque no nome da página para abrir o menu com Receitas, Gastos e as outras telas. *(larga: As telas do app ficam nesta barra.)* | **This is where you switch screens** · Tap the page name to open the menu with Income, Expenses and the other screens. *(wide: The app's screens are in this bar.)* |
| 2 | Cartão "Conta" (saldo + texto de apoio) | **O dinheiro entra na conta** · Cada receita que você lança cai aqui. Ela ainda não está em nenhuma caixinha. | **Money lands in your account** · Every income you add shows up here. It isn't in any envelope yet. |
| 3 | Botão "Alocar" | **Depois, distribua** · Alocar manda parte da conta para uma caixinha. As caixinhas você cria em Categorias. | **Then split it up** · Allocate moves part of your account into an envelope. You create envelopes in Categories. |
| 4 | Cartão "Caixinhas" (com o botão Transferir) | **Suas caixinhas** · Cada uma mostra quanto tem. Transferir move dinheiro de uma para outra. | **Your envelopes** · Each one shows how much it holds. Transfer moves money from one to another. |

### Receitas (3 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Cartão do formulário (data, valor, origem, descrição) | **Lance o que entrou** · Preencha o valor e de onde veio. A data já vem com hoje. | **Add what came in** · Fill in the amount and where it came from. The date starts as today. |
| 2 | Botão "Lançar receita" | **É só lançar** · O valor cai na sua conta. Para separar em caixinhas, use Alocar no Dashboard. | **Then add it** · The amount goes to your account. To split it into envelopes, use Allocate on the Dashboard. |
| 3 | Cartão "Receitas lançadas" (filtro de datas + lista) | **Tudo o que entrou fica aqui** · Toque numa receita para corrigir. As datas acima filtram a lista. | **Everything that came in** · Tap an income to fix it. The dates above filter the list. |

### Gastos (3 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Cartão do formulário | **Lance um gasto** · Valor e data. A descrição é opcional, mas ajuda a lembrar depois. | **Add an expense** · Amount and date. The description is optional, but it helps later. |
| 2 | Campo "De onde sai" (com o "Disponível" logo abaixo) | **Escolha de onde sai** · Da conta ou de uma caixinha. O saldo disponível aparece logo abaixo. | **Choose where it comes from** · Your account or an envelope. The available balance shows right below. |
| 3 | Cartão "Gastos lançados" | **Seus gastos ficam aqui** · Toque num gasto para editar. As datas acima filtram a lista. | **Your expenses** · Tap one to edit it. The dates above filter the list. |

### Assinaturas (3 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Cartão do formulário (nome, dia da cobrança, valor) | **Cadastre uma vez** · Nome, valor e o dia da cobrança. Streaming, academia, aluguel. | **Set it up once** · Name, amount and billing day. Streaming, gym, rent. |
| 2 | Campo "Sai de" | **Lançado no dia certo** · No dia da cobrança, o gasto sai da conta ou da caixinha escolhida, na próxima vez que você abrir o app. | **Charged on the right day** · On the billing day, the expense comes out of the account or envelope you picked, the next time you open the app. |
| 3 | Cartão "Assinaturas cadastradas" | **Suas assinaturas** · Toque numa para editar. Cobrar agora lança antes do dia. | **Your subscriptions** · Tap one to edit it. Charge now posts it before the day. |

Nota do passo 2: o lançamento acontece quando o app abre (o catch-up roda na
abertura). O texto diz isso para não prometer um débito automático que não
existe com o app fechado.

### Parcelamentos (3 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Cartão do formulário (nome, data da compra, valor, parcelas, primeira cobrança) | **Uma compra, várias parcelas** · Informe o valor total e em quantas vezes. O Dindin divide pelos meses. | **One purchase, many installments** · Enter the total and how many installments. Dindin splits it across the months. |
| 2 | Campo "Sai de" | **Cada parcela sai daqui** · Da conta ou de uma caixinha, no mês de cada cobrança. | **Each installment comes from here** · Your account or an envelope, in each billing month. |
| 3 | Cartão "Parcelamentos cadastrados" | **Adiantar ou quitar** · Em cada compra, você pode pagar mais que a parcela ou quitar o que falta. | **Pay early or pay off** · On each purchase you can pay more than the installment or pay off the rest. |

Se a lista estiver vazia, o passo 3 continua no cartão da lista (que existe),
com o mesmo texto: ele explica o que vai aparecer ali.

### Categorias (3 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Campo de nome + botão "Adicionar" | **Cada categoria vira uma caixinha** · Dê um nome, como Mercado ou Viagem, e toque em Adicionar. | **Each category becomes an envelope** · Give it a name, like Groceries or Travel, and tap Add. |
| 2 | Botões "Guardar / Gastar" | **Guardar ou gastar** · Guardar é para juntar até uma meta. Gastar é para ter um limite por mês. | **Save or spend** · Save is for reaching a goal. Spend is for a monthly limit. |
| 3 | Lista de caixinhas | **Suas caixinhas** · Toque numa para mudar o nome, a meta ou o limite. | **Your envelopes** · Tap one to change its name, goal or limit. |

### Ajustes (2 passos)

| # | Elemento destacado | pt-BR | en |
|---|---|---|---|
| 1 | Cartão "Backup" | **Guarde uma cópia** · Exporte um backup dos seus dados quando quiser. | **Keep a copy** · Export a backup of your data whenever you want. |
| 2 | Cartão "Tutoriais" (novo, seção 5) | **Rever explicações** · Quer ver um tutorial de novo? Ele fica aqui. | **See tips again** · Want to see a tutorial again? It's here. |

Termo em inglês para caixinha: "envelope", o mesmo do `app_en.arb`
(`caixinhasTitle`: "Envelopes"). Telas com o nome do inglês: Income,
Expenses, Installments, Categories.

---

## 4. Estados vazios

Um componente só, evolução do `EmptyState` atual (que ganha `title`,
`illustration` e `action` obrigatório quando houver o que fazer):

- Ilustração no topo, até 72 dp de altura, centralizada.
- Título: Fraunces 600, 17/24, `inkPrimary`.
- Texto: Work Sans 14/20, `inkSecondary` (não mais `subtle`: é a instrução,
  tem que ler bem), largura máxima de 280 dp.
- Botão: `FilledButton` `primary`, rótulo com verbo + nome ("Adicionar
  receita").
- Vazio **filtrado** (Receitas e Gastos com filtro de data): fica só texto +
  "Limpar filtro", sem ilustração, como hoje. Ilustração ali seria ruído.

Cada página usa um motivo diferente, todos do repertório do manual:

| Página | Motivo | pt-BR (título · texto · botão) | en | O que o botão faz |
|---|---|---|---|---|
| Dashboard (sem caixinha e sem receita) | **Cartão de passo** do manual, sem ilustração: lista "Primeiros passos" com 1., 2., 3. em Fraunces verde | **Primeiros passos** · Três coisas e o Dindin começa a fazer sentido. 1. Crie uma caixinha (Criar) · 2. Lance uma receita (Lançar) · 3. Aloque na caixinha (Alocar) | **First steps** · Three things and Dindin starts to make sense. 1. Create an envelope · 2. Add an income · 3. Allocate to an envelope | Cada linha leva à tela certa (Categorias, Receitas com Valor focado, diálogo Alocar). Passo feito fica riscado em `subtle` com "Feito". O cartão some quando os três estão feitos e substitui o vazio atual de Caixinhas |
| Dashboard, histórico mensal vazio | só texto (o cartão de passos já está na tela) | Lance receitas e gastos para ver o histórico por mês. · botão de texto "Lançar receita" | Add income and expenses to see the monthly history. · "Add income" | Vai pra Receitas com Valor focado |
| Receitas | **Uma moeda** do Dindin (dinheiro entrando) | **Nenhuma receita ainda** · Lance seu salário ou qualquer valor que entrou. Ele vai para a conta. · Adicionar receita | **No income yet** · Add your salary or any money that came in. It goes to your account. · Add income | Rola até o formulário e foca Valor |
| Gastos | **Ícone de linha carrinho**, traço folha | **Nenhum gasto ainda** · Lance o mercado de hoje, uma conta ou um café. Você escolhe de onde sai. · Adicionar gasto | **No expenses yet** · Add today's groceries, a bill or a coffee. You choose where it comes from. · Add expense | Rola até o formulário e foca Valor |
| Assinaturas | **Ícone de linha calendário com uma volta** (repete), traço folha | **Nenhuma assinatura ainda** · Streaming, academia, aluguel. Cadastre uma vez com o dia da cobrança. · Adicionar assinatura | **No subscriptions yet** · Streaming, gym, rent. Set it up once with the billing day. · Add subscription | Rola até o formulário e foca Nome |
| Parcelamentos | **Três moedas em escada**, crescendo (o limite de três do manual) | **Nenhum parcelamento ainda** · Cadastre a compra uma vez, com o valor total e o número de parcelas. · Adicionar parcelamento | **No installment purchases yet** · Add the purchase once, with the total and the number of installments. · Add installment purchase | Rola até o formulário e foca Nome |
| Categorias | **Par de folhinhas** (ramo alto, uma espelhada) nas laterais, longe do texto | **Nenhuma caixinha ainda** · Mercado, Viagem, Reserva. Crie a primeira acima. · Criar caixinha | **No envelopes yet** · Groceries, Travel, Savings. Create the first one above. · Create envelope | Rola até o topo e foca o campo de nome |
| Ajustes | não tem vazio | — | — | — |

Cores das ilustrações: moeda sempre #E8B04A com sombra #A8660A (igual nos dois
temas, conforme o manual e o SVG `dindin-moeda.svg`); folhinhas pelas versões
`-fundo-claro` / `-fundo-escuro` de `elementos/`; ícones de linha na cor folha
(#3A604B no claro; no escuro, a mesma cor clara das folhinhas de fundo escuro,
#7FCB9E, pra não sumir no #201C17). Ilustração é decorativa pra leitor de
tela (`excludeSemantics`); quem carrega o sentido é o título.

O selo terracota não entra em nenhum vazio: ele fica reservado pro cartão de
tutoriais completo (seção 5), o único ponto terracota do onboarding.

Os SVGs da marca precisam ser copiados de `cafelabs-vault/marca/dindin/elementos/`
para `assets/` do app. O ícone de calendário com volta não existe no manual
(decisão 7).

---

## 5. Tutoriais em Ajustes

Um `AppCard` novo, **entre "Tema" e "Backup"** (perto das preferências, longe
da zona de perigo).

- Cabeçalho: "Tutoriais" (`titleSmall`) à esquerda; "5 de 7 vistos"
  (`bodySmall`, `subtle`) à direita.
- Barra de progresso abaixo, com a semântica de meta do app (encher é bom):
  `primary`, trilho `border`, 6 dp. O texto "5 de 7" carrega o número; a barra
  não é a única informação.
- Lista com as 7 páginas, na ordem do menu. Cada linha (altura mínima 52 dp):
  nome da página · status · botão de texto.
  - Status: "Visto" (`primary`, 600), "Pulado" (`subtle`), "Ainda não"
    (`subtle`). Pulado conta como visto no número, mas aparece escrito, por
    honestidade.
  - Botão: "Rever" nas vistas, "Ver" nas não vistas. Tocar **marca como não
    visto e já abre a página**, onde o tutorial começa. Não faz sentido mandar
    a pessoa procurar a página sozinha.
- Rodapé: `OutlinedButton` "Rever todos". Marca as 7 como não vistas e mostra
  o snackbar "Os tutoriais vão aparecer de novo quando você abrir cada
  página." com "Desfazer". Sem diálogo de confirmação: não apaga dado nenhum,
  e o Desfazer cobre o toque sem querer.
- Com 7 de 7: o **selo com D** (`dindin-selo.svg`, 32 dp) aparece ao lado do
  título do cartão, e a lista pode recolher numa linha "Você já viu todos. Pode
  rever qualquer um." com um "Mostrar" pra expandir. Decorativo pro leitor de
  tela.
- Leitor de tela: cada linha lida como "Gastos, pulado, botão Rever".

Textos em inglês: Tutorials · "5 of 7 seen" · Seen / Skipped / Not yet ·
Review / View · Review all · "Tutorials will show again when you open each
page." · Undo · "You've seen them all. You can review any of them."

---

## 6. Navegação mais descobrível no celular

Em ordem de custo, do mais barato ao mais caro. Recomendo 1 + 2 + 3 juntos.

1. **Chevron dentro de um chip tonal.** Trocar o `expand_more` cinza de 26 dp
   por um círculo de 30 dp em `secondaryContainer` com o ícone em
   `onSecondaryContainer` (10,5:1 claro; 8,8:1 escuro). O chip é a forma que o
   app já usa pra "isto se aperta" (botão tonal Alocar). O alvo de toque segue
   sendo o título inteiro, com no mínimo 48 dp de altura (hoje tem 4 dp de
   padding vertical; subir pra 10). Mesmo tratamento no título fixo
   (`_StickyTitle`). Visto no mockup, no Dashboard dos estados vazios.
2. **Menu com uma linha de descrição por tela.** O nome "Assinaturas" não diz
   o que tem lá; uma linha em `subtle` resolve sem tutorial:
   Dashboard · Saldo, conta e caixinhas / Receitas · O que entrou / Gastos · O
   que saiu / Assinaturas · Gastos que se repetem / Parcelamentos · Compras em
   parcelas / Categorias · Suas caixinhas / Ajustes · Conta, tema e backup.
   (en: Balance, account and envelopes / What came in / What went out / Recurring
   expenses / Purchases in installments / Your envelopes / Account, theme and
   backup.) Itens de 56 dp, ainda cabem os 7 sem rolar num celular comum.
3. **Ações de lançar no Dashboard.** O cerne da reclamação é "não achei onde
   cadastrar", e o Dashboard é onde todo mundo cai. Uma linha com dois botões
   logo abaixo do Saldo total: "Lançar receita" (`FilledButton.tonal`) e
   "Lançar gasto" (`FilledButton.tonal`). Cada um leva à página com Valor
   focado. Usa o padrão de botão que o app já tem, aparece também na web e não
   cria um segundo formulário.
   - Alternativa: um FAB "+" que abre uma escolha Receita/Gasto. Mais
     conhecido no Android, mas é um padrão novo no app e cobre conteúdo no
     rodapé da lista. Prefiro os dois botões.
4. **Barra inferior (o padrão da plataforma).** É a correção mais forte e a
   mais conhecida: Dashboard, Receitas, Gastos e "Mais" sempre visíveis. Fica
   registrado porque é a alternativa padrão, mesmo sabendo que o app tirou as
   barras de propósito (comentário em `app_shell.dart`). Custo: volta a
   ocupar ~80 dp de altura em toda tela e reabre a decisão de layout. Se, depois
   de 1 a 3 e do tutorial, a métrica de "primeira receita lançada" não subir,
   essa é a próxima carta.

---

## 7. Checklist de aceite (QA) e decisões

### 7.1 Checklist de aceite

Disparo e progresso
- [ ] Conta nova: cada uma das 7 páginas mostra seu tutorial na primeira
      abertura, e só nela.
- [ ] Conta existente: idem, na próxima abertura de cada página.
- [ ] O tutorial não aparece por cima de carregamento, erro, do diálogo de
      verificação de e-mail, nem com teclado aberto.
- [ ] "Pular", "Entendi", voltar do sistema e o toque no título (passo 1 do
      Dashboard) marcam a página como vista.
- [ ] Trocar de página no meio (exceto pelo passo do menu) não marca visto.
- [ ] Visto num aparelho não reaparece em outro com a mesma conta.
- [ ] Sem internet: o tutorial visto não reaparece na mesma sessão nem ao
      reabrir o app; sincroniza quando voltar a conexão.
- [ ] Ajustes mostra o número certo, "Pulado" distinto de "Visto".
- [ ] "Rever" abre a página e o tutorial começa. "Rever todos" zera os 7 e o
      "Desfazer" restaura o estado anterior.

Visual
- [ ] Claro e escuro conferidos contra a tabela 2.1/2.2 (véu, anel, balão,
      textos).
- [ ] Recorte acompanha o elemento real, com raio e folga corretos; nada
      cortado nem descentralizado; a seta aponta pro centro do alvo.
- [ ] Alvo fora da tela: a lista rola até ele antes do recorte aparecer.
- [ ] 320 px de largura: nenhum texto cortado, botões com 48 dp, balão no
      rodapé quando não cabe.
- [ ] Fonte x1.3 e x2: idem; em x2 os botões continuam visíveis.
- [ ] Rotação e redimensionamento da janela (web) reposicionam; cruzar 720 px
      troca o alvo do passo do menu pra barra lateral.
- [ ] Estados vazios: um motivo por página como na tabela 4; botão leva ao
      formulário com o campo focado; vazio filtrado continua só texto +
      "Limpar filtro".
- [ ] Cartão "Primeiros passos" risca cada passo feito e some com os três.
- [ ] Chevron em chip tonal no título e no título fixo; título com 48 dp de
      altura de toque.

Acessibilidade e movimento
- [ ] TalkBack (Android) e leitor da web: foco vai pro balão, anúncio com
      página e "passo X de Y", fundo inacessível durante o tutorial.
- [ ] Web: Tab percorre Próximo/Pular, Enter ativa, Esc pula.
- [ ] Remover animações ligado: nenhuma animação de deslize ou subida.
- [ ] Ilustrações dos vazios e o selo não são lidos pelo leitor de tela.

Texto
- [ ] Todos os passos em pt-BR e en, conferidos com a seção 3; nada de
      exclamação ou emoji; termos do app (caixinha, receita, gasto, saldo).

### 7.2 Decisões que precisam do Felipe

1. **Direção:** A "Lanterna" (recomendada), B "Etiqueta", ou A no geral com B
   só em Receitas e Gastos?
2. **Passo guiado pela ação no menu:** tocar no título durante o passo 1 do
   Dashboard abre o menu de verdade e encerra o tutorial. Pode, ou prefere o
   tour todo só com "Próximo"?
3. **Voltar do sistema durante o tutorial** = Pular (marca visto)? Alternativa:
   fecha sem marcar e reaparece na próxima vez (risco de irritar).
4. **Ações de lançar no Dashboard** (seção 6, item 3): entra junto com o
   onboarding? E dois botões ou FAB?
5. **Versão por tutorial:** guardar a versão pra reexibir um tutorial quando a
   página mudar muito? Custa um campo a mais no perfil.
6. **Nome "Dashboard" no app em português:** os textos falam "Dashboard"
   porque é o nome da tela; se um dia virar "Início", os passos mudam junto.
7. **Ícone de linha calendário em Assinaturas:** não existe no manual. Aprovar
   (e registrar no manual, nos dois vaults) ou trocar por outro do repertório
   (ex.: ícone casa, pelo aluguel)?
8. **Cartão "Primeiros passos"** substituindo o vazio de Caixinhas no
   Dashboard: aprovado? Some sozinho com os três passos feitos, ou também tem
   um "Dispensar"?
9. **Selo com D ao completar os 7 tutoriais:** aprovado como o único ponto
   terracota do onboarding?
10. **Barra inferior** (seção 6, item 4): fica só como plano B, condicionada a
    medir a primeira receita lançada? Se sim, definir qual evento do Analytics
    mede isso.
11. **Ordem dos passos do Dashboard:** o menu vem primeiro (pra quem pula
    cedo). Se preferir uma narrativa (conta → Alocar → caixinhas → menu),
    trocar.

---

## 8. Decisões tomadas (2026-11-12)

Decidido pelo Felipe:

1. **Direção A "Lanterna" em tudo**, sem a B em nenhuma página, incluindo o único passo guiado pela ação (o do menu, no Dashboard, decisão 2).

Assumido pelo Claude como padrão, por ser a recomendação deste documento e fácil de reverter (o Felipe ainda pode trocar):

- **Decisão 3:** voltar do sistema durante o tutorial = Pular (marca como visto). Reaparecer a cada abertura irritaria mais do que perder um tutorial.
- **Decisão 5:** guardar a versão de cada tutorial no perfil (um número por página), pra poder reexibir um tutorial quando a página mudar muito.
- **Decisão 11:** a ordem dos passos do Dashboard é a do documento (menu primeiro).
- **Decisão 6:** os textos seguem chamando a tela de "Dashboard".

Ainda **sem decisão** (ficam pra fase dos estados vazios e da navegação; nada disso é construído antes de o Felipe responder): 4 (botões de lançar no Dashboard), 7 (ícone de calendário fora do manual), 8 (cartão "Primeiros passos"), 9 (selo ao completar os 7) e 10 (barra inferior).

## 9. Ordem de implementação

1. Base: progresso por página (perfil + cópia local), motor do tutorial (rota modal com recorte) e o balão no formato do cartão de passo.
2. Tutorial do Dashboard (4 passos) como primeiro uso.
3. Seção "Tutoriais" em Ajustes.
4. Tutoriais das outras páginas.
5. Estados vazios e navegação mais descobrível (depende das decisões em aberto).
