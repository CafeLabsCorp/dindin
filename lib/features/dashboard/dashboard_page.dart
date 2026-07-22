import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/providers.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/caixinha_budget_bar.dart';
import '../../widgets/caixinha_color_dot.dart';
import '../../widgets/stat_tile.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(summaryProvider);
    final categories = ref.watch(categoriesProvider).value;

    if (summary == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final dark = Theme.of(context).brightness == Brightness.dark;

    final caixinhas =
        categories
            .map(
              (c) => (
                id: c.id,
                name: c.name,
                value: summary.balancesByCategory[c.id] ?? 0,
                createdAt: c.createdAt,
                monthlyBudget: c.monthlyBudget,
                spentThisMonth: summary.currentMonth.expenseByCategory[c.id] ?? 0,
                kind: c.effectiveKind,
                goalAmount: c.goalAmount,
                savedThisMonth: summary.savedThisMonthByCat[c.id] ?? 0,
                colorIndex: categories.indexOf(c),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final netColor = summary.currentMonth.net >= 0 ? context.tokens.statusGood : context.tokens.statusCritical;

    // §5.3: a caixinha is a valid transfer *origin* only if it has money to
    // move; the button itself is disabled rather than opening onto a
    // half-broken dialog when there's nothing eligible (mirrors the existing
    // "Alocar" disabled-when-impossible guard just below).
    final eligibleOrigins = categories.where((c) => (summary.balancesByCategory[c.id] ?? 0) > 0).toList();
    final canTransfer = categories.length >= 2 && eligibleOrigins.isNotEmpty;

    return ListView(
      children: [
        Text(l10n.dashboardTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.dashboardSubtitle, style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        StatTile(label: l10n.totalBalanceLabel, value: formatCurrency(summary.total)),
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
                      l10n.accountLabel,
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
                      l10n.accountBalanceDescription,
                      style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: categories.isEmpty || summary.accountBalance <= 0
                    ? null
                    : () => _showAllocateDialog(context, ref, categories, summary.accountBalance),
                child: Text(l10n.allocateButton),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final tiles = [
              StatTile(label: l10n.receivedThisMonthLabel, value: formatCurrency(summary.currentMonth.totalIncome)),
              StatTile(label: l10n.spentThisMonthLabel, value: formatCurrency(summary.currentMonth.totalExpense)),
              StatTile(label: l10n.monthBalanceLabel, value: formatCurrency(summary.currentMonth.net), color: netColor),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.caixinhasTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  FilledButton(
                    onPressed: canTransfer
                        ? () => _showTransferDialog(context, ref, categories, eligibleOrigins, summary.balancesByCategory)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    child: Text(l10n.transferButton),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (caixinhas.isEmpty)
                EmptyState(l10n.caixinhasEmptyState)
              else
                for (var i = 0; i < caixinhas.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i > 0 ? Border(top: BorderSide(color: context.tokens.border)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  CaixinhaColorDot(
                                    color: caixinhaPaletteColor(caixinhas[i].colorIndex, dark: dark),
                                    label: caixinhas[i].name,
                                    labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                  Text(
                                    l10n.sinceDatePrefix(formatDate(caixinhas[i].createdAt)),
                                    style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatCurrency(caixinhas[i].value),
                              style: TextStyle(
                                color: caixinhas[i].value < 0 ? context.tokens.statusCritical : context.tokens.muted,
                                fontWeight: caixinhas[i].value < 0 ? FontWeight.w600 : FontWeight.w400,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        if (caixinhas[i].kind == CategoryKind.save && caixinhas[i].goalAmount != null) ...[
                          const SizedBox(height: 8),
                          CaixinhaGoalBar(saved: caixinhas[i].value, goal: caixinhas[i].goalAmount!),
                        ] else if (caixinhas[i].kind == CategoryKind.save) ...[
                          const SizedBox(height: 4),
                          CaixinhaSavedThisMonth(savedThisMonth: caixinhas[i].savedThisMonth),
                        ] else ...[
                          // Spend caixinha: budget bar (month vs. limit) and
                          // debt indicator (all-time balance) are independent
                          // facts and can both show at once — see the
                          // Categorias list for the same pairing.
                          if (caixinhas[i].monthlyBudget != null) ...[
                            const SizedBox(height: 8),
                            CaixinhaBudgetBar(spent: caixinhas[i].spentThisMonth, limit: caixinhas[i].monthlyBudget!),
                          ],
                          if (caixinhas[i].value < 0) ...[
                            const SizedBox(height: 4),
                            CaixinhaDebtIndicator(balance: caixinhas[i].value),
                          ],
                        ],
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
                l10n.historyTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (summary.history.isEmpty)
                EmptyState(l10n.historyEmptyState)
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
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
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
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.allocateDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.availableInAccountLabel(formatCurrency(widget.accountBalance)),
            style: TextStyle(color: context.tokens.subtle),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.caixinhaLabel),
            items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submitting ? null : _confirm, child: Text(l10n.confirm)),
      ],
    );
  }
}

/// §5.3: mirrors `_AllocateDialog`'s shape exactly (same `showDialog`
/// unconditionally — not the wide/narrow `showAdaptiveFormSheet` used for the
/// §5.1 edit sheets — since this is meant to read as "the same kind of
/// dialog as Alocar", not a different interaction pattern).
Future<void> _showTransferDialog(
  BuildContext context,
  WidgetRef ref,
  List<Category> categories,
  List<Category> eligibleOrigins,
  Map<String, double> balancesByCategory,
) {
  return showDialog(
    context: context,
    builder: (ctx) => _TransferDialog(
      categories: categories,
      eligibleOrigins: eligibleOrigins,
      balancesByCategory: balancesByCategory,
      ref: ref,
    ),
  );
}

class _TransferDialog extends StatefulWidget {
  final List<Category> categories;
  final List<Category> eligibleOrigins;
  final Map<String, double> balancesByCategory;
  final WidgetRef ref;

  const _TransferDialog({
    required this.categories,
    required this.eligibleOrigins,
    required this.balancesByCategory,
    required this.ref,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late String _fromId = widget.eligibleOrigins.first.id;
  late String _toId = _firstDestinationExcluding(_fromId);
  final _amountController = TextEditingController();
  String? _error;
  bool _submitting = false;

  String _firstDestinationExcluding(String excludeId) {
    final candidates = widget.categories.where((c) => c.id != excludeId);
    return candidates.isNotEmpty ? candidates.first.id : excludeId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    if (_fromId == _toId) {
      setState(() => _error = l10n.originDestinationMustDifferError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ref.read(firestoreServiceProvider)!.createTransfer(
        fromCategoryId: _fromId,
        toCategoryId: _toId,
        amount: value,
        date: DateTime.now().toIso8601String().substring(0, 10),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fromBalance = widget.balancesByCategory[_fromId] ?? 0;
    final destinationOptions = widget.categories.where((c) => c.id != _fromId).toList();
    final toId = destinationOptions.any((c) => c.id == _toId)
        ? _toId
        : (destinationOptions.isNotEmpty ? destinationOptions.first.id : _toId);

    return AlertDialog(
      title: Text(l10n.transferDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.availableAtOriginLabel(formatCurrency(fromBalance)), style: TextStyle(color: context.tokens.subtle)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _fromId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.transferOriginLabel),
            items: [
              for (final c in widget.eligibleOrigins)
                DropdownMenuItem(
                  value: c.id,
                  child: CaixinhaColorDot(color: caixinhaPaletteColor(widget.categories.indexOf(c), dark: dark), label: c.name),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _fromId = v;
                if (_toId == _fromId) _toId = _firstDestinationExcluding(_fromId);
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: toId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.transferDestinationLabel),
            items: [
              for (final c in destinationOptions)
                DropdownMenuItem(
                  value: c.id,
                  child: CaixinhaColorDot(color: caixinhaPaletteColor(widget.categories.indexOf(c), dark: dark), label: c.name),
                ),
            ],
            onChanged: (v) => setState(() => _toId = v ?? _toId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submitting ? null : _confirm, child: Text(l10n.confirm)),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<dynamic> history;

  const _HistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark ? AppPalette.categoricalDark : AppPalette.categorical;
    final gridColor = context.tokens.border;
    final axisTextColor = context.tokens.subtle;

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
                getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
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
                          style: TextStyle(fontSize: 12, color: axisTextColor),
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
                      style: TextStyle(fontSize: 12, color: axisTextColor),
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
                        color: palette[0],
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: history[i].totalExpense as double,
                        color: palette[1],
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
            CaixinhaColorDot(color: palette[0], label: l10n.receivedLegend),
            const SizedBox(width: 16),
            CaixinhaColorDot(color: palette[1], label: l10n.spentLegend),
          ],
        ),
      ],
    );
  }
}
