# Deploy, CI e rollback

**[Read in English](DEPLOY.md)**

Guia operacional pra um mantenedor solo rodar/debugar o deploy do Dindin sem
reconstruir contexto. Ler `docs/BACKEND.pt-br.md` primeiro pro *porquê* a
ordem de deploy é a que é — este arquivo é o *como*, mais CI e rollback.

Dois canais de distribuição saem deste mesmo repositório, e eles não se
parecem em nada:

| | Web (Firebase Hosting) | Android (Google Play) |
|---|---|---|
| Como | `scripts/deploy.sh` / `firebase deploy` | `scripts/release_android.sh` + upload manual no Play Console |
| Tempo até o usuário | segundos | minutos a dias (revisão do Google) |
| Rollback | alguns cliques, instantâneo | **nenhum** — ver "Rollback no Play" |
| Custo | grátis (Spark) | US$ 25 uma vez, já pago |

Por causa dessa terceira linha, vale ler a seção de Android inteira **antes**
do primeiro upload, não durante.

## CI (`.github/workflows/ci.yml`)

Roda em todo push pra `main`, e também manualmente pelo "Run workflow"
(`workflow_dispatch`). Três jobs independentes. **Custo: zero e sem teto** —
`github.com/CafeLabsCorp/dindin` é um repositório público, então os minutos do
Actions não são medidos e não existe superfície de cobrança aqui. (Se um dia
virar privado, o teto grátis é 2.000 min/mês e o job `android` abaixo é o caro,
~10 min por rodada.)

- **`flutter`** — `flutter pub get && flutter analyze && flutter test`.
  Agnóstico de plataforma: **não** compila o target Android nem o Windows.
- **`rules`** — sobe o emulador do Firestore (`firebase-tools
  emulators:exec`) e roda `npm test` em `test/rules/`, que é
  `rules.test.mjs` (regras de segurança — integridade de dinheiro da Fase 2,
  incluindo os caminhos `getAfter()`/null-teardown que não podem ser
  exercitados a partir do Dart; dezenas de casos em 8 blocos `describe`) **e**
  `backfill.test.mjs` (classificação de dívida-legítima-vs-corrupção do
  `scripts/backfill_balances.mjs`, rodado como subprocesso real contra o
  mesmo emulador), os dois numa passada só. Usa só o emulador — nunca toca
  produção, não precisa de credenciais de projeto.
- **`android`** — `flutter build appbundle --release`. Como `flutter
  analyze`/`flutter test` nunca encostam no Gradle, sem este job um manifest,
  plugin ou upgrade de AGP quebrado só apareceria no dia do release, na mão, sob
  pressão. Ele **não guarda nenhum segredo**: `android/key.properties` não está
  no repo, então o build cai no fallback da chave de debug (o que também prova
  que esse fallback continua funcionando pra clones novos), e o bundle
  resultante deliberadamente **não** é publicado como artifact — um `.aab`
  assinado com a chave de debug é inútil e ninguém deve ser tentado a subir um.
  O job também verifica que a linha de versão do `pubspec.yaml` ainda casa com
  `<nome>+<código>`.

CI **não** faz deploy de nada — nem pro Firebase Hosting, nem pro Google Play.
É uma rede de segurança pro código; publicar em produção continua sendo a ação
manual deliberada abaixo.

Pra debugar uma falha de CI localmente, rodar os mesmos comandos: `flutter
analyze`, `flutter test`, `flutter build appbundle --release`, ou `firebase
emulators:exec --only firestore --project dindin-rules-test "npm test --prefix
test/rules"` (ver o cabeçalho de `test/rules/rules.test.mjs` pra variante
manual de dois terminais).

### Por que o upload pro Play é manual

Decisão deliberada, não uma pendência. Automatizar significaria colocar o
**keystore de upload e suas senhas nos secrets do GitHub Actions**, mais uma
chave de service account de vida longa pra Play Developer API — ou seja, mover
o único segredo cujo comprometimento é de fato caro pra um segundo lugar,
controlado por terceiro, num repositório **público**, pra economizar uns dois
minutos de um primeiro release que no resto são várias horas de trabalho manual
no console (verificação de identidade, ficha da loja, formulário de segurança
de dados, classificação indicativa, um teste fechado de 14 dias). Numa cadência
de MVP medida em semanas, essa automação apodreceria antes de se pagar — e a
primeira execução de um caminho de release deveria ser uma que um humano
acompanhou de ponta a ponta.

Revisitar quando os releases virarem semanais ou mais frequentes, ou quando uma
segunda pessoa precisar conseguir publicar. Aí o formato certo é um job só com
`workflow_dispatch`, usando `fastlane supply` e o keystore em base64 nos
secrets — nunca um job disparado por push.

## Fazendo deploy (`scripts/deploy.sh`)

Codifica a ordem obrigatória de release de `docs/BACKEND.pt-br.md` como um
script com gates rígidos, pra que um passo não possa ser pulado ou
reordenado por acidente:

1. Confirmação interativa de que o backup manual dos dados (Ajustes ->
   Exportar JSON, por usuário real) foi feito. Aborta se não confirmado.
2. Dry-run do backfill (`backfill_balances.mjs --dry-run`); aborta se a
   saída contiver o marcador `BALANCE CORRUPTION` — um saldo negativo que
   nunca deveria existir (a conta geral, uma caixinha `save`, ou um id
   órfão). Uma dívida aberta/congelada legítima numa caixinha `spend` (a
   feature `allowNegative`) imprime como um aviso "open debt" SEM esse
   marcador e NÃO bloqueia o deploy — ver `docs/BACKEND.pt-br.md`, "Option
   B residual limitations" pra como o script diferencia os dois casos.
3. Confirmação interativa final antes de qualquer escrita/deploy real.
4. Rodada real do backfill (idempotente).
5. Preflight: `backfill_balances.mjs --verify` — confirma que todo
   `/users/{uid}` tem um doc `meta/account`. Aborta antes de tocar as
   rules se alguém estiver sem um.
6. `firebase deploy --only firestore:rules --project dindin-cafelabs`.
7. `flutter build web` + `firebase deploy --only hosting --project
   dindin-cafelabs`.

Rodar a partir da raiz do repo:

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project dindin-cafelabs
scripts/deploy.sh
```

O `deploy.sh` acha essas credenciais sozinho — não precisa exportar nada.

**Por que ADC e não uma chave de service account:** a política da organização
neste projeto (`iam.disableServiceAccountKeyCreation`) **bloqueia** criar
chave JSON de service account. O console recusa com "Não é permitido criar
chaves nesta conta de serviço", então o caminho da chave não está disponível
a menos que alguém levante a política. Credencial de usuário via ADC funciona
igual pro `firebase-admin`, com uma diferença: ela não carrega projeto
embutido, então o `GOOGLE_CLOUD_PROJECT` é necessário — o script já cuida
disso. Se você tiver uma chave vinda de outro lugar, `export
GOOGLE_APPLICATION_CREDENTIALS=/caminho/abs/pra/serviceAccount.json` continua
funcionando (nunca commitar isso).

A organização também exige reautenticação periódica: se aparecer
`invalid_rapt` ou `invalid_grant`, é só repetir o
`gcloud auth application-default login`.

Esse script é pensado pra uso interativo, manual, durante um release — não
roda em CI. Se você só precisa publicar uma mudança só de hosting (sem
mudança de rules/schema), a sequência manual antiga continua válida e
segura:

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

(Pular `scripts/deploy.sh` inteiramente pra mudanças puras de UI — o gate de
backup/backfill existe especificamente pra mudanças que tocam
`firestore.rules` ou os docs de saldo, não todo deploy.)

## Release Android (Google Play)

Web e Android saem deste mesmo repositório, mas por dois pipelines com
propriedades opostas. O deploy web é reversível em alguns cliques; **um release
no Play não é reversível de jeito nenhum** — ver "Rollback no Play" abaixo. Ler
essa parte antes do primeiro upload, não depois.

### Duas chaves, e só uma delas é sua

Apps novos no Play usam **Google Play App Signing**, e isso não é opcional.
Isso divide a assinatura em duas chaves, e confundir as duas é o erro mais caro
disponível aqui:

| | Chave de upload | Chave de assinatura do app |
|---|---|---|
| Quem tem | Você (Felipe), no keystore gerado abaixo | O Google, no Play Console. Você nunca vê a chave privada |
| O que assina | O `.aab` que você sobe | Os APKs que o Google gera e entrega aos aparelhos |
| Se perder | Recuperável — o suporte do Play reseta e você registra outra. Dias de fricção, não é fatal | Nunca se perde, nunca muda, nunca é substituída |
| Onde o SHA-1 dela importa | Builds locais e `flutter run` | **Toda instalação vinda do Play** |

Consequências práticas:

1. **Faça backup do keystore de upload mesmo assim.** "Recuperável via
   suporte" não é algo que você quer descobrir que precisa no dia de um
   hotfix.
2. **Por padrão o Google Sign-In fica registrado contra a chave errada.** O
   Play reassina o app com a *chave de assinatura do app*, então o SHA-1 que o
   Firebase precisa conhecer é o dela, copiado do Play Console depois do
   primeiro upload. Se só o SHA-1 da sua chave de upload/debug estiver
   registrado, o login funciona perfeitamente na sua máquina e falha com
   `ApiException: 10 (DEVELOPER_ERROR)` pra todo usuário que instalou pela
   loja. Hoje isso está sem registro nenhum — ver "Resolver antes do primeiro
   upload".

### Gerar a chave de upload (uma vez, só o mantenedor)

Ninguém mais — nenhum agente, nenhuma CI, nenhum colaborador — deve rodar isto
ou ter o resultado. Rodar uma vez, na sua própria máquina, fora do repositório:

```bash
mkdir -p ~/keys/dindin
keytool -genkey -v \
  -keystore ~/keys/dindin/dindin-upload-key.jks \
  -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias upload
```

O `keytool` vem com o JDK (já instalado por causa do emulador do Firestore).
Ele pergunta a senha do keystore, a senha da chave, e um distinguished name
(seu nome / org / cidade servem; nada disso é mostrado a usuários). `-validity
10000` é ~27 anos — o Play exige que o certificado siga válido bem depois de
2033, então não encurte. O `keytool` vai avisar que JKS é um formato
proprietário; PKCS12 (`-storetype PKCS12`) funciona igual com o Gradle, se
preferir — só manter o caminho no `key.properties` coerente.

Depois, apontar o build pra ele:

```bash
cp android/key.properties.example android/key.properties
# editar android/key.properties: caminho ABSOLUTO do storeFile + as duas senhas
```

`android/key.properties` está no gitignore em dois lugares
(`android/.gitignore` e o `.gitignore` da raiz) e **este repositório é
público** — nunca mova o keystore pra dentro da working tree, nunca cole uma
senha num commit, numa issue, ou num log de CI. O
`scripts/release_android.sh` se recusa a buildar se o caminho do `storeFile`
resolver pra dentro do repo.

O `android/app/build.gradle.kts` lê esse arquivo. Se ele não existir — clone
novo, CI, qualquer pessoa que não seja você — os builds de release caem na
chave de debug e imprimem um aviso barulhento em vez de falhar, então o projeto
continua buildando e testando pra todo mundo. Um bundle assinado com a chave de
debug é rejeitado pelo Play, então esse fallback não consegue produzir
silenciosamente um release "de verdade".

### Backup do keystore

O arquivo do keystore **e** as senhas dele são uma coisa só: um keystore cuja
senha se perdeu é um keystore perdido. Faça backup dos dois, num lugar que não
seja este repo e que não seja repositório git nenhum (o git nunca esquece um
arquivo, mesmo apagado depois):

- O `.jks` → o Google Drive da empresa, mesmo raciocínio dos PDFs de contrato,
  mais uma cópia offline (pendrive/HD externo).
- As duas senhas e o alias (`upload`) → o gerenciador de senhas, numa entrada
  que também aponte onde o `.jks` está.
- Anote também as fingerprints, pra conseguir identificar a chave depois sem
  abrir o arquivo:
  ```bash
  keytool -list -v -keystore ~/keys/dindin/dindin-upload-key.jks -alias upload
  ```

**Teste o restore uma vez.** Baixe a cópia de backup pra um diretório
qualquer e rode o `keytool -list -v` acima contra *essa cópia*, com a senha
lida do gerenciador. Um backup que nunca foi aberto é uma hipótese, não um
backup.

### Versionamento

O `version: <versionName>+<versionCode>` do `pubspec.yaml` alimenta os dois
canais, mas as duas metades não significam a mesma coisa:

- **`versionName`** (`1.0.0`) — a versão semântica do produto, compartilhada
  por Web, Android e Windows. É o número que o humano vê.
- **`versionCode`** (`+1`) — **só Android**. Um contador monotônico de
  artefatos enviados ao Play. O Play recusa qualquer upload cujo código não
  seja estritamente maior que todos os já enviados pra este app, *inclusive*
  builds que só foram pro teste interno e builds que foram rejeitados. Nunca
  pode ser reusado nem diminuído, pelo resto da vida da ficha.

Ou seja: `flutter build web` ignora o `versionCode` completamente. Subir o
código sem publicar web, ou publicar web sem subir o código, são as duas coisas
normais — ele conta uploads no Play, não releases de produto. Não migre pra
código baseado em data (`20260827`): limita você a um upload por dia e queima o
espaço de inteiros de forma irreversível.

**Primeiro release no Play: `1.0.0+1`.** Nada nunca foi enviado, então o código
1 ainda está livre. O `scripts/release_android.sh` sobe o código pra você; a CI
verifica que a linha continua casando com `<major>.<minor>.<patch>+<código>`.

### Buildar o App Bundle

O Play exige um **Android App Bundle** (`.aab`) pra apps novos. `flutter build
apk` serve só pra sideload e distribuição direta — nunca pra loja.

O caminho scriptado, que é o que se deve usar:

```bash
scripts/release_android.sh                 # +1 no versionCode, depois builda
scripts/release_android.sh --version 1.1.0 # também define um versionName novo
scripts/release_android.sh --no-bump       # rebuilda o mesmo versionCode
```

Ele se recusa a começar sem `android/key.properties`, recusa keystore guardado
dentro do repo, sobe o `pubspec.yaml`, roda o mesmo `analyze`/`test` que a CI
roda, builda, e depois lê o certificado do assinante de volta de dentro do
bundle gerado pra provar que ele não está assinado com a chave de debug. Ele não
commita, não dá push e não sobe nada. Revise o `git diff pubspec.yaml` e
commite o bump você mesmo.

O equivalente manual, se precisar debugar algum passo:

```bash
flutter pub get
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
unzip -p build/app/outputs/bundle/release/app-release.aab 'META-INF/*.RSA' \
  | keytool -printcert | head -2      # NÃO pode dizer CN=Android Debug
```

O bundle tem ~60 MB, mas esse não é o tamanho do download: cerca de metade é
metadado de símbolos de debug por ABI que o Play remove antes de entregar, e o
Play ainda serve pra cada aparelho só a ABI dele. Espere bem menos de 20 MB pro
usuário.

**Builds de release passam por minificação e shrink de recursos (R8); builds de
debug não.** O que o R8 removeu está listado em
`build/app/outputs/mapping/release/usage.txt`. Isso é uma diferença de
comportamento real em relação a todo build já rodado neste app até hoje, então
antes do primeiro upload instale o artefato de release num aparelho físico e
exercite o Google Sign-In, uma leitura e uma escrita no Firestore, e o
export/import de JSON ida e volta. `flutter build apk --release` + `adb
install` é o jeito mais rápido de testar o mesmo caminho de código (o `.aab` em
si não é instalável direto; `bundletool build-apks --local-testing` é a
alternativa de fidelidade exata, se quiser).

### Ofuscação e arquivos de símbolo — desligados de propósito

`--obfuscate --split-debug-info` **não** é usado aqui, e isso é uma decisão, não
um esquecimento:

- O AAB já envia ao Play os símbolos nativos completos, por ABI
  (`BUNDLE-METADATA/com.android.tools.build.debugsymbols/*/libapp.so.sym`),
  mais o mapping do R8 (`.../obfuscation/proguard.map`). O Play Console
  simboliza os relatórios de crash a partir disso automaticamente, sem nenhum
  trabalho de arquivamento da sua parte.
- Ligar a ofuscação move a resolução de símbolos Dart pra *fora*, pra arquivos
  `app.android-arm64.symbols` que teriam que ser arquivados, por release, pra
  sempre, ao lado do backup do keystore. Perdeu, todo crash daquela versão fica
  ilegível permanentemente. Isso é um modo de falha irrecuperável novo pra um
  mantenedor solo, comprado por muito pouco.
- Não há segredo nenhum no cliente pra proteger. A config do Firebase em
  `lib/firebase_options.dart` e `android/app/google-services.json` é pública
  por design; a fronteira de acesso é o `firestore.rules` (ver
  `docs/BACKEND.pt-br.md`), e ofuscação não faz nada por isso.

Revisitar só quando houver um coletor de crashes (Crashlytics/Sentry) ligado
*e* o upload de símbolos automatizado. Se for ligar, o comando é `flutter build
appbundle --release --obfuscate
--split-debug-info=~/keys/dindin/symbols/<versionName>+<versionCode>/` — repare
que o caminho é fora do repo, versionado por build, e precisa do mesmo rigor de
backup que o keystore.

### Runbook de upload (primeiro release)

Os passos 1 e 2 dependem do Google e são o caminho crítico — comece por eles.

1. **Verificação de identidade.** A conta de desenvolvedor é pessoa física
   (Felipe Portes Antunes, aberta em 25/08/2026). Enquanto o Google não
   terminar de verificar identidade e endereço, você não consegue nem criar a
   ficha do app. Nada abaixo é acionável até isso sair.
2. **Exigência de teste fechado.** Contas de pessoa física criadas depois de
   13/11/2023 precisam rodar um teste fechado com um número mínimo de testers
   inscritos por 14 dias contínuos antes de poder pedir acesso à produção. O
   Google já mudou esse número pelo menos uma vez (era 20, depois 12) — leia o
   número atual no seu próprio Play Console em vez de confiar neste documento.
   Reserve ~3 semanas de calendário e recrute testers desde já; é quase sempre
   isso que de fato atrasa um primeiro lançamento.
3. **Criar o app** no Play Console: nome, idioma padrão (pt-BR), app (não
   jogo), gratuito.
4. **Assets da ficha da loja** — nenhum deles mora neste repo, todos são
   enviados no console:
   - ícone do app, PNG 512x512 32-bit, sem transparência, sem cantos
     arredondados embutidos (gerar a partir de `assets/icon/logo_1024.png`);
   - feature graphic, 1024x500;
   - no mínimo 2 screenshots de celular;
   - descrição curta (80 caracteres) e completa (4000);
   - **uma URL pública de política de privacidade** — obrigatória aqui, porque
     o app exige conta e lida com dados financeiros. `dindin.cafelabs.net` é o
     lugar natural. É bloqueante e não tem contorno.
5. **Formulário de segurança de dados.** Declarar, no mínimo: e-mail e nome
   (coletados via Firebase Auth / Google Sign-In) e informação financeira (o
   ledger digitado pelo usuário), armazenados no Firebase, criptografados em
   trânsito. Apps que permitem criar conta também precisam oferecer um
   **caminho de exclusão de conta** — dentro do app e como URL pública.
   Confirme que existe antes de preencher; declaração falsa aqui é violação de
   política, não deslize burocrático.
6. **Classificação indicativa**, **público-alvo**, declaração de anúncios (não
   tem).
7. **Subir o `.aab`** numa trilha: Testar e lançar → (Teste interno → Teste
   fechado → Produção) → Criar novo lançamento → enviar
   `build/app/outputs/bundle/release/app-release.aab`.
8. **Imediatamente depois do primeiro upload**, antes de deixar alguém
   instalar: Play Console → Testar e lançar → Configuração → Assinatura de app
   → copiar o **SHA-1 do certificado da chave de assinatura do app** → console
   do Firebase → Configurações do projeto → seu app Android → Adicionar
   impressão digital → colar → **rebaixar o `google-services.json` pra
   `android/app/`** e commitar. Sem isso, o Google Sign-In falha pra toda
   instalação vinda da loja. Adicione também o SHA-1 da sua chave de upload,
   pra que APKs de release buildados localmente continuem funcionando.
9. **Lançar em etapas**, não em 100% — ver abaixo.

Num release rotineiro posterior, só os passos 7 e 9 se aplicam.

### Rollback no Play — não existe

Dizendo sem rodeio, porque o hábito vindo do hosting não se transfere: **você
não pode despublicar, apagar nem reverter uma versão que já chegou aos
usuários.** Quem já atualizou está com o build quebrado e o Play não vai tirar
isso dele.

As três alavancas que existem de fato:

- **Interromper o lançamento (halt rollout).** Só faz sentido se o release
  estiver em lançamento *em etapas*: para a distribuição pra novos usuários na
  porcentagem em que estiver. Quem já recebeu, fica com ele. É o mais parecido
  com rollback que existe, e só existe se você tiver escolhido etapas antes.
- **Rolar pra frente.** Corrigir, subir o `versionCode`, enviar, lançar. É o
  caminho real de recuperação. No melhor caso é uma hora; um release novo
  também pode ficar um dia ou mais na revisão do Google, e você não controla
  qual dos dois será.
- **Relançar o build anterior.** Permitido, mas o `versionCode` antigo está
  queimado pra sempre — você precisa subir aquele mesmo código sob um
  `versionCode` *novo*, maior.

O que significa, na prática:

- **Sempre lance em etapas** (comece em 10–20%, acompanhe o Android vitals por
  um dia, depois amplie). É grátis, é a única ferramenta com formato de
  rollback que o Play dá, e é escolhida na hora do lançamento — não dá pra
  acrescentar depois.
- **O app web é o canal de correção rápida.**
  `app.dindin.cafelabs.net` roda o mesmo código, contra os mesmos dados no
  Firestore e as mesmas contas, e volta atrás em alguns cliques. Se um release
  Android estiver quebrado e a correção estiver presa na revisão, apontar os
  usuários afetados pro web é uma mitigação real.
- **Uma regressão no `firestore.rules` quebra os dois clientes de uma vez**, e
  só o rollback das rules (abaixo) resolve — rolar pra frente no Android não
  resolveria, e nem chegaria a tempo. Essa assimetria é justamente o motivo de
  mudanças de rules passarem pelo `scripts/deploy.sh` e não por um release de
  app.

### E os dados continuam não voltando

Tudo em "Dados do usuário" abaixo continua valendo, só que pior: um release web
que corrompe dados pode ser parado em minutos, um Android não pode ser puxado
de volta dos aparelhos que já estão rodando. A exportação JSON por usuário
feita no passo 1 do `scripts/deploy.sh` continua sendo o único caminho de
restore — faça também antes de um release Android que toque no schema do
ledger, mesmo que o release Android em si não rode aquele script.

## Rollback

### Firestore rules

O arquivo de rules anterior vive no histórico do git — esse é todo o
caminho de rollback, sem backup separado necessário:

```bash
git log --oneline -- firestore.rules        # achar o último commit bom
git show <commit-bom>:firestore.rules > firestore.rules
firebase deploy --only firestore:rules --project dindin-cafelabs
git checkout -- firestore.rules             # restaurar a working tree depois
```

Isso só toca as rules — não afeta os docs de saldo escritos pelo backfill,
que continuam válidos sob qualquer versão de rules (as rules da Fase 1
simplesmente não os checam).

### Hosting (cliente web)

O Firebase Hosting mantém releases anteriores automaticamente. Pra fazer
rollback sem rebuild:

- Console do Firebase -> Hosting -> seu site -> "Release history" -> escolher
  o release anterior -> **Rollback**. São alguns cliques, sem precisar de
  CLI, e é o caminho mais rápido de volta a um cliente conhecido-bom.
- Ou pela CLI: `firebase hosting:clone <site>:<id-do-release-anterior>
  <site>:live --project dindin-cafelabs`.

### Dados do usuário

O **único** rollback pros dados do usuário é a exportação manual de JSON
feita durante o passo de backup do deploy-gate (`scripts/deploy.sh` passo 1
/ `docs/BACKEND.pt-br.md`). Pra restaurar: abrir o app, logar como o
usuário afetado, Ajustes -> Importar JSON, escolher o arquivo de backup.
Isso substitui as seis coleções de ledger daquele usuário e reseta os
docs de saldo a partir do ledger importado — não há restore parcial/
seletivo, então usar a exportação boa mais recente.

Não há backup automatizado point-in-time do Firestore em si (o tier
Spark/grátis não tem produto de export agendado) — a exportação JSON por
usuário é toda a história de durabilidade de dados agora. Se o uso crescer
o bastante pra "pedir pra cada usuário ter exportado recentemente" deixar
de ser uma barra aceitável, revisitar um export agendado (tier Blaze
`gcloud firestore export` pro Cloud Storage, ou um dump scriptado com o
Admin SDK) — fora do escopo deste ciclo de MVP.

## Monitoramento — gap atual, próximo passo recomendado (não configurado neste ciclo)

O escopo deste ciclo foi CI + o gate de backup/rollback. Marcando
explicitamente: **não há hoje visibilidade de uptime ou taxa de erro no app
em produção** — uma queda ou um pico de escritas rejeitadas (ex.: de uma
regressão de rules) só seria descoberto por um report de usuário. Isso é
uma lacuna aceitável e deliberada pras mudanças de código que saem *neste*
ciclo (mudanças de rules são aditivas/retrocompatíveis conforme
`docs/BACKEND.pt-br.md` e foram verificadas contra o emulador), mas não
deve continuar sem endereçamento por muito tempo conforme usuários reais
passam a depender deste app. Opções mais baratas, em ordem de esforço:

- **Uptime**: um monitor externo grátis (ex.: tier grátis do UptimeRobot —
  50 monitores, intervalo de 5 minutos, alerta por email/webhook) apontado
  pra `https://dindin-cafelabs.web.app`. Leva uns 5 minutos pra configurar
  e não precisa de mudança de código; só precisa criar uma conta, então
  fica pro dono em vez de ser feito silenciosamente aqui.
- **Erros**: Firebase Crashlytics (grátis, produto Firebase já integrado)
  pra erros do lado do cliente, ou observar o painel de uso/negações de
  "Rules" do Firestore no console do Firebase depois de um deploy de rules
  pra pegar um pico de escritas rejeitadas.
- **Uso/custo**: ver a seção a seguir — a diferença entre um freio e um aviso
  importa mais aqui do que parece.

### Limites do tier grátis: o que trava sozinho e o que só avisa

Dois serviços independentes, e eles falham de formas opostas.

**Firebase (Spark).** Não há conta de billing anexada, então **uma fatura
surpresa é impossível** — as quotas diárias são uma parada dura, não suave.
Essa parada dura *é* o freio, e ele é automático. O que você não ganha por
padrão é qualquer aviso antes de bater nela. Os tetos que importam (confira os
números atuais no console, o Google ajusta):

| Quota | Teto diário no Spark | O que acontece no teto |
|---|---|---|
| Leituras de documento no Firestore | ~50.000/dia | leituras passam a falhar até 00:00 US-Pacific |
| Escritas de documento no Firestore | ~20.000/dia | escritas passam a falhar até 00:00 US-Pacific |
| Deleções no Firestore | ~20.000/dia | deleções passam a falhar |
| Dados armazenados | 1 GiB | escritas rejeitadas |
| Auth (Google Sign-In) | sem teto diário | — |

Esse é exatamente o formato em que chegam os padrões de abuso contra os quais
`backend`/`security` se protegem: um script criando contas em loop, ou
martelando escritas, queima 20.000 escritas muito antes de custar qualquer
coisa — e aí **o app cai pra todos os usuários reais até a virada do dia**, sem
fatura e, por padrão, sem notificação. O modo de falha de um tier grátis é uma
queda, não um boleto.

O que configurar de fato, em ordem de valor:

1. **O monitor externo de uptime** (UptimeRobot, acima) é o que pegaria isso,
   porque estourar a quota faz o app web dar erro visível. É um alarme
   posterior ao fato, mas é o único que funciona hoje sem ressalvas.
   Configure.
2. **Console do Firebase → Usage and billing → Usage** mostra os contadores
   diários. Vale olhar no dia seguinte a qualquer lançamento ou divulgação.
   Manual.
3. **Políticas de alerta do Cloud Monitoring** em métricas do Firestore
   (`firestore.googleapis.com/document/write_count`) dariam um alerta
   *preditivo* em, digamos, 60% da quota diária de escrita. **Verifique antes
   de depender disso**: políticas de alerta num projeto GCP sem conta de
   billing anexada não têm disponibilidade garantida, e os alertas de orçamento
   do próprio Firebase exigem Blaze com certeza. Se o console recusar, volte
   pro 1 e o 2 — **não** habilite o Blaze pra conseguir o alerta, já que
   anexar uma conta de billing remove o hard cap que hoje é a única coisa
   impedindo uma fatura.

**GitHub Actions.** Repositório público → minutos não medidos, sem superfície
de cobrança, nada pra alertar.

**Google Play.** US$ 25 de registro, uma vez, já pago. Nenhum custo por
instalação ou por download, nunca. Nada pra monitorar financeiramente.

### Monitoramento específico de Android (depois do primeiro release)

- **Play Console → Qualidade → Android vitals** é grátis e automático: taxa de
  crash, taxa de ANR, e stack traces já simbolizadas (o AAB envia os símbolos
  de debug, ver "Ofuscação e arquivos de símbolo"). Ligar os alertas por e-mail
  em Play Console → Configurações → Preferências → Notificações por e-mail,
  incluindo os de "limite de mau comportamento" — passar de ~1,09% de crash
  percebido pelo usuário rebaixa a ficha na busca e nas recomendações.
- **Play Console → Avaliações** com notificação por e-mail ligada. Pra um
  mantenedor solo isso é, realisticamente, o sinal de queda mais rápido do
  cliente Android especificamente.
- **Ainda falta**: não há Crashlytics/Sentry, então erros que não derrubam o
  processo (uma escrita no Firestore que falha, um login que silenciosamente
  não faz nada) são invisíveis nos dois clientes. Esse é o principal gap de
  monitoramento restante e o investimento certo depois que o lançamento
  assentar.
- O Firebase em si não tem endpoint nosso pra monitorar — o cliente fala com o
  Google direto. Assine https://status.firebase.google.com pra incidentes do
  lado da plataforma.

## Resolver antes do primeiro upload no Play (parte disso é permanente)

- **Nome do pacote `com.cafelabs.dindin`** — permanente. Não pode ser mudado
  depois de publicado, e não pode ser reusado nem se você apagar a ficha do app
  e começar de novo. Ele bate com `namespace`, `applicationId` e o pacote em
  `android/app/google-services.json`. Confirme que está satisfeito com ele
  *agora*.
- **O SHA-1 do Google Sign-In não está registrado.** O
  `android/app/google-services.json` hoje tem a lista `oauth_client` vazia, ou
  seja, nenhuma impressão digital de certificado está registrada pro app
  Android no Firebase — o login já falha em aparelho hoje, e vai continuar
  falhando pra instalações do Play até o SHA-1 da *chave de assinatura do app*
  ser adicionado (ver passo 8 do runbook). Tratar como bloqueio de lançamento.
- **`android:label`** agora é `"Dindin"` (era o valor minúsculo do template,
  `dindin`). Isso é só o rótulo do launcher; o título da ficha no Play e o
  `<title>` do `web/index.html` são duas strings separadas — o
  `web/index.html` ainda diz `dindin`. Escolha uma grafia pras três. Esta aqui
  é mudável depois, diferente do nome do pacote.
- **Ícone do app** — o adaptive icon está corretamente configurado (foreground
  com inset de 16%, fundo `#FCFCFB`), então o ícone do launcher está ok. O Play
  exige separadamente um ícone de loja PNG 512x512 32-bit enviado no console,
  sem transparência e sem cantos arredondados embutidos.
- **URL de política de privacidade e caminho de exclusão de conta** — os dois
  obrigatórios pra um app com contas e dados financeiros, os dois bloqueantes,
  e nenhum dos dois existe neste repo. Ver passos 4 e 5 do runbook.
