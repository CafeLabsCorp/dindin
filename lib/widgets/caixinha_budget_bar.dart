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
          '${formatCurrency(spent)} de ${formatCurrency(limit)} este mês',
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
