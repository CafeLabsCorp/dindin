import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/format.dart';

/// Shared "spent vs. monthly limit" visualization (`docs/DESIGN.md` §5.2),
/// used both on the Categorias list and the Dashboard "Caixinhas" card so a
/// user learns the pattern once and recognizes it in both places.
///
/// Callers are expected to only render this when a limit is actually set —
/// "no limit set" is its own empty state (no bar at all, not this widget with
/// a zero limit).
class CaixinhaBudgetBar extends StatelessWidget {
  final double spent;
  final double limit;

  const CaixinhaBudgetBar({super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final over = spent - limit;

    final Color fill;
    if (ratio > 1) {
      fill = context.tokens.statusCritical;
    } else if (ratio >= 0.8) {
      fill = context.tokens.statusWarning;
    } else {
      fill = Theme.of(context).colorScheme.secondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: context.tokens.border,
            valueColor: AlwaysStoppedAnimation(fill),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gasto: ${formatCurrency(spent)} de ${formatCurrency(limit)} este mês',
          style: TextStyle(fontSize: 12, color: context.tokens.subtle),
        ),
        if (ratio > 1)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+${formatCurrency(over)} acima do limite',
              style: TextStyle(fontSize: 12, color: context.tokens.statusCritical, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Progress toward a savings goal for a "guardar" caixinha: how much of the
/// target amount is already sitting in the box. Unlike [CaixinhaBudgetBar]
/// (a consumption meter that turns alarming as it fills), filling up here is
/// success — the bar uses the primary color and flips to statusGood when the
/// goal is reached.
class CaixinhaGoalBar extends StatelessWidget {
  final double saved;
  final double goal;

  const CaixinhaGoalBar({super.key, required this.saved, required this.goal});

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : saved / goal;
    final reached = ratio >= 1;
    final pct = (ratio * 100).clamp(0, 999).toStringAsFixed(0);
    final fill = reached ? context.tokens.statusGood : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: context.tokens.border,
            valueColor: AlwaysStoppedAnimation(fill),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          reached
              ? 'Meta atingida: ${formatCurrency(saved)} de ${formatCurrency(goal)} guardados'
              : '${formatCurrency(saved)} de ${formatCurrency(goal)} guardados ($pct%)',
          style: TextStyle(
            fontSize: 12,
            color: reached ? context.tokens.statusGood : context.tokens.subtle,
            fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Feedback line for a "guardar" caixinha with no goal set: the month's net
/// inflow ("Guardou +R$ 200,00 este mês"). Renders nothing when the month is
/// flat — a caixinha simply resting doesn't need a status line.
class CaixinhaSavedThisMonth extends StatelessWidget {
  final double savedThisMonth;

  const CaixinhaSavedThisMonth({super.key, required this.savedThisMonth});

  @override
  Widget build(BuildContext context) {
    if (savedThisMonth == 0) return const SizedBox.shrink();
    final positive = savedThisMonth > 0;
    return Text(
      positive
          ? 'Guardou +${formatCurrency(savedThisMonth)} este mês'
          : 'Retirou ${formatCurrency(-savedThisMonth)} este mês',
      style: TextStyle(
        fontSize: 12,
        color: positive ? context.tokens.statusGood : context.tokens.subtle,
      ),
    );
  }
}
