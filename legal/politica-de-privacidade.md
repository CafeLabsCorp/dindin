# Política de Privacidade — Dindin

**Versão 0.1 — MINUTA de 27 de agosto de 2026**
**Status: ⚠️ MINUTA — NÃO revisada por advogado(a). Não publicar, não vincular
no Google Play e não apresentar a usuário antes da revisão jurídica.**

> Publicação prevista: `https://dindin.cafelabs.net/privacidade`
> (URL pública, indexável, em HTML — **não** em PDF, exigência do Google Play).
> Também deve ficar acessível de dentro do aplicativo (Ajustes → Legal).
> Toda alteração gera uma nova versão datada. As versões anteriores ficam
> arquivadas no repositório, para que seja sempre possível provar qual texto
> estava em vigor em qualquer data.

> ⚠️ **Pendências de dado real neste documento** (marcadas com `[CONFIRMAR]`
> ao longo do texto): região do Firestore do projeto `dindin-cafelabs`.
> Enquanto não forem preenchidas, o texto está incompleto e não pode ser
> publicado.

---

## 1. Em linguagem simples

O Dindin é um caderno digital de finanças pessoais. Você anota o que ganha,
divide esse dinheiro em "caixinhas" e anota o que gasta. Os números que
aparecem no app são os números que **você digitou**.

O Dindin **não se conecta ao seu banco**, **não movimenta dinheiro**, **não
pede o número do seu cartão** e **não pede o seu CPF**. Ele não sabe nada
sobre a sua vida financeira além do que você mesmo escreveu nele.

Para guardar essas anotações e sincronizá-las entre os seus aparelhos, o
Dindin precisa de uma conta — e é por isso que ele pede o seu e-mail. Nada
disso é vendido, usado para propaganda ou mostrado para outra pessoa.

O resto deste documento explica isso em detalhe, porque a lei exige que a
explicação seja completa.

---

## 2. Quem é responsável pelos seus dados

**Controlador (quem decide quais dados existem e por quê):**
Café Labs, operada por Felipe Portes Antunes (CPF 704.995.256-71) — a Café
Labs ainda não possui CNPJ próprio.

Diferentemente de outros produtos da Café Labs, aqui **não existe um terceiro
controlador**: quem decide as finalidades do tratamento é a própria Café Labs,
e é ela quem responde perante você e perante a ANPD.

**Operadores (quem processa dados por conta da Café Labs):**
- **Google LLC / Google Cloud (Firebase Authentication e Cloud Firestore)** —
  hospeda a sua conta e as suas anotações financeiras.
- **Vercel Inc.** — hospeda apenas o site de apresentação
  `dindin.cafelabs.net`, que não recebe nenhum dado financeiro seu.

**Canal de contato sobre privacidade:**
`privacidade@cafelabs.net`

Esse é o canal para tirar dúvidas sobre esta política e para exercer os
direitos descritos na seção 8. A Café Labs é hoje um agente de tratamento de
pequeno porte e, nos termos da Resolução CD/ANPD nº 2/2022, está dispensada
da indicação formal de Encarregado(a) — mas mantém este canal de comunicação
com você e com a ANPD, como a mesma norma exige. Se o volume ou a natureza do
tratamento mudar, a indicação será feita e esta política será atualizada.

---

## 3. Quais dados são tratados

### 3.1 Dados da sua conta

Criados quando você se cadastra, e tratados pelo Firebase Authentication:

- **E-mail** — usado como identificador de login.
- **Senha** — se você se cadastrou por e-mail e senha. A senha é armazenada
  pelo Google de forma cifrada e **não é legível pela Café Labs**.
- **Nome e foto de perfil da conta Google** — apenas se você entrar com
  "Entrar com Google". Vêm da sua conta Google; o Dindin não pede esses dados
  a você e não os usa para nada além de identificar a sua sessão.
- **Identificador interno da conta (UID)** — um código gerado pelo Firebase,
  que é a chave sob a qual as suas anotações ficam guardadas.
- **Datas de criação da conta e do último acesso**, registradas pelo Firebase
  Authentication.

### 3.2 As suas anotações financeiras

Tudo abaixo é **digitado por você** — nada é importado de banco, cartão,
fatura ou qualquer fonte externa:

- **Caixinhas (envelopes)**: nome que você deu, se é de gasto ou de reserva,
  limite mensal, meta de guardar, se pode ficar negativa, data de criação.
- **Entradas (receitas)**: valor, data, origem (texto livre — por exemplo
  "salário") e descrição opcional.
- **Alocações**: quanto você moveu da conta para cada caixinha, e as
  transferências entre caixinhas.
- **Gastos**: valor, data, caixinha de origem (ou "conta"), descrição opcional
  e, quando o gasto foi gerado por uma assinatura ou parcelamento, a
  referência ao lançamento que o originou.
- **Assinaturas**: nome, valor, dia de vencimento, caixinha de origem.
- **Parcelamentos**: nome, valor total, número de parcelas, datas, quantas
  parcelas já foram lançadas e quanto foi adiantado.
- **Saldos calculados**: saldo da conta e saldo de cada caixinha, derivados
  automaticamente dos lançamentos acima.

⚠️ **Atenção aos campos de texto livre.** Os campos "origem", "descrição" e o
nome das caixinhas/assinaturas aceitam qualquer texto. Se você escrever ali
informações pessoais (nome de pessoas, endereço, dado de saúde, etc.), elas
passam a ser tratadas junto com o resto. **Recomendamos não escrever nesses
campos nada além do necessário para você se organizar.**

Sob a LGPD, dados financeiros **não** são classificados como "dados pessoais
sensíveis" (art. 5º, II), mas são tratados aqui com o mesmo cuidado, porque
revelam hábitos e situação de vida.

### 3.3 Dados técnicos

- **Sessão de login**: no aplicativo web, a sessão é guardada no seu próprio
  navegador (armazenamento local do Firebase Authentication) para que você não
  precise entrar de novo a cada visita. Não é um cookie de publicidade e não
  acompanha você em outros sites.
- **Registros técnicos do Google**: ao usar o app, o seu endereço IP e dados
  básicos da requisição chegam à infraestrutura do Google Firebase, que os
  registra para operação e segurança do serviço, sob a política de privacidade
  do próprio Google.

### 3.4 O que NÃO é coletado

Por decisão de projeto, o Dindin **não** coleta e **não** pede:

- CPF, RG ou qualquer documento de identidade
- Número de cartão, conta bancária, chave Pix ou qualquer dado de pagamento
- Conexão com banco, Open Finance, importação de fatura ou extrato
- Localização/GPS, contatos da agenda, fotos, câmera, microfone
- Dados de saúde ou qualquer outro dado pessoal sensível

O aplicativo **não contém SDK de analytics, de publicidade ou de rastreamento
de terceiros**, não exibe anúncios e não compartilha dados com redes de
anúncios. Isso é verificável: as dependências do app estão públicas em
`pubspec.yaml`, no repositório do projeto.

### 3.5 Site de apresentação (`dindin.cafelabs.net`)

O site de apresentação é apenas informativo — **não** dá acesso a nenhuma
anotação financeira e não tem formulário, cadastro ou login. Ele usa uma
medição de audiência agregada (Vercel Web Analytics), que **não utiliza
cookies**, não cria identificador persistente e não permite identificar quem
visitou. São registrados apenas dados agregados como página visitada,
país/região aproximados, tipo de aparelho e navegador. Como não há cookie nem
identificação individual, não é exibido banner de cookies.

---

## 4. Para que os dados são usados

| Finalidade | Dados envolvidos |
|---|---|
| Criar e manter a sua conta, e reconhecer você no login | e-mail, senha, dados da conta Google (se usada), UID |
| Guardar as suas anotações e sincronizá-las entre os seus aparelhos | todas as anotações financeiras da seção 3.2 |
| Calcular saldos, resumos mensais e lançar assinaturas/parcelamentos vencidos | todas as anotações financeiras |
| Impedir que uma pessoa acesse os dados de outra | UID, regras de segurança do Firestore |
| Manter o serviço funcionando (corrigir falhas, operar a infraestrutura) | dados técnicos, com acesso restrito |
| Responder a você quando pedir suporte ou exercer um direito | e-mail |
| Medir audiência do site de apresentação, de forma agregada | dados agregados da seção 3.5 |

Os dados **não** são usados para: propaganda, marketing, venda,
perfilamento, análise de crédito, score, ou compartilhamento com bancos,
seguradoras, empregadores, lojas ou qualquer terceiro comercial.

**O Dindin não envia mensagens promocionais.** Hoje o único e-mail que você
pode receber é transacional (por exemplo, uma confirmação ou uma resposta a um
pedido seu). Se um dia a Café Labs quiser enviar novidades ou qualquer
comunicação promocional, isso exigirá um **consentimento separado e
específico**, pedido em uma caixa própria (nunca embutido na aceitação dos
Termos), que você poderá recusar ou retirar a qualquer momento **sem perder o
acesso ao aplicativo**.

---

## 5. Base legal de cada tratamento

| Tratamento | Base legal (Lei 13.709/2018 — LGPD) |
|---|---|
| Conta (e-mail, senha, dados da conta Google, UID) | art. 7º, V — execução de contrato do qual você é parte (os Termos de Uso) |
| Anotações financeiras (seção 3.2) | art. 7º, V — execução de contrato: sem elas o aplicativo não tem função |
| Isolamento entre contas e proteção contra acesso indevido | art. 7º, V, e art. 7º, IX — legítimo interesse na segurança do próprio serviço |
| Registros técnicos de operação (IP, logs do Firebase) | art. 7º, IX — legítimo interesse na operação e segurança |
| Atendimento a pedidos de titular | art. 7º, II — cumprimento de obrigação legal |
| Medição agregada do site de apresentação | art. 7º, IX — legítimo interesse, sem identificação individual |
| Comunicação promocional (não existe hoje) | art. 7º, I — consentimento específico e destacado, se um dia existir |

Nenhum tratamento do Dindin depende de você consentir com propaganda: recusar
comunicação promocional **não** limita nada no aplicativo.

---

## 6. Onde os dados ficam e transferência internacional

A sua conta e as suas anotações ficam armazenadas no **Google Firebase
(Firebase Authentication e Cloud Firestore)**, no projeto `dindin-cafelabs`.

`[CONFIRMAR: região do banco de dados Firestore do projeto dindin-cafelabs]`

- **Se a região for `southamerica-east1` (São Paulo, Brasil):** as suas
  anotações financeiras ficam armazenadas em território nacional. O Google,
  como operador, pode acessá-las a partir de outros países exclusivamente para
  suporte técnico e operação da infraestrutura, sob os compromissos
  contratuais de proteção de dados do Google Cloud — hipótese do art. 33, II,
  da LGPD (cláusulas contratuais).
- **Se a região for qualquer outra (por exemplo `nam5`, Estados Unidos):** há
  **transferência internacional de dados**. Nesse caso, as suas anotações
  financeiras são armazenadas fora do Brasil, em infraestrutura do Google, e a
  transferência se apoia no art. 33, II, da LGPD (cláusulas contratuais
  padrão firmadas com o Google Cloud/Firebase), com as garantias do "Cloud
  Data Processing Addendum" do Google.

O Firebase Authentication opera em infraestrutura global do Google,
independentemente da região escolhida para o Firestore — ou seja, **os dados
da sua conta (e-mail e credencial) trafegam e podem ser armazenados fora do
Brasil** em qualquer cenário, sob a mesma hipótese do art. 33, II.

O site de apresentação é hospedado na Vercel, com servidores fora do Brasil,
mas o site **não recebe nenhum dado financeiro nem dado de conta**; a única
informação que sai do país por ali é a medição agregada e não identificável
descrita no item 3.5.

---

## 7. Por quanto tempo os dados ficam guardados

| Dado | Prazo |
|---|---|
| Conta e anotações financeiras | enquanto a sua conta existir — você decide, não há expiração automática |
| Conta inativa | não há exclusão automática por inatividade hoje; se isso mudar, você será avisado por e-mail com antecedência mínima de 30 dias antes de qualquer eliminação |
| Após pedido de exclusão da conta | eliminação conforme a seção 8, item "Exclusão" |
| Cópias de segurança da infraestrutura | ciclo de até **30 dias** do provedor; dados excluídos desaparecem das cópias ao fim do ciclo |
| Registro de que a exclusão foi feita (sem os seus dados pessoais) | 5 anos, apenas para comprovar o cumprimento da lei |
| Registros técnicos de operação/segurança | conforme a retenção do provedor (Google Firebase) |

**O Dindin não é obrigado a guardar as suas anotações financeiras por prazo
legal nenhum.** Ele não é instituição financeira, não emite documento fiscal e
não registra operação regulada — por isso pode atender integralmente a um
pedido de exclusão, sem exceções de "obrigação de guarda".

---

## 8. Seus direitos e como exercê-los

Pela LGPD (art. 18), você pode a qualquer momento:

- **Saber** se existem dados seus e quais são
- **Acessar** os seus dados — o próprio aplicativo já é esse acesso: tudo que
  o Dindin guarda sobre você está visível nas telas do app
- **Corrigir** dados incompletos, errados ou desatualizados — você mesmo edita
  qualquer lançamento dentro do app
- **Pedir a exclusão** da sua conta e de todos os seus dados
- **Pedir a portabilidade** — Ajustes → **Exportar JSON** gera, na hora, um
  arquivo com todas as suas anotações em formato aberto e legível, que você
  pode guardar ou levar para outro serviço
- **Saber com quem** os seus dados são compartilhados (seção 2)
- **Revogar** qualquer consentimento que você tenha dado separadamente
- **Se opor** a um tratamento que você considere irregular
- **Reclamar** à ANPD (Autoridade Nacional de Proteção de Dados)

**Como pedir:** escreva para `privacidade@cafelabs.net`. A resposta é dada em
até **15 dias**.

### Exclusão da conta — o que acontece na prática

`[CONFIRMAR: o procedimento abaixo descreve o comportamento pretendido do
fluxo de exclusão; ele ainda NÃO está implementado no aplicativo. Ver seção
"Requisitos de implementação" do relatório de compliance.]`

1. Você pede a exclusão de dentro do aplicativo (Ajustes → Excluir conta) ou
   pela página pública `https://dindin.cafelabs.net/excluir-conta`.
2. Antes de confirmar, o aplicativo oferece a exportação do seu JSON — depois
   da exclusão não é possível recuperar nada.
3. São eliminados: a sua conta de login (Firebase Authentication) e **todo** o
   conteúdo de `users/{seu-id}` — caixinhas, entradas, alocações, gastos,
   assinaturas, parcelamentos e saldos.
4. Cópias de segurança já feitas expiram no ciclo de até 30 dias e não são
   restauradas.
5. Fica guardado apenas um registro de que a exclusão ocorreu, **sem os seus
   dados pessoais**, para provar que a lei foi cumprida.

A exclusão é **definitiva e não reversível**. Não existe "conta desativada"
que possa ser recuperada depois.

---

## 9. Crianças e adolescentes

O Dindin **não é destinado a menores de 18 anos** e a Café Labs não direciona
o produto a crianças ou adolescentes — não há conteúdo, linguagem ou
divulgação voltados a esse público.

Mesmo assim, o aplicativo reconhece que um adolescente pode tentar usá-lo:

- **Menores de 12 anos (crianças):** o tratamento de dados de criança exige
  consentimento específico e em destaque de pelo menos um dos pais ou do
  responsável legal (art. 14, §1º, da LGPD). O Dindin **não coleta esse
  consentimento** e, portanto, **não deve ser usado por crianças**. Se
  tomarmos conhecimento de que uma conta pertence a uma criança, ela será
  excluída e os dados eliminados.
- **Entre 12 e 17 anos (adolescentes):** o tratamento, se ocorrer, é feito no
  melhor interesse do adolescente (art. 14, caput). Ainda assim, os Termos de
  Uso restringem o cadastro a maiores de 18 anos, e pai, mãe ou responsável
  pode pedir a exclusão da conta pelo canal da seção 8.

Em nenhuma hipótese dados de crianças ou adolescentes são usados para
publicidade ou repassados a terceiros.

---

## 10. Segurança

- Todo o tráfego é criptografado em trânsito (HTTPS/TLS).
- Os dados em repouso são criptografados pela infraestrutura do Google
  Firebase.
- O isolamento entre contas é imposto pelo servidor, por meio das *Security
  Rules* do Firestore: cada conta só alcança o próprio caminho de dados, nunca
  o de outra pessoa. Essa regra é testada automaticamente a cada alteração do
  código.
- A senha de e-mail/senha é armazenada e verificada pelo Google, em formato
  cifrado, e não é legível pela Café Labs.
- O acesso administrativo à infraestrutura é individual e restrito.

Nenhum sistema é 100% seguro. Se ocorrer um incidente de segurança que possa
gerar risco ou dano relevante a você, a Café Labs comunicará a **ANPD** e
**você** nos termos do art. 48 da LGPD, dentro do prazo fixado pela
regulamentação da ANPD (hoje, **3 dias úteis** contados do conhecimento do
incidente), informando o que aconteceu, quais dados foram afetados, quais
riscos isso gera e o que está sendo feito. O procedimento interno de resposta
a incidente está descrito em `docs/` no repositório do projeto.

**Proteja a sua senha.** A Café Labs nunca vai pedir a sua senha por e-mail,
mensagem ou telefone.

---

## 11. Alterações desta política

Se esta política mudar de forma relevante, a nova versão será publicada em
`dindin.cafelabs.net/privacidade` com a data de vigência, e você será avisado
dentro do aplicativo antes de continuar usando. As versões anteriores
permanecem arquivadas.

---

## 12. Contato

Café Labs — Felipe Portes Antunes (CPF 704.995.256-71)
E-mail: `privacidade@cafelabs.net`

Autoridade Nacional de Proteção de Dados (ANPD): `gov.br/anpd`

---

> **Aviso de elaboração:** esta minuta foi redigida com apoio de IA a partir do
> inventário real de dados do produto (esquema do Firestore, serviços de
> autenticação e dependências efetivamente usadas). Ela **não substitui a
> revisão de advogado(a)** e não deve ser publicada, vinculada no Google Play
> nem apresentada a usuário antes dessa revisão. Diferentemente do Micare, o
> texto do Dindin **ainda não passou por advogado(a)**.
