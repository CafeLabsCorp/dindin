import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Canonical "caixinha color" identity component (`docs/DESIGN.md` §4): a
/// small filled circle + label, `6px` gap between them. Extracted from the
/// `_LegendDot` widget that used to live only in `dashboard_page.dart`'s
/// history chart legend, so it can be reused anywhere a caixinha/category
/// needs its color swatch next to its name (Dashboard caixinha rows,
/// Categorias list, transfer-dialog dropdowns, chart legends, ...).
///
/// Per the usage rule in §1.3: the color is decorative only — the [label]
/// text (rendered in the theme's default ink color) is what actually carries
/// the meaning, never the color alone.
class CaixinhaColorDot extends StatelessWidget {
  final Color color;
  final String label;

  /// Defaults to the original 12px caption style used by the chart legend.
  /// Callers using this as a row/list title (e.g. a caixinha's name, not a
  /// legend chip) can pass a bigger/heavier style instead.
  final TextStyle? labelStyle;

  const CaixinhaColorDot({super.key, required this.color, required this.label, this.labelStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: labelStyle ?? const TextStyle(fontSize: 12))),
      ],
    );
  }
}

/// Deterministic color assignment for a caixinha, given its position in the
/// (stable, `createdAt`-ordered) categories list — `categories.indexOf(cat)`.
/// No per-category color is stored on the model (out of scope for this pass,
/// and `lib/models/**` is closed), so every screen that shows a caixinha
/// color derives it the same way from the same ordered list, which keeps a
/// given caixinha's color consistent across Dashboard/Categorias/the transfer
/// dialog without needing new persisted state.
Color caixinhaPaletteColor(int index, {required bool dark}) {
  final palette = dark ? AppPalette.categoricalDark : AppPalette.categorical;
  if (index < 0) return palette[0];
  return palette[index % palette.length];
}
