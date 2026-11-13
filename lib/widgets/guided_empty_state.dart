import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';

/// An empty state that tells the user what to do next: a small illustration,
/// a title, one or two sentences and a button with a verb
/// (`docs/onboarding-design.md` §4). Used where a list is empty because the
/// user hasn't added anything yet. A list that is empty only because of a date
/// filter keeps the plain [EmptyState] with "Limpar filtro" instead.
class GuidedEmptyState extends StatelessWidget {
  final Widget illustration;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const GuidedEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ink = theme.brightness == Brightness.dark ? const Color(0xFFF5F1EA) : const Color(0xFF211A12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative: the title carries the meaning for a screen reader.
            ExcludeSemantics(child: SizedBox(height: 72, child: Center(child: illustration))),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, fontSize: 17, height: 24 / 17, color: ink),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                // The instruction, not a caption: secondary ink, not "subtle".
                style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, height: 20 / 14, color: tokens.muted),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// Scrolls the page to [target] and puts the cursor in [field]: what the
/// button of an empty state does when the form it points to is on the same
/// page.
Future<void> scrollToAndFocus(GlobalKey target, FocusNode field) async {
  final context = target.currentContext;
  if (context != null) {
    await Scrollable.ensureVisible(
      context,
      alignment: 0.1,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
  field.requestFocus();
}

// Illustrations: all from the brand's repertoire (`marca/dindin/elementos`),
// one motif per page so the empty states don't all look the same.

/// One Dindin coin (money coming in).
class CoinIllustration extends StatelessWidget {
  final double height;

  const CoinIllustration({super.key, this.height = 64});

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/illustrations/dindin-moeda.svg', height: height);
}

/// Three coins in a rising ladder (the brand's limit of three per piece).
class CoinsLadderIllustration extends StatelessWidget {
  const CoinsLadderIllustration({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      CoinIllustration(height: 34),
      SizedBox(width: 6),
      CoinIllustration(height: 48),
      SizedBox(width: 6),
      CoinIllustration(height: 64),
    ],
  );
}

/// A single-stroke line icon in the leaf green, light or dark variant.
class LineIconIllustration extends StatelessWidget {
  final IconData icon;

  const LineIconIllustration(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Leaf green on light; the lighter leaf green on dark, so it doesn't sink
    // into the background.
    return Icon(icon, size: 56, color: dark ? const Color(0xFF7FCB9E) : const Color(0xFF3A604B));
  }
}

/// A pair of leaves, one mirrored.
class LeavesIllustration extends StatelessWidget {
  const LeavesIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/illustrations/dindin-ramo-alto-fundo-escuro.svg'
        : 'assets/illustrations/dindin-ramo-alto-fundo-claro.svg';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(asset, height: 72),
        const SizedBox(width: 24),
        Transform.flip(flipX: true, child: SvgPicture.asset(asset, height: 72)),
      ],
    );
  }
}
