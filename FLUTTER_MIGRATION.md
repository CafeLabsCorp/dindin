# Migração dindin: Next.js → Flutter + Firebase

Este documento descreve a nova arquitetura do **dindin** após a migração de Next.js
(web-only, JSON local) para **Flutter** (multiplataforma) com **Firebase** como backend.

O app Next.js atual (`src/`, `data/db.json`) **permanece no repositório até a migração
estar pronta**. Nada foi apagado — a limpeza do código Next.js é o último passo, feito
só depois que o app Flutter estiver funcional e os dados migrados.

## 1. Por que Flutter

- Um único codebase para **Web, Android e Windows** (as 3 plataformas pedidas).
- iOS fica de fora por enquanto (exige macOS para build/assinatura). Caminho futuro,
  sem precisar comprar um Mac: runners macOS gratuitos/pagos por minuto no GitHub
  Actions ou Codemagic — não é bloqueante, só não é o foco agora.
- Widget tree declarativo facilita reaproveitar a identidade visual (cores, cards,
  tipografia) já validada no Next.js como um `ThemeData` único.

## 2. Stack

| Camada | Escolha | Motivo |
|---|---|---|
| Framework | Flutter (canal stable) | multiplataforma, um só time de código |
| Linguagem | Dart | nativo do Flutter |
| Estado | Riverpod (`flutter_riverpod`) | simples, testável, sem boilerplate de `BuildContext` |
| Roteamento | `go_router` | rotas nomeadas, funciona bem em Web (URLs reais) e desktop |
| Gráficos | `fl_chart` | open-source, gratuito, cobre bem barra/linha como o dashboard atual |
| Datas/moeda | `intl` | formatação `pt_BR` / `BRL`, igual ao app atual |
| Backend | **Firebase** (Spark — plano gratuito) | auth pronto + banco sincronizado entre dispositivos, sem manter servidor |

## 3. Backend: Firebase (mantendo tudo no plano gratuito)

### 3.1 Auth

- `firebase_auth` com dois provedores:
  - **Email/senha**
  - **Google Sign-In** (`google_sign_in` + `firebase_auth`)
- A foto de perfil do Google **não é armazenada em lugar nenhum** — usamos direto a
  `photoURL` que já vem no `User`/`GoogleSignInAccount` (é uma URL do Google, exibida
  com `Image.network` / `CircleAvatar(backgroundImage: NetworkImage(...))`). Isso é
  exatamente o motivo de você não precisar do Firebase Storage: a imagem já está
  hospedada pelo Google, só linkamos.
- Auth no plano Spark é **gratuito e ilimitado** para email/senha e Google — só
  provedores por SMS (telefone) têm cota paga, e não vamos usar isso.

### 3.2 Firestore — modelo de dados

Firestore é um banco de documentos. Para manter segurança simples (cada usuário só
enxerga os próprios dados) e já deixar o app pronto para múltiplas contas (você +
alguém no futuro, ou só você em vários aparelhos), tudo fica dentro de uma
subcoleção por usuário:

```
users/{uid}
  categories/{categoryId}   { name, recurring, createdAt }
  incomes/{incomeId}        { date, amount, source, description }
  allocations/{allocationId}{ incomeId, categoryId, amount, date }
  expenses/{expenseId}      { date, amount, categoryId, description }
```

Isso é o **mesmo modelo de dados do `db.json` atual** (`Category`, `Income`,
`Allocation`, `Expense`) — só migrando de "array dentro de um arquivo" para
"coleção dentro do Firestore". As regras de agregação (saldo por caixinha, resumo
mensal) continuam sendo as mesmas contas, só que lidas do Firestore em vez do JSON.

**Security rules** (rascunho):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

### 3.3 Por que evitar dados pesados (fotos, arquivos)

Você já apontou o ponto certo: o Spark (plano gratuito) do Firestore tem cota diária
generosa pra uso pessoal (~50 mil leituras/dia, ~20 mil escritas/dia, 1 GiB de
armazenamento total) — de sobra pro volume de um app financeiro pessoal. O que
estoura rápido é **Firebase Storage** (arquivos binários — fotos, PDFs de
comprovante etc.), que tem cota de download diário bem mais apertada no plano
gratuito. Por isso:

- Nenhuma foto é enviada para o Firebase — nem a de perfil (vem do Google, ver 3.1),
  nem futuros "comprovantes de gasto" (se um dia quiser isso, melhor guardar o link
  pra uma imagem já hospedada em outro lugar gratuito, ou simplesmente não guardar).
- Só texto/número (o mesmo tipo de dado que já está no `db.json`) vai pro Firestore.

## 4. Identidade visual

A paleta e os tokens usados no Next.js (`src/lib/palette.ts`, `globals.css`) migram
para um `ThemeData` único em Dart:

```
lib/theme/colors.dart   // hexs: categorical, sequential, status, ink — mesmos valores
lib/theme/theme.dart    // ThemeData(useMaterial3: true, colorScheme: ...)
```

Mesma lógica de hoje: cor categórica em ordem fixa (azul, aqua, amarelo, verde,
violeta, vermelho, magenta, laranja), status reservado (bom/alerta/sério/crítico),
sequencial azul pra magnitude. Layout equivalente: 4 telas (Dashboard, Receitas,
Gastos, Categorias) — em mobile como bottom navigation bar, em Web/Windows como
`NavigationRail` lateral (breakpoint por largura de tela).

## 5. Estrutura do projeto Flutter

```
dindin_flutter/
  lib/
    main.dart
    app.dart                  # MaterialApp.router + tema
    theme/
      colors.dart
      theme.dart
    models/
      category.dart
      income.dart
      allocation.dart
      expense.dart
    services/
      auth_service.dart       # login email/senha + Google
      firestore_service.dart  # CRUD por coleção, sob users/{uid}/...
      aggregation_service.dart# saldo por caixinha, resumo mensal (porta de aggregations.ts)
      import_export_service.dart # importar/exportar JSON (ver seção 6)
    features/
      auth/login_page.dart
      dashboard/dashboard_page.dart
      categorias/categorias_page.dart
      receitas/receitas_page.dart
      gastos/gastos_page.dart
    widgets/
      stat_tile.dart
      app_card.dart
  web/       # gerado pelo `flutter create`, config de PWA/ícones aqui
  android/
  windows/
  pubspec.yaml
```

## 6. Migração dos dados existentes

Sem perder o que já está lançado no `data/db.json` atual:

1. O `db.json` é mantido como está até a migração ser concluída (não mexer nele).
2. No app Flutter, uma tela simples (Configurações → "Importar backup") lê um
   arquivo `.json` no mesmo formato de `db.json` e grava tudo em lote no Firestore,
   sob `users/{uid}/...`, usando um `WriteBatch`.
3. Essa mesma funcionalidade serve como **backup/restore permanente** do app daqui
   pra frente (não é só uma ferramenta descartável de migração única) — exporta o
   estado atual do Firestore de volta pra um `.json` idêntico ao formato usado hoje.
4. Depois que os dados estiverem confirmados no Firestore (dá pra conferir pelo
   próprio app ou pelo console do Firebase), o `data/db.json` e o restante do código
   Next.js são removidos do repositório.

## 7. Hospedagem

| Plataforma | Como | Custo |
|---|---|---|
| **Web** | `flutter build web` → **Firebase Hosting** (`firebase deploy`) | grátis (10 GB armazenamento / 360 MB por dia de transferência no Spark) |
| **Android** | `flutter build apk` → instala direto no aparelho (sideload) | grátis. Publicar na Play Store é opcional e tem taxa única de US$25 |
| **Windows** | `flutter build windows` → `.exe`, distribuído como `.zip` (ex: anexado numa release do GitHub) | grátis |
| **iOS** | fora do escopo por enquanto (sem Mac) | — |

Firebase Hosting é a escolha natural pra Web porque já fica no mesmo projeto do
Auth/Firestore, sai com HTTPS de graça e aceita domínio próprio sem custo extra.

## 8. Limites do plano gratuito a ficar de olho

- Firestore Spark: 1 GiB armazenamento, 50k leituras/dia, 20k escritas/dia, 20k
  exclusões/dia — folgado pro uso de uma pessoa. Se um dia mais gente usar o app
  ativamente, esse é o primeiro limite a observar.
- Hosting Spark: 10 GB armazenamento, 360 MB/dia de transferência — de sobra pra um
  app pessoal (o build web do Flutter fica na casa de poucos MB).
- Sem cartão de crédito cadastrado no plano Spark, o Firebase simplesmente bloqueia
  o uso ao bater a cota em vez de cobrar — ou seja, não tem risco de conta surpresa
  enquanto ficar no Spark.

## 9. Roadmap de execução

1. Criar projeto Firebase (Auth + Firestore) e configurar `flutterfire configure`.
2. `flutter create dindin_flutter`, estrutura de pastas acima, tema portado.
3. Telas de auth (login/cadastro email+senha, botão "Entrar com Google").
4. Modelos + `firestore_service.dart` (CRUD equivalente às API routes atuais).
5. Portar as 4 telas (Categorias, Receitas, Gastos, Dashboard) com a mesma lógica
   de agregação já validada no Next.js.
6. Tela de importar/exportar JSON; importar o `data/db.json` atual.
7. Testar nas 3 plataformas (Web, Android, Windows).
8. Deploy Web no Firebase Hosting.
9. Remover o código Next.js do repositório.
