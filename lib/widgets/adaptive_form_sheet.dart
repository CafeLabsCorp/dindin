import 'package:flutter/material.dart';

/// Shows [contentBuilder] as a centered `Dialog` on wide screens (≥720px —
/// the same breakpoint `AppShell` already uses for rail-vs-bottom-nav) or as
/// a `showModalBottomSheet(isScrollControlled: true)` with a drag handle on
/// narrow ones.
///
/// This is the one "wide vs. narrow" rule every edit sheet in the app shares
/// (`docs/DESIGN.md` §5.1/§5.2: dialogs are the desktop/web-native affordance
/// for a short form, bottom sheets are the mobile-native one) — a single
/// helper instead of a bespoke branch per feature.
Future<T?> showAdaptiveFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder contentBuilder,
  double maxDialogWidth = 480,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;

  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth),
          child: Padding(
            padding: const EdgeInsets.all(24),
            // Unlike the narrow/bottom-sheet path below, `Dialog` doesn't cap
            // its child's height to the viewport on its own — a form tall
            // enough (e.g. one with a conditionally-shown hint/warning line)
            // would overflow instead of scrolling. Mirror the bottom sheet's
            // `SingleChildScrollView` so variable-length content is always
            // accommodated the same way in both breakpoints.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
              child: SingleChildScrollView(child: contentBuilder(ctx)),
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                contentBuilder(ctx),
              ],
            ),
          ),
        ),
      );
    },
  );
}
