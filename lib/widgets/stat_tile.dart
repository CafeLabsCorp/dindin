import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatTile({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: context.tokens.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          // Shrinks a long amount instead of wrapping it ("R$ 4.000,0" / "0")
          // when the tile is narrow, e.g. three across on a small tablet.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
