import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/db.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/services/aggregation_service.dart';

void main() {
  const casa = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
  const lazer = Category(id: 'c2', name: 'Lazer', recurring: false, createdAt: '2026-01-01');
  const semMovimento = Category(id: 'c3', name: 'Sem movimento', recurring: false, createdAt: '2026-01-01');

  const salario = Income(id: 'i1', date: '2026-01-05', amount: 1000, source: IncomeSource.estagio);
  const freela = Income(id: 'i2', date: '2026-02-05', amount: 500, source: IncomeSource.freela);

  const allocCasa = Allocation(id: 'a1', categoryId: 'c1', amount: 600, date: '2026-01-05');
  const allocLazer = Allocation(id: 'a2', categoryId: 'c2', amount: 300, date: '2026-01-05');
  const allocCasaExtra = Allocation(id: 'a3', categoryId: 'c1', amount: 200, date: '2026-02-05');

  const despesaCasa = Expense(id: 'e1', date: '2026-01-10', amount: 150, categoryId: 'c1');
  const despesaLazer = Expense(id: 'e2', date: '2026-02-15', amount: 50, categoryId: 'c2');
  const despesaConta = Expense(id: 'e3', date: '2026-02-20', amount: 80, categoryId: null);

  final db = AppDb(
    categories: [casa, lazer, semMovimento],
    incomes: [salario, freela],
    allocations: [allocCasa, allocLazer, allocCasaExtra],
    expenses: [despesaCasa, despesaLazer, despesaConta],
  );

  test('monthKey extrai o prefixo YYYY-MM de uma data ISO', () {
    expect(monthKey('2026-03-17'), '2026-03');
  });

  group('accountBalance', () {
    test('é o total recebido menos o alocado menos os gastos diretos da conta', () {
      // 1500 recebido - 1100 alocado (600+300+200) - 80 gasto direto = 320
      expect(accountBalance(db), 320);
    });

    test('sem nenhum lançamento fica em zero', () {
      expect(accountBalance(AppDb.empty), 0);
    });
  });

  group('categoryBalances', () {
    test('soma alocações e subtrai despesas por categoria', () {
      final balances = categoryBalances(db);
      expect(balances['c1'], 650); // 600 + 200 - 150
      expect(balances['c2'], 250); // 300 - 50
    });

    test('categoria sem alocações nem despesas fica em zero', () {
      expect(categoryBalances(db)['c3'], 0);
    });

    test('gastos direto da conta (categoryId nulo) não entram em nenhuma caixinha', () {
      final balances = categoryBalances(db);
      expect(balances.values.fold(0.0, (s, v) => s + v), 900); // 650 + 250 + 0, sem o gasto da conta
    });

    test('AppDb vazio não gera categorias', () {
      expect(categoryBalances(AppDb.empty), isEmpty);
    });
  });

  test('totalBalance soma a conta com o saldo de todas as categorias', () {
    // 320 (conta) + 650 (c1) + 250 (c2) + 0 (c3) = 1220
    // equivale a: total recebido (1500) - total gasto (150+50+80=280) = 1220
    expect(totalBalance(db), 1220);
  });

  group('monthSummary', () {
    test('filtra receitas e despesas do mês pedido', () {
      final summary = monthSummary(db, '2026-01');
      expect(summary.month, '2026-01');
      expect(summary.totalIncome, 1000);
      expect(summary.totalExpense, 150);
      expect(summary.net, 850);
      expect(summary.incomeBySource, {'Estágio': 1000});
      expect(summary.expenseByCategory, {'c1': 150});
    });

    test('inclui gastos diretos da conta no total, mas não no detalhe por categoria', () {
      final summary = monthSummary(db, '2026-02');
      expect(summary.totalIncome, 500);
      expect(summary.totalExpense, 130); // 50 (c2) + 80 (conta)
      expect(summary.net, 370);
      expect(summary.incomeBySource, {'freela': 500});
      expect(summary.expenseByCategory, {'c2': 50});
    });

    test('mês sem nenhum lançamento fica zerado', () {
      final summary = monthSummary(db, '2099-12');
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
      expect(summary.net, 0);
      expect(summary.incomeBySource, isEmpty);
      expect(summary.expenseByCategory, isEmpty);
    });
  });

  test('allMonths retorna os meses únicos em ordem cronológica', () {
    expect(allMonths(db), ['2026-01', '2026-02']);
  });

  test('monthlyHistory gera um MonthSummary por mês existente', () {
    final history = monthlyHistory(db);
    expect(history.map((m) => m.month), ['2026-01', '2026-02']);
    expect(history[0].totalIncome, 1000);
    expect(history[1].totalIncome, 500);
  });

  test('currentMonthKey usa o formato YYYY-MM', () {
    expect(currentMonthKey(), matches(RegExp(r'^\d{4}-\d{2}$')));
  });

  test('buildSummary combina saldo total, da conta, por categoria e histórico', () {
    final summary = buildSummary(db);
    expect(summary.total, totalBalance(db));
    expect(summary.accountBalance, accountBalance(db));
    expect(summary.balancesByCategory, categoryBalances(db));
    expect(summary.currentMonth.month, currentMonthKey());
    expect(summary.history.map((m) => m.month), allMonths(db));
  });

  // ---------------------------------------------------------------------
  // Transfers: a pair of allocations sharing a transferId (negative leg on
  // the source, positive leg on the destination). Money-math regression:
  // the pair must net to zero against the account and simply move balance
  // between the two caixinhas.
  // ---------------------------------------------------------------------
  group('transferências (par de allocations com transferId)', () {
    const origem = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
    const destino = Category(id: 'c2', name: 'Lazer', recurring: false, createdAt: '2026-01-01');
    const receita = Income(id: 'i1', date: '2026-01-01', amount: 1000, source: IncomeSource.freela);
    // Pre-existing plain allocation funding the source caixinha.
    const allocOrigem = Allocation(id: 'a1', categoryId: 'c1', amount: 400, date: '2026-01-02');
    // The transfer pair: -150 on the source, +150 on the destination.
    const legOrigem = Allocation(
      id: 't1a',
      categoryId: 'c1',
      amount: -150,
      date: '2026-01-03',
      transferId: 'transfer-1',
    );
    const legDestino = Allocation(
      id: 't1b',
      categoryId: 'c2',
      amount: 150,
      date: '2026-01-03',
      transferId: 'transfer-1',
    );

    final dbComTransfer = AppDb(
      categories: [origem, destino],
      incomes: [receita],
      allocations: [allocOrigem, legOrigem, legDestino],
      expenses: const [],
    );

    test('o par neteia zero no total alocado e não afeta o saldo da conta', () {
      // totalAllocated soma tudo, incl. os dois legs: 400 - 150 + 150 = 400,
      // igual ao caso sem transferência nenhuma.
      expect(totalAllocated(dbComTransfer), 400);
      expect(accountBalance(dbComTransfer), 1000 - 400); // 600, como se a transferência não existisse
    });

    test('move o saldo exatamente entre as duas caixinhas', () {
      final balances = categoryBalances(dbComTransfer);
      expect(balances['c1'], 250); // 400 - 150
      expect(balances['c2'], 150); // 0 + 150
    });

    test('totalBalance é preservado (dinheiro só mudou de caixinha, não some nem aparece)', () {
      final semTransfer = AppDb(
        categories: [origem, destino],
        incomes: [receita],
        allocations: [allocOrigem],
        expenses: const [],
      );
      expect(totalBalance(dbComTransfer), totalBalance(semTransfer));
    });

    test('gasto na caixinha de destino após a transferência sai do saldo transferido', () {
      const gastoDestino = Expense(id: 'e1', date: '2026-01-10', amount: 100, categoryId: 'c2');
      final withExpense = AppDb(
        categories: [origem, destino],
        incomes: [receita],
        allocations: [allocOrigem, legOrigem, legDestino],
        expenses: [gastoDestino],
      );
      expect(categoryBalances(withExpense)['c2'], 50); // 150 - 100
    });
  });

  // ---------------------------------------------------------------------
  // Monthly budget per caixinha: `Category.monthlyBudget` (soft limit) vs.
  // `MonthSummary.expenseByCategory` (spent this month) — aggregation itself
  // doesn't compute a "spent vs budget" ratio, but this locks in that the
  // two numbers a screen would compare are each computed correctly and that
  // the field survives round-trip through the model.
  // ---------------------------------------------------------------------
  group('orçamento mensal por caixinha (monthlyBudget vs. spent)', () {
    const comLimite = Category(
      id: 'c1',
      name: 'Lazer',
      recurring: false,
      createdAt: '2026-01-01',
      monthlyBudget: 200,
    );
    const semLimite = Category(id: 'c2', name: 'Casa', recurring: true, createdAt: '2026-01-01');

    const gasto1 = Expense(id: 'e1', date: '2026-03-05', amount: 120, categoryId: 'c1');
    const gasto2 = Expense(id: 'e2', date: '2026-03-20', amount: 90, categoryId: 'c1');
    const gastoOutroMes = Expense(id: 'e3', date: '2026-04-01', amount: 500, categoryId: 'c1');

    final dbComLimite = AppDb(
      categories: [comLimite, semLimite],
      incomes: const [],
      allocations: const [],
      expenses: [gasto1, gasto2, gastoOutroMes],
    );

    test('spent do mês (expenseByCategory) soma só os gastos daquele mês, ultrapassando o limite', () {
      final summary = monthSummary(dbComLimite, '2026-03');
      final spent = summary.expenseByCategory['c1'];
      expect(spent, 210); // 120 + 90
      expect(spent! > comLimite.monthlyBudget!, isTrue); // 210 > 200 -> acima do limite
    });

    test('mês seguinte não herda o gasto do mês anterior (o limite é sempre "este mês")', () {
      final summary = monthSummary(dbComLimite, '2026-04');
      expect(summary.expenseByCategory['c1'], 500);
    });

    test('categoria sem monthlyBudget definido fica null (sem limite)', () {
      expect(semLimite.monthlyBudget, isNull);
    });

    test('monthlyBudget sobrevive ao round-trip toMap/fromMap', () {
      final map = comLimite.toMap();
      expect(map['monthlyBudget'], 200);
      final restored = Category.fromMap('c1', map);
      expect(restored.monthlyBudget, 200);
    });

    test('toMap omite monthlyBudget quando null (não escreve o campo)', () {
      final map = semLimite.toMap();
      expect(map.containsKey('monthlyBudget'), isFalse);
    });
  });

  group('caixinhas com propósito (kind) e meta (goalAmount)', () {
    test('kind e goalAmount sobrevivem ao round-trip toMap/fromMap', () {
      const cofrinho = Category(
        id: 'c1',
        name: 'Viagem',
        recurring: true,
        createdAt: '2026-01-01',
        kind: CategoryKind.save,
        goalAmount: 5000,
      );
      final restored = Category.fromMap('c1', cofrinho.toMap());
      expect(restored.kind, CategoryKind.save);
      expect(restored.goalAmount, 5000);
    });

    test('doc legado (sem kind) se comporta como envelope de gasto', () {
      final legado = Category.fromMap('c1', {
        'name': 'Casa',
        'recurring': true,
        'createdAt': '2026-01-01',
      });
      expect(legado.kind, isNull);
      expect(legado.effectiveKind, CategoryKind.spend);
    });

    test('toMap omite kind/goalAmount quando null (docs antigos não mudam de shape)', () {
      const legado = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
      final map = legado.toMap();
      expect(map.containsKey('kind'), isFalse);
      expect(map.containsKey('goalAmount'), isFalse);
    });

    test('savedThisMonthByCategory: alocações do mês menos gastos do mês, por caixinha', () {
      final db = AppDb(
        categories: const [
          Category(id: 'c1', name: 'Viagem', recurring: true, createdAt: '2026-01-01'),
        ],
        incomes: const [],
        allocations: const [
          Allocation(id: 'a1', categoryId: 'c1', amount: 300, date: '2026-03-05'),
          Allocation(id: 'a2', categoryId: 'c1', amount: 200, date: '2026-02-05'), // outro mês
        ],
        expenses: [
          Expense(id: 'e1', date: '2026-03-10', amount: 100, categoryId: 'c1'),
        ],
      );
      final saved = savedThisMonthByCategory(db, '2026-03');
      expect(saved['c1'], 200); // 300 alocado - 100 gasto, ignora fevereiro
    });

    test('savedThisMonthByCategory inclui pernas de transferência (com sinal)', () {
      final db = AppDb(
        categories: const [
          Category(id: 'origem', name: 'A', recurring: true, createdAt: '2026-01-01'),
          Category(id: 'destino', name: 'B', recurring: true, createdAt: '2026-01-01'),
        ],
        incomes: const [],
        allocations: const [
          Allocation(id: 't1', categoryId: 'origem', amount: -50, date: '2026-03-05', transferId: 'tx'),
          Allocation(id: 't2', categoryId: 'destino', amount: 50, date: '2026-03-05', transferId: 'tx'),
        ],
        expenses: const [],
      );
      final saved = savedThisMonthByCategory(db, '2026-03');
      expect(saved['origem'], -50);
      expect(saved['destino'], 50);
    });
  });
}
