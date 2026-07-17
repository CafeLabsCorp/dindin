import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// `docs/DESIGN.md` §4: elevation 1 + hairline border + transparent surface
/// tint (kept explicit here, on top of the matching `CardThemeData` defaults
/// in `theme.dart`, so this component reads correctly on its own too).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.tokens.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;

  /// Optional slot for an inline action (e.g. "Limpar filtro") so a
  /// filtered-empty state doesn't force the user to scroll back up to find
  /// the way out (`docs/DESIGN.md` §5.4).
  final Widget? action;

  const EmptyState(this.message, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.tokens.subtle),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
