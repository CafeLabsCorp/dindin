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

  const allocSalarioCasa = Allocation(id: 'a1', incomeId: 'i1', categoryId: 'c1', amount: 600, date: '2026-01-05');
  const allocSalarioLazer = Allocation(id: 'a2', incomeId: 'i1', categoryId: 'c2', amount: 300, date: '2026-01-05');
  const allocFreelaCasa = Allocation(id: 'a3', incomeId: 'i2', categoryId: 'c1', amount: 200, date: '2026-02-05');

  const despesaCasa = Expense(id: 'e1', date: '2026-01-10', amount: 150, categoryId: 'c1');
  const despesaLazer = Expense(id: 'e2', date: '2026-02-15', amount: 50, categoryId: 'c2');

  final db = AppDb(
    categories: [casa, lazer, semMovimento],
    incomes: [salario, freela],
    allocations: [allocSalarioCasa, allocSalarioLazer, allocFreelaCasa],
    expenses: [despesaCasa, despesaLazer],
  );

  test('monthKey extrai o prefixo YYYY-MM de uma data ISO', () {
    expect(monthKey('2026-03-17'), '2026-03');
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

    test('AppDb vazio não gera categorias', () {
      expect(categoryBalances(AppDb.empty), isEmpty);
    });
  });

  test('totalBalance soma o saldo de todas as categorias', () {
    expect(totalBalance(db), 900); // 650 + 250 + 0
  });

  group('unallocatedByIncome', () {
    test('subtrai o total já alocado do valor da receita', () {
      final unallocated = unallocatedByIncome(db);
      expect(unallocated['i1'], 100); // 1000 - (600 + 300)
      expect(unallocated['i2'], 300); // 500 - 200
    });

    test('receita sem nenhuma alocação fica com o valor cheio', () {
      const semAlocacao = Income(id: 'i3', date: '2026-03-01', amount: 400, source: IncomeSource.outro);
      final dbComExtra = AppDb(
        categories: db.categories,
        incomes: [...db.incomes, semAlocacao],
        allocations: db.allocations,
        expenses: db.expenses,
      );
      expect(unallocatedByIncome(dbComExtra)['i3'], 400);
    });
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

    test('mês diferente traz outros totais', () {
      final summary = monthSummary(db, '2026-02');
      expect(summary.totalIncome, 500);
      expect(summary.totalExpense, 50);
      expect(summary.net, 450);
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

  test('buildSummary combina saldo total, por categoria e histórico', () {
    final summary = buildSummary(db);
    expect(summary.total, totalBalance(db));
    expect(summary.balancesByCategory, categoryBalances(db));
    expect(summary.currentMonth.month, currentMonthKey());
    expect(summary.history.map((m) => m.month), allMonths(db));
  });
}
