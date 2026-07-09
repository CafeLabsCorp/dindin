import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../providers/providers.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_tile.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final categories = ref.watch(categoriesProvider).value;

    if (summary == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final caixinhas = categories
        .map((c) => (id: c.id, name: c.name, value: summary.balancesByCategory[c.id] ?? 0, createdAt: c.createdAt))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final netColor = summary.currentMonth.net >= 0 ? AppPalette.statusGood : AppPalette.statusCritical;

    return ListView(
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Visão geral da conta e do mês atual.', style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        StatTile(label: 'Saldo total', value: formatCurrency(summary.total)),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conta',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.tokens.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(summary.accountBalance),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dinheiro recebido e ainda não alocado em nenhuma caixinha.',
                      style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: categories.isEmpty || summary.accountBalance <= 0
                    ? null
                    : () => _showAllocateDialog(context, ref, categories, summary.accountBalance),
                child: const Text('Alocar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final tiles = [
              StatTile(label: 'Recebido este mês', value: formatCurrency(summary.currentMonth.totalIncome)),
              StatTile(label: 'Gasto este mês', value: formatCurrency(summary.currentMonth.totalExpense)),
              StatTile(label: 'Saldo do mês', value: formatCurrency(summary.currentMonth.net), color: netColor),
            ];
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final t in tiles) ...[t, const SizedBox(height: 12)]],
              );
            }
            return Row(
              children: [for (final t in tiles) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: t))],
            );
          },
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Caixinhas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (caixinhas.isEmpty)
                const EmptyState('Crie categorias e aloque receitas para ver suas caixinhas aqui.')
              else
                for (var i = 0; i < caixinhas.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i > 0 ? Border(top: BorderSide(color: context.tokens.border)) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(caixinhas[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                'desde ${formatDate(caixinhas[i].createdAt)}',
                                style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                              ),
                            ],
                          ),
                        ),
                        Text(formatCurrency(caixinhas[i].value), style: TextStyle(color: context.tokens.muted)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Histórico mensal — recebido x gasto',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (summary.history.isEmpty)
                const EmptyState('Lance receitas e gastos para ver o histórico por mês.')
              else
                SizedBox(height: 280, child: _HistoryChart(history: summary.history)),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showAllocateDialog(
  BuildContext context,
  WidgetRef ref,
  List<Category> categories,
  double accountBalance,
) {
  return showDialog(
    context: context,
    builder: (ctx) => _AllocateDialog(categories: categories, accountBalance: accountBalance, ref: ref),
  );
}

class _AllocateDialog extends StatefulWidget {
  final List<Category> categories;
  final double accountBalance;
  final WidgetRef ref;

  const _AllocateDialog({required this.categories, required this.accountBalance, required this.ref});

  @override
  State<_AllocateDialog> createState() => _AllocateDialogState();
}

class _AllocateDialogState extends State<_AllocateDialog> {
  late String _categoryId = widget.categories.first.id;
  final _amountController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = 'Informe um valor válido.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ref.read(firestoreServiceProvider)!.createAllocation(
        categoryId: _categoryId,
        amount: value,
        date: DateTime.now().toIso8601String().substring(0, 10),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alocar pra caixinha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Disponível na conta: ${formatCurrency(widget.accountBalance)}', style: TextStyle(color: context.tokens.subtle)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Caixinha'),
            items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', hintText: '0,00'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submitting ? null : _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<dynamic> history;

  const _HistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final m in history) {
      if (m.totalIncome > maxY) maxY = m.totalIncome as double;
      if (m.totalExpense > maxY) maxY = m.totalExpense as double;
    }
    maxY = maxY <= 0 ? 100 : maxY * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: AppPalette.inkGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= history.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          formatMonthLabel(history[i].month as String),
                          style: TextStyle(fontSize: 12, color: AppPalette.inkMuted),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 64,
                    getTitlesWidget: (value, meta) => Text(
                      formatCurrencyCompact(value),
                      style: TextStyle(fontSize: 12, color: AppPalette.inkMuted),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(formatCurrency(rod.toY), const TextStyle(color: Colors.white, fontSize: 12));
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < history.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: history[i].totalIncome as double,
                        color: AppPalette.categorical[0],
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: history[i].totalExpense as double,
                        color: AppPalette.categorical[1],
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                    barsSpace: 4,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppPalette.categorical[0], label: 'Recebido'),
            const SizedBox(width: 16),
            _LegendDot(color: AppPalette.categorical[1], label: 'Gasto'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
