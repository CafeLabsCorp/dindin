import 'package:flutter/material.dart';

/// The chevron that marks a page title as the menu button. A tonal circle (the
/// same "this is pressable" shape as the app's tonal buttons) instead of a bare
/// grey arrow that read as decoration (`docs/onboarding-design.md` §6).
class MenuChevronChip extends StatelessWidget {
  final double size;

  const MenuChevronChip({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
      child: Icon(Icons.expand_more, size: size * 0.7, color: scheme.onSecondaryContainer),
    );
  }
}
