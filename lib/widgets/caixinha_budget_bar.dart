import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    // `spent` is always a sum of non-negative expense amounts for the current
    // month (see `MonthSummary.expenseByCategory`) — it tracks monthly
    // consumption against the soft budget, which is a different number from
    // the caixinha's all-time running balance (which CAN be negative now that
    // "allow negative balance" exists; see [CaixinhaDebtIndicator] for that).
    // Guarded defensively anyway so a future/unexpected negative input can't
    // flip the ratio sign or blow past the bar's 0–100% width.
    final safeSpent = spent < 0 ? 0.0 : spent;
    final ratio = limit <= 0 ? 0.0 : safeSpent / limit;
    final over = safeSpent - limit;

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
          l10n.budgetSpentOfLimit(formatCurrency(safeSpent), formatCurrency(limit)),
          style: TextStyle(fontSize: 12, color: context.tokens.subtle),
        ),
        if (ratio > 1)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.budgetOverLimit(formatCurrency(over)),
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
    final l10n = AppLocalizations.of(context)!;
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
              ? l10n.goalReached(formatCurrency(saved), formatCurrency(goal))
              : l10n.goalProgress(formatCurrency(saved), formatCurrency(goal), pct),
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
    final l10n = AppLocalizations.of(context)!;
    final positive = savedThisMonth > 0;
    return Text(
      positive
          ? l10n.savedThisMonthPositive(formatCurrency(savedThisMonth))
          : l10n.savedThisMonthNegative(formatCurrency(-savedThisMonth)),
      style: TextStyle(
        fontSize: 12,
        color: positive ? context.tokens.statusGood : context.tokens.subtle,
      ),
    );
  }
}

/// Debt indicator for a "gastar" caixinha whose running balance has gone
/// negative (only reachable when its "permitir saldo negativo" toggle is, or
/// was, on — see `Category.allowsNegativeBalance`). Independent from
/// [CaixinhaBudgetBar]: that widget tracks *this month's* spend against a
/// soft monthly limit, while this tracks the caixinha's *all-time running
/// balance* — a caixinha can be mid-month under budget and still be in debt
/// (or vice versa), so both can render side by side. Renders nothing when
/// [balance] is non-negative — a healthy caixinha needs no extra line, same
/// convention as [CaixinhaSavedThisMonth].
///
/// Reuses the same visual language as [CaixinhaBudgetBar]'s "acima do
/// limite" caption (plain bold `statusCritical` text, no bar/badge) rather
/// than inventing a new pattern for "this number is bad".
class CaixinhaDebtIndicator extends StatelessWidget {
  final double balance;

  const CaixinhaDebtIndicator({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    if (balance >= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.debtIndicator(formatCurrency(-balance)),
      style: TextStyle(fontSize: 12, color: context.tokens.statusCritical, fontWeight: FontWeight.w600),
    );
  }
}
