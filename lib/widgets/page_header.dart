import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The title + subtitle every screen opens with — and, on narrow screens, the
/// app's navigation.
///
/// There used to be an app bar above this showing the same screen name, so
/// "Dashboard" appeared twice, one line apart. Rather than delete one of the
/// two, the page's own title absorbed the app bar's job: it grows a chevron
/// and opens the menu. One name on screen, and the thing you tap is the thing
/// you're reading.
///
/// [onOpenMenu] is null on wide screens (the side rail is the navigation
/// there) — the header then renders as a plain, non-interactive title.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  /// Opens the navigation menu. Null = not a menu (wide screens).
  final VoidCallback? onOpenMenu;

  /// Tooltip/semantic label for the menu affordance, so a screen reader
  /// announces the title as something that opens navigation.
  final String? menuLabel;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onOpenMenu,
    this.menuLabel,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onOpenMenu == null)
          Text(title, style: titleStyle)
        else
          Semantics(
            button: true,
            label: menuLabel,
            child: Tooltip(
              message: menuLabel ?? '',
              child: InkWell(
                onTap: onOpenMenu,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  // Negative-looking inset: the tap target extends past the
                  // text so it's comfortably tappable, while the text itself
                  // still lines up with the content below it.
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 26, color: context.tokens.subtle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Padding(
          // Matches the InkWell's horizontal inset so title and subtitle stay
          // on the same left edge.
          padding: EdgeInsets.only(left: onOpenMenu == null ? 0 : 6),
          child: Text(subtitle, style: TextStyle(color: context.tokens.muted)),
        ),
      ],
    );
  }
}
