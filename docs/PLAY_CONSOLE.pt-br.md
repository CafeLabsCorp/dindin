# Configuração no Play Console e depuração do login com Google

Este documento cobre as partes de colocar o Dindin na Play Store que não
são sobre buildar/subir o `.aab` (isso está no `DEPLOY.pt-br.md`) — a
própria ficha no Play Console, e a configuração OAuth no Google Cloud da
qual o login com Google depende. Escrito em setembro de 2026 depois de
várias rodadas de tentativa e erro pra acertar as duas coisas.

## Saindo do status "Rascunho"

Um app novo no Play Console fica em Rascunho até todo item de "Termine de
configurar seu app" estar concluído. Os que não são óbvios só pelo nome do
item:

- **Classificação de conteúdo (questionário IARC)** — responder com
  honestidade sobre o que o app faz (controle financeiro pessoal, sem
  conteúdo gerado por usuário, sem anúncios no lançamento).
- **Público-alvo** — faixas etárias a que o app se destina; também pergunta
  se o app atrai crianças (não atrai, é um app de finanças pessoais).
- **Declaração de recursos financeiros** — o Dindin declara controle de
  orçamento/gastos pessoais; não movimenta dinheiro de verdade, então não é
  um app de pagamentos ou empréstimos pela política de recursos financeiros
  da Play.
- **Declaração de apps de saúde** — não se aplica, mas a Play pergunta
  explicitamente; responder "sem recursos de saúde."
- **Declaração de ID de publicidade** — o Dindin não usa o Advertising ID
  (confirmado removido do manifest na rodada de segurança do `mobile`, ver
  o board). Declarar "não utilizado."
- **Formulário de Segurança dos Dados (Data Safety)** — ver abaixo; é o mais
  ligado ao comportamento real do app e precisa bater exatamente com a
  Política de Privacidade (`dindin.cafelabs.net/privacidade`), não só estar
  "mais ou menos certo."

### Formulário de Segurança dos Dados

Preencher as duas abas, "Coletados" e "Compartilhados." O que o Dindin
coleta de fato, batendo com o que está na Política de Privacidade já
publicada:

- **IDs de usuário** (UID do Firebase Auth, e-mail) — coletado, obrigatório,
  não compartilhado.
- **Informações financeiras** (transações, saldos, categorias de orçamento
  — o dado principal do app) — coletado, obrigatório, não compartilhado,
  criptografado em trânsito.
- **Local aproximado** — só se/quando alguma funcionalidade realmente ler
  isso; caso contrário declarar "não coletado." Conferir contra o código
  atual antes de responder, esse formulário é uma superfície de
  compliance, não um chute.
- **Interações no app / identificadores de dispositivo** — vêm do Firebase
  Analytics (os 4 eventos mínimos da rodada de segurança do `mobile`) e do
  Firebase App Check (Play Integrity). Ambos com opt-out em Ajustes →
  Privacidade.

Nenhum dado do Dindin é vendido ou compartilhado com terceiros pra
publicidade. Tudo é excluível via o fluxo de exclusão de conta self-service
(Ajustes → Privacidade → "Zona de perigo") — o formulário de Segurança dos
Dados tem uma checkbox pra isso ("usuários podem solicitar exclusão de
dados") que deve ficar `true`.

### Ficha da loja (página "Detalhes do app" padrão, pt-BR)

Preenchida em 2026-09-24. Texto como foi publicado (só pt-BR):

**Nome:** `Dindin: finanças por caixinhas`

**Descrição curta:** `Organize suas finanças em caixinhas: gastos, receitas e assinaturas.`

**Descrição completa:**

```
Dindin é um caderno digital de finanças pessoais, baseado em "caixinhas" (envelopes).

Divida o que você ganha entre caixinhas com propósitos diferentes — gastar ou guardar — e registre o que sai de cada uma. Você sempre sabe quanto tem disponível, sem precisar abrir planilha nenhuma.

PRINCIPAIS RECURSOS
• Caixinhas: organize seu dinheiro por categoria, com meta e limite opcionais
• Receitas e gastos: lance manualmente, com data, valor e descrição
• Assinaturas e parcelamentos: o Dindin lança os gastos automaticamente nas datas certas
• Saldo em tempo real: saiba sempre quanto tem em cada caixinha e na conta
• Exportar e importar em JSON: seus dados são seus, leve pra onde quiser
• Multiplataforma: use no navegador (app.dindin.cafelabs.net) ou no Android

PRIVACIDADE EM PRIMEIRO LUGAR
O Dindin não se conecta ao seu banco, não pede cartão, não pede CPF e não movimenta dinheiro de verdade — é só uma ferramenta de organização. Você digita, o Dindin soma. Seus dados não são vendidos.

É gratuito, feito pela Café Labs.
```

Ficou de fora da ficha de propósito: "sem anúncios". O app não tem anúncio
hoje, mas a ficha não deve travar isso — atenção que os Termos de Uso (§3,
preço) e a Política de Privacidade (§3.4) *prometem* hoje que não há
anúncios, então pôr anúncio no futuro exige revisar esses dois também, além
da declaração "contém anúncios" e do Data Safety na Play.

**Gráficos** — gerados por `scripts/play_store_assets.mjs` (usa `sharp`,
devDependency de `scripts/`, e as fontes Fraunces/Work Sans do próprio app):

- `node play_store_assets.mjs graphics <pasta>` → `icone-512.png` (fundo
  escuro `#16130F`, igual ao ícone adaptativo) e
  `grafico-destaque-1024x500.png` (logo + nome + slogan). Os dois sem canal
  alfa, como a Play exige pro gráfico de destaque.
- `node play_store_assets.mjs screenshots <pasta> <legendas.json>` →
  emoldura prints crus do celular em 1080×1920 (9:16) com legenda em cima.
  A Play só aceita 16:9 ou 9:16; o 1080×2340 (19,5:9) nativo do S23 é
  recusado direto. Legendas usadas: "Saiba quanto tem / em cada caixinha"
  (Dashboard), "Metas, limites / e histórico do mês", "Assinaturas lançadas
  / no automático", "Compras parceladas / sob controle", "Todos os gastos, /
  filtrados por período", "Seus dados, / seu controle" (Ajustes).

As imagens geradas **não são commitadas**: são reproduzíveis, binário
incha o histórico do git pra sempre, e os prints podem mostrar dados reais
de conta. As versões publicadas ficam no Google Drive da empresa.

### Trilhas de teste

- **Teste interno**: instantâneo, sem revisão, bom pra aparelhos do próprio
  desenvolvedor. Não é suficiente sozinho — a Play exige **teste fechado**
  antes de produção pra uma conta de desenvolvedor pessoal.
- **Teste fechado (Alpha)**: precisa de **12 testadores que aceitaram
  participar por 14 dias contínuos** antes de poder pedir acesso à
  produção. Os testadores precisam entrar ativamente pelo link de adesão da
  trilha, não basta listar os e-mails.
- Pra subir o mesmo `.aab` numa segunda trilha depois que ele já foi
  enviado pra uma: usar **"Adicionar da biblioteca"** pra reaproveitar o
  artefato já enviado, em vez de subir o `versionCode` e rebuildar. A Play
  recusa o mesmo `versionCode` duas vezes em *qualquer* trilha, inclusive
  rascunhos.
- **Vincular a Política de Privacidade** na ficha da loja (não só dentro do
  app) antes de pedir acesso à produção — é um campo separado das citações
  do formulário de Segurança dos Dados.

## Login com Google: configuração OAuth no Google Cloud

Essa é a parte que não está no `DEPLOY.pt-br.md`, seção Android, porque não
é sobre o projeto Firebase nem a chave de assinatura diretamente — é o
console **"Google Auth Platform"** do Google Cloud (antes chamado "Tela de
consentimento OAuth," reorganizado em várias páginas no final de 2026), do
qual o provedor Google do Firebase Auth depende separadamente do Console
do Firebase.

Console → projeto `dindin-cafelabs` → menu hambúrguer → **APIs e serviços →
Tela de permissão OAuth** (cai no `Google Auth Platform`).

### O que precisa estar configurado, e onde

| Página | O que controla | O que o Dindin precisava |
|---|---|---|
| **Público-alvo** | Status de publicação (Teste vs. Produção), lista de usuários de teste | Precisa estar "Em produção" pra qualquer conta Google conseguir logar sem estar numa allowlist |
| **Branding** | Nome do app, logo, links de página inicial/privacidade/termos, domínios autorizados | Os três campos de link são obrigatórios (`*`) assim que a marca precisa aparecer pro usuário; cada domínio usado nesses links também precisa estar em "Domínios autorizados" |
| **Clientes** | Os client IDs OAuth 2.0 de fato — um por chave de assinatura Android (debug/upload/Play App Signing) mais um cliente Web usado como `serverClientId` | Precisa ter exatamente as impressões digitais SHA-1 que vão assinar de verdade o APK distribuído; criado automaticamente pelo Firebase, mas vale conferir na mão |
| **Central de verificação** | Se o Google exige que o app passe por revisão de verificação | Não é exigido pro Dindin — ele só pede escopos não sensíveis (`email`, `profile`, `openid`), confirmado pelo card "Data access status" |

### As três impressões digitais SHA-1 do Android, e por que existem três

`android/app/google-services.json` tem uma entrada `oauth_client` por chave
de assinatura que pode assinar um build que chega num aparelho de verdade:

1. **Chave de debug** — a que estiver no keystore de debug padrão da
   máquina do desenvolvedor (`~/.android/debug.keystore`). Necessária pra
   `flutter run` num build de debug conseguir logar durante o
   desenvolvimento.
2. **Chave de upload** — a chave com que `scripts/release_android.sh`
   assina o `.aab` antes de subir pra Play (ver `DEPLOY.pt-br.md` → "Duas
   chaves, e só uma é sua"). A Play reassina com a chave de assinatura do
   app antes de distribuir, então essa impressão digital importa menos com
   o Play App Signing ativo, mas é o que a própria Play confere no upload.
3. **Chave de assinatura do app (Play App Signing)** — a chave que o Google
   usa de fato pra assinar o `.apk`/split do `.aab` que chega no aparelho
   do usuário depois de baixado da Play Store. **É essa que precisa bater
   pro login com Google funcionar em qualquer instalação vinda da Play**,
   inclusive teste interno/fechado. Pega em Play Console → **Testar e
   lançar → Configuração → Integridade do app** (a "chave de assinatura do
   app," não o "certificado da chave de upload" mais abaixo na mesma
   página — é fácil confundir os dois, e só um deles realmente importa
   pras instalações vindas da Play).

As três vão em Firebase Console → Authentication → Sign-in method → Google
→ adicionar impressão digital, o que regenera o `google-services.json` com
uma nova entrada `oauth_client` por impressão digital. Baixar de novo pra
dentro de `android/app`, e se isso mudar o artefato de forma relevante
(novo cliente OAuth adicionado), subir o `versionCode` — a Play não deixa
reenviar o mesmo código com um `google-services.json` diferente embutido.

### Depurando "GoogleSignInException(... [16] Account reauth failed...)"

Isso apareceu só no build de teste interno distribuído pela Play — nunca em
builds de debug, nunca na web. Trilha completa da investigação, caso volte
a acontecer ou aconteça em outro app Android da Café Labs usando o fluxo
baseado em Credential Manager do `google_sign_in` v7:

**O que `[16] Account reauth failed` realmente significa**: `16` é o
`CommonStatusCodes.CANCELED` do Google Play services — um balde genérico,
não literalmente "usuário apertou cancelar." O plugin `google_sign_in_android`
mapeia qualquer coisa nesse balde pra `GoogleSignInExceptionCode.canceled`
independente da causa real, então o texto do erro é enganoso por design,
não um bug deste app. Confirmado que a própria string é produzida pelo
módulo do Google Play services instalado no aparelho (o provedor de
identidade Google do Credential Manager), não por nenhum código na árvore
de dependências deste app — vasculhado o bytecode decompilado de
`play-services-auth`, `credentials-play-services-auth` e
`google_sign_in_android` e ela não aparece em nada embarcado no APK.

**Causas comuns documentadas** (pelo próprio README de troubleshooting do
`google_sign_in_android`, e por dois issues fechados do Flutter relatando
exatamente o mesmo erro —
[#174744](https://github.com/flutter/flutter/issues/174744),
[#184918](https://github.com/flutter/flutter/issues/184918)), todas
verificadas pro Dindin e descartadas uma a uma:

- ❌ Impressão digital SHA errada/ausente → conferida a SHA-1 da chave de
  assinatura do app dígito por dígito contra o que está cadastrado.
- ❌ Nome de pacote errado → `applicationId`/`namespace` ambos
  `com.cafelabs.dindin`, batendo com os três clientes OAuth Android.
- ❌ `serverClientId` ausente/errado → o client ID Web fixo em
  `lib/services/auth_service.dart` bate com a entrada `client_type: 3` do
  `google-services.json`.
- ❌ Específico da conta (concessão antiga, precisa reautorizar no nível da
  Conta Google) → descartado testando 3 contas Google diferentes, nenhuma
  das quais já tinha concedido acesso ao Dindin antes.
- ❌ Específico do aparelho (cache/versão do Play Services) → descartado
  testando em dois aparelhos Android físicos diferentes (celular + tablet),
  mesmo resultado nos dois.
- ❌ Tela de consentimento OAuth não verificada/sem marca → a marca estava
  de fato incompleta (faltavam os links obrigatórios de página inicial e
  política de privacidade, e o domínio `cafelabs.net` não estava na lista
  de domínios autorizados) e foi corrigida, mas o erro continuou depois —
  então esse era um problema real e separado, que valia a pena corrigir,
  só não era *a* causa desse erro específico.

**A causa real, achada em 2026-09-24**: a SHA-1 mostrada na seção "chave de
assinatura do app" do Play Console — o valor comparado dígito por dígito
acima e considerado correto — **não era** o certificado que de fato assina
o APK distribuído pela Play. O `keytool -printcert -jarfile` nem consegue
ler esse certificado (APKs distribuídos pela Play carregam só assinaturas
v2/v3, que o `keytool` não interpreta), então o único jeito de saber a
resposta real foi puxar o `base.apk` instalado de fato via `adb`, de um
celular que instalou o app **pela Play Store**, e ler o certificado
diretamente (`scripts/apk_cert.py`, criado pra isso). Isso deu uma SHA-1
completamente diferente (`1E:2A:0F:A1:...`) da que tinha sido copiada da
tela do console e cadastrada no Firebase (`28:E1:77:6A:...`). Cadastrar a
impressão digital verificada via `adb` corrigiu o login na hora — sem
build novo, funcionando em toda conta e aparelho já testados. O passo a
passo completo e a tabela de impressões digitais atualizada estão em
`docs/DEPLOY.pt-br.md` → "Login com Google só falha em instalações da
Play", não duplicados aqui.

**A lição**: nunca confiar numa impressão digital copiada de uma tela de
console como fonte da verdade de qual certificado está assinando um build
distribuído pela Play — verificar contra o certificado real do APK
instalado. Toda outra causa do checklist documentado acima (nome de
pacote, `serverClientId`, conta, aparelho, marca da tela de consentimento)
realmente estava certa; a falha era inteiramente um problema de
transcrição/suposição sobre qual certificado estava valendo, não uma etapa
de configuração faltando.

Pendências não-bloqueantes: confirmar de onde veio o valor errado
`28:E1:77:6A:...` (coluna errada lida no console? chave desatualizada?) e
decidir se remove do Firebase; baixar de novo o `google-services.json` pra
dentro de `android/app/` pra refletir as impressões digitais novas
(cosmético — o Firebase confere no lado do servidor, então o login já
funciona sem isso).

Enquanto isso, `lib/features/auth/login_page.dart` foi corrigido
independente da causa raiz: ele mostrava esse texto de exceção cru na
tela (foi assim que o bug ficou visível, pra começo de conversa). Agora
ele captura `GoogleSignInException` especificamente, loga por completo via
`dart:developer` pra diagnóstico, e mostra uma mensagem curta e localizada
no lugar — ver commit `b7a8c3f`.
