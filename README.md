# dindin

Um produto [Café Labs](https://cafelabs.net).

App pessoal de controle financeiro por "caixinhas": receitas entram, são alocadas
entre categorias, e os gastos saem de cada categoria.

Flutter multiplataforma (Web, Android, Windows) com Firebase como backend.

## Stack

| Camada | Escolha |
|---|---|
| Framework | Flutter (stable) |
| Estado | Riverpod (`flutter_riverpod`) |
| Roteamento | `go_router` |
| Gráficos | `fl_chart` |
| Datas/moeda | `intl` (`pt_BR` / BRL) |
| Backend | Firebase (Auth + Firestore), projeto `dindin-cafelabs` |

## Modelo de dados

Firestore, particionado por usuário:

```
users/{uid}
  categories/{categoryId}    { name, recurring, createdAt }
  incomes/{incomeId}         { date, amount, source, description }
  allocations/{allocationId} { incomeId, categoryId, amount, date }
  expenses/{expenseId}       { date, amount, categoryId, description }
```

## Estrutura

```
lib/
  main.dart
  app.dart                    # MaterialApp.router + tema
  theme/                      # cores e ThemeData
  models/                     # Category, Income, Allocation, Expense
  providers/                  # providers Riverpod
  services/
    auth_service.dart         # login email/senha + Google
    firestore_service.dart    # CRUD por coleção, sob users/{uid}/...
    aggregation_service.dart  # saldo por caixinha, resumo mensal
    import_export_service.dart# backup/restore em JSON
  features/
    auth/login_page.dart
    dashboard/dashboard_page.dart
    categorias/categorias_page.dart
    receitas/receitas_page.dart
    gastos/gastos_page.dart
    settings/settings_page.dart
  widgets/
```

## Rodando localmente

```bash
flutter pub get
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run                # Android (emulador/dispositivo conectado)
```

## Build e deploy

```bash
flutter build web
firebase deploy --only hosting --project dindin-cafelabs
```

Web publicado em https://dindin-cafelabs.web.app.

## Backup/restore

Em Ajustes, dá pra exportar todos os dados do usuário pra um `.json` e importar de
volta (substitui os dados atuais) — útil tanto como backup manual quanto para migrar
dados entre contas/ambientes.
