# Pendências (PENDENCIAS)

**[Read in English](PENDENCIAS.md)**

O que ainda está em aberto no Dindin, no formato da convenção do Forge:
pendências, riscos aceitos, dependências e todo `TODO: confirmar` deixado nos
docs. Reconciliado com o código e os docs em 2026-11-16 (versão 1.2.1+7). Os
outros docs apontam pra cá em vez de repetir estes itens. Onde um item vem do
board mantido fora deste repositório, está dito; esses não puderam ser
reverificados no código.

Gravidade: `bloqueia lançamento`, `importante`, `menor`.

## Em aberto

- [ ] A 1.2.1+7 foi enviada à Play e aguarda a análise do Google; registrar o
  resultado em `docs/DEPLOY.pt-br.md` (tabela de versões publicadas) quando for
  aprovada. _origem:_ docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Não verificado em aparelho real: o onboarding.** Sete tutoriais
  (`lib/widgets/tutorial/`), estados vazios guiados, cartão "Primeiros passos",
  selo de cera em Ajustes → Tutoriais, chip e descrições do menu, popup de
  lançamento rápido. Evidência até aqui: widget tests, testes das rules no
  emulador, capturas renderizadas. Falta: TalkBack, rotação, fonte grande do
  sistema, teclado físico e desempenho do véu num celular.
  _origem:_ mobile/docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Não verificado em aparelho real: seletor de tema e animação de abertura**
  (`lib/widgets/splash_gate.dart`), incluindo o possível flash branco/preto da
  janela nativa antes do primeiro quadro do Flutter, e o rótulo "Sistema" sem
  quebrar em 320-360 px (só medido em testes).
  _origem:_ mobile/docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Não verificada: a atualização in-app.** O indicador fixo (ponto + item
  "Atualizar" no menu) nunca foi visto num aparelho, porque exige um build
  instalado pela Play com uma versão mais nova publicada; o download da
  atualização flexible e o snackbar "Reiniciar" só rodam contra o plugin real da
  Play e são testados apenas com um serviço falso.
  _origem:_ mobile/docs, 2026-11-16. _gravidade:_ importante.
- [ ] **Tema claro e conformidade com o manual de marca só em parte conferidos.**
  Os tokens batem com o manual (2026-11-12). Renderizados e conferidos: Ajustes e
  Categorias. Não conferidos: gráficos do Dashboard, Receitas, Gastos,
  Assinaturas, Parcelamentos, login e diálogos, e o app num aparelho.
  _origem:_ design, 2026-11-12. _gravidade:_ menor.
- [ ] **Play Console: declarar o status de comerciante até 2027-02-01.** É da
  conta de desenvolvedor, vale pra todos os apps dela; sem declarar, o perfil e os
  apps saem da Play no mundo todo. A escolha e os dados públicos do perfil são do
  mantenedor. Ver `docs/PLAY_CONSOLE.pt-br.md`. _origem:_ board, 2026-11-16.
  _gravidade:_ importante (prazo firme).
- [ ] **O "Enforce" do App Check não está ligado** no Firestore/Authentication.
  Observar antes as métricas de App Check no Firebase Console (requisições do
  Android verificadas); o Enforce também barraria o cliente web (sem App Check na
  web), então decidir isso antes. Confirmar também o projeto do Google Cloud
  vinculado ao Play Integrity. Ver `docs/BACKEND.pt-br.md`, "App Check".
  _origem:_ board, 2026-11-11. _gravidade:_ importante.
- [ ] **App Check na web** adiado (precisa de chave reCAPTCHA v3; a alternativa
  Enterprise exige faturamento). `_recaptchaV3SiteKey` em `lib/main.dart` é um
  placeholder. _origem:_ decisão de 2026-09-21. _gravidade:_ menor.
- [ ] **`accountDeletionLog` sem TTL** enquanto a Política de Privacidade promete
  5 anos de retenção, não "para sempre". Passo de console/infra (TTL nativo em
  `deletedAt`); não é necessário pra promessa valer hoje. Ver
  `docs/BACKEND.pt-br.md`. _origem:_ backend, 2026-09-23. _gravidade:_ menor.
- [ ] **Lacuna de monitoramento:** sem checagem de disponibilidade e sem
  Crashlytics/Sentry; erros que não derrubam o app ficam invisíveis. Ver
  `docs/DEPLOY.pt-br.md`, "Monitoramento". _origem:_ devops. _gravidade:_ menor.
- [ ] **Erros de stream sem UI dedicada:** um stream do Firestore negado ou
  quebrado parece "ainda carregando" na maioria das telas (o Dashboard mostra uma
  tela de tentar de novo). Nenhuma está planejada (mantenedor, 2026-11-16). Ver `docs/BACKEND.pt-br.md`,
  "Superfície de integração". _origem:_ backend. _gravidade:_ menor.
- [ ] **Excluir a conta ainda exige sair e entrar quando o login é antigo**
  (`hasRecentLogin`); reautenticar na hora é uma melhoria de UX não feita.
  _origem:_ board, 2026-11-10. _gravidade:_ menor.
- [ ] **Scripts de operação autenticam como a conta Google pessoal do
  mantenedor** (`scripts/deploy.sh`, `sweep_orphans.mjs`), não uma service account
  com escopo; a política da organização bloqueia chave de service account, então o
  caminho certo é impersonation sem chave. Mexe em IAM real: só o mantenedor.
  _origem:_ board, 2026-09-23. _gravidade:_ menor.
- [ ] **Sem projeto Firebase separado de dev/prod** (só `dindin-cafelabs`).
  _origem:_ board. _gravidade:_ menor.
- [ ] **Comentários desatualizados em `lib/`** (não editados, passada só de docs):
  o comentário de App Check em `lib/main.dart` diz que o app ainda não está no Play
  Console; `lib/widgets/app_shell.dart` cita um `FLUTTER_MIGRATION.md` que não
  existe mais. _origem:_ docs, 2026-11-16. _gravidade:_ menor.

## Riscos aceitos

- **Teto da Option B (integridade só por rules):** um cliente pode reescrever os
  próprios docs de saldo, e o "descongelar via teardown" pode recriar um saldo
  negativo na própria caixinha `spend`. Dado de um único dono, os saldos exibidos
  são re-somados do ledger, então isso só restringe as escritas dessa mesma
  pessoa. Aceito pelo mantenedor quando a Option B foi escolhida em vez de Cloud
  Functions/Blaze (custo). Detalhes: `docs/BACKEND.pt-br.md`.
- **O Dashboard re-soma o ledger inteiro** a cada sessão e snapshot: mais leituras
  e memória em contas grandes, em troca de um saldo que não pode ser subcontado. A
  rever se houver contas com dezenas de milhares de linhas (e a cota diária de
  leituras do Spark). Decidido no código (`summaryProvider`);
  `docs/BACKEND.pt-br.md`, "O saldo do Dashboard re-soma o ledger".
- **Escritas simples são dadas como enviadas após 4 s offline (`ackOrQueue`)**:
  uma negação das rules que chegue depois dessa janela já não pode ser mostrada à
  pessoa.
- **Sem rollback na Google Play** (só pausar um lançamento em etapas ou corrigir
  pra frente) e uma regressão de rules atinge web e Android juntos; mitigado pelo
  `scripts/deploy.sh` e pelo backup antes do deploy. `docs/DEPLOY.pt-br.md`.
- **Plano Spark, sem Blaze:** cobranças de assinatura/parcelamento só são lançadas
  quando o app é aberto, nunca por agendamento no servidor. Decisão do mantenedor;
  rever junto com a ideia de migrar pro Blaze.

## Dependências

- **Projeto Firebase `dindin-cafelabs`:** Auth (e-mail/senha, Google), Firestore
  (São Paulo), Hosting (web), Analytics, App Check. Plano Spark.
- **Configuração OAuth do Google Cloud** para o login com Google (SHA-1/SHA-256 das
  chaves de debug, de upload e do Play App Signing): `docs/PLAY_CONSOLE.pt-br.md`.
- **Google Play Console**, pacote `com.cafelabs.dindin` (permanente), conta de
  desenvolvedor pessoa física; **keystore de upload fora do repo**, referenciado
  pelo `android/key.properties` não versionado.
- **Ferramentas:** Flutter 3.44.4 (fixado na CI), Node 20 para os scripts e o
  harness das rules, `firebase-tools` e JDK 21 para o emulador do Firestore.
- **Domínios:** `dindin.cafelabs.net` (landing e páginas legais públicas, repo
  `dindin-landing`), `app.dindin.cafelabs.net` (app web).
- **Consumido por / refletido em outros projetos (avisar o mantenedor, não
  editá-los sozinho):** `dindin-landing` (descrição das funcionalidades, botão da
  Play, logo, páginas legais), o card do Dindin no `cafelabs-portifolio` e o manual
  de marca no `cafelabs-vault` (`marca/dindin/`, que este repo só referencia).
  Mudança de funcionalidade, paleta, logo ou links aqui provavelmente pede
  atualização equivalente lá.
- **Inativo:** `functions/` (Cloud Functions, Option A) não está deployado e não
  tem callables de assinaturas nem de parcelamentos.

## Para confirmar

Respondido pelo mantenedor em 2026-11-16 e já aplicado: `/privacidade`,
`/termos` e `/excluir-conta` respondem em produção; a pasta `windows/` foi
apagada; não há UI dedicada de erro de stream planejada.

- `docs/DEPLOY.pt-br.md`: se cada release usou lançamento em etapas (e em que
  porcentagem; o mantenedor não lembra, dá para ver em Play Console → Testar e
  lançar → Produção → histórico de versões); o histórico dos `versionCode`s 1-2
  (desconhecido, só registro); se a grafia do `<title>` de `web/index.html` foi
  resolvida.
- `docs/ARQUITETURA.pt-br.md`: se o comentário `FLUTTER_MIGRATION.md` em
  `lib/widgets/app_shell.dart` deve ser removido ou mantido como histórico.
