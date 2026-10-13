import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Pull-down-to-refresh that re-runs the recurring-charge catch-up
/// (subscriptions and installment purchases that have come due).
///
/// The catch-up otherwise runs once per app open, so something that fell due
/// while the app stayed open would not post until a restart. The app shell
/// listens to the same provider, so the "N charges posted" snackbar still
/// appears when the pull actually charged something.
///
/// The [child] must be a scrollable that can always scroll (give a `ListView`
/// `physics: const AlwaysScrollableScrollPhysics()`), otherwise the gesture
/// does nothing when the content fits on screen.
class CatchUpRefresh extends ConsumerWidget {
  final Widget child;

  const CatchUpRefresh({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recurringChargesCatchUpProvider);
        try {
          await ref.read(recurringChargesCatchUpProvider.future);
        } catch (_) {
          // Already logged by the provider; the indicator just stops.
        }
      },
      child: child,
    );
  }
}
