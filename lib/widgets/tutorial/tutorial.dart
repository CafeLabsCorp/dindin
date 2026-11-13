import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';

/// One step of an onboarding tutorial: a real widget of the screen (found by
/// [target]) is lit up and a balloon explains it. `docs/onboarding-design.md`,
/// direction A "Lanterna".
class TutorialStep {
  /// Key of the widget to highlight. It must be mounted when the step shows:
  /// a widget in a lazily built list that is far below the fold isn't built
  /// yet and can't be found, so pick targets near the top or in the first
  /// screenful, or the tutorial ends as [TutorialResult.unavailable].
  final GlobalKey target;
  final String title;
  final String body;

  /// Corner radius of the highlighted element; the cut-out adds 4 dp to it.
  final double radius;

  /// When set, tapping the lit-up element runs this and ends the tutorial as
  /// done (the single "guided by the action" step: the page-title menu).
  final VoidCallback? onTargetTap;

  const TutorialStep({
    required this.target,
    required this.title,
    required this.body,
    this.radius = 12,
    this.onTargetTap,
  });
}

/// How a tutorial ended. Back, Esc and "Pular" are all [skipped]. [unavailable]
/// means a step's target wasn't on screen (the page changed under the
/// tutorial, or the widget sits in a lazily built list far below the fold):
/// the caller must NOT mark the tutorial as seen, so it can try again later.
enum TutorialResult { done, skipped, unavailable }

/// Shows [steps] one at a time over the current screen and completes when the
/// user finishes, skips or goes back. [pageName] is only used for the
/// screen-reader announcement ("Tutorial de Receitas, passo 1 de 3...").
Future<TutorialResult> showTutorial(
  BuildContext context, {
  required String pageName,
  required List<TutorialStep> steps,
}) async {
  assert(steps.isNotEmpty);
  final result = await Navigator.of(context, rootNavigator: true).push<TutorialResult>(
    _TutorialRoute(pageName: pageName, steps: steps, reduceMotion: MediaQuery.disableAnimationsOf(context)),
  );
  return result ?? TutorialResult.skipped;
}

class _TutorialRoute extends PopupRoute<TutorialResult> {
  final String pageName;
  final List<TutorialStep> steps;
  final bool reduceMotion;

  _TutorialRoute({required this.pageName, required this.steps, required this.reduceMotion});

  @override
  Color? get barrierColor => null; // the veil is painted with the cut-out

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: animation,
      child: _TutorialScreen(pageName: pageName, steps: steps),
    );
  }
}

class _TutorialScreen extends StatefulWidget {
  final String pageName;
  final List<TutorialStep> steps;

  const _TutorialScreen({required this.pageName, required this.steps});

  @override
  State<_TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<_TutorialScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _slide = Duration(milliseconds: 280);

  late final AnimationController _move;
  int _index = 0;
  Rect? _from;
  Rect? _to;
  bool _scrolling = false;

  TutorialStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    // Created here (not lazily): dispose() must not build it on a dead element
    // when the tutorial ends before its first step ever showed.
    _move = AnimationController(vsync: this, duration: _slide);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToStep(0, first: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _move.dispose();
    super.dispose();
  }

  /// Rotation, window resize or keyboard: the target moved, so measure again.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrolling) return;
      final rect = _measure();
      if (rect != null && rect != _to) setState(() => _to = rect);
    });
  }

  /// The target's rectangle in this overlay's coordinates, or null when it
  /// isn't on screen (not mounted, not laid out).
  Rect? _measure() {
    final targetContext = _step.target.currentContext;
    final overlayBox = context.findRenderObject();
    if (targetContext == null || overlayBox is! RenderBox || !overlayBox.hasSize) return null;
    final box = targetContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  }

  Future<void> _goToStep(int index, {bool first = false}) async {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final previous = _to;
    _index = index;
    final targetContext = _step.target.currentContext;
    if (targetContext != null) {
      _scrolling = true;
      try {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.3,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // Not inside a scrollable: nothing to scroll.
      }
      _scrolling = false;
    }
    if (!mounted) return;
    final rect = _measure();
    if (rect == null) {
      // The widget isn't there (the screen changed under us): end quietly,
      // without counting it as seen.
      Navigator.of(context).pop(TutorialResult.unavailable);
      return;
    }
    setState(() {
      _from = first || reduce ? rect : (previous ?? rect);
      _to = rect;
    });
    if (first || reduce) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop(TutorialResult.done);
    } else {
      _goToStep(_index + 1);
    }
  }

  void _skip() => Navigator.of(context).pop(TutorialResult.skipped);

  void _tapTarget() {
    final callback = _step.onTargetTap;
    if (callback == null) return;
    Navigator.of(context).pop(TutorialResult.done);
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final to = _to;
    final announcement = l10n.tutorialAnnouncement(
      widget.pageName,
      _index + 1,
      widget.steps.length,
      _step.title,
      _step.body,
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _skip},
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: announcement,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Stack(
                children: [
                  if (to != null)
                    AnimatedBuilder(
                      animation: _move,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(_move.value);
                        final rect = Rect.lerp(_from ?? to, to, t)!;
                        final hole = _holeFor(rect, _step.radius);
                        return Positioned.fill(
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                if (hole.rect.contains(details.localPosition)) _tapTarget();
                              },
                              child: CustomPaint(
                                painter: _SpotlightPainter(
                                  hole: hole,
                                  veil: dark
                                      ? AppPalette.darkBackground.withValues(alpha: 0.72)
                                      : AppPalette.lightInkPrimary.withValues(alpha: 0.60),
                                  ring: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (to != null)
                    Positioned.fill(
                      child: _BalloonPlacement(
                        key: ValueKey(_index),
                        screen: size,
                        hole: _holeFor(to, _step.radius).rect,
                        padding: MediaQuery.paddingOf(context),
                        reduceMotion: MediaQuery.disableAnimationsOf(context),
                        balloon: _Balloon(
                          number: _index + 1,
                          total: widget.steps.length,
                          title: _step.title,
                          body: _step.body,
                          isLast: _isLast,
                          onNext: _next,
                          onSkip: _skip,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

({Rect rect, double radius}) _holeFor(Rect target, double radius) {
  final margin = target.height < 48 ? 6.0 : 4.0;
  return (rect: target.inflate(margin), radius: radius + 4);
}

class _SpotlightPainter extends CustomPainter {
  final ({Rect rect, double radius}) hole;
  final Color veil;
  final Color ring;

  _SpotlightPainter({required this.hole, required this.veil, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final cut = RRect.fromRectAndRadius(hole.rect, Radius.circular(hole.radius));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(cut),
    );
    canvas.drawPath(path, Paint()..color = veil);
    canvas.drawRRect(
      cut,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.veil != veil || old.ring != ring;
}

/// Places the balloon below the lit-up element, above it, or docked at the
/// bottom of the screen without an arrow when neither fits (large element,
/// small screen, big font).
class _BalloonPlacement extends StatelessWidget {
  final Size screen;
  final Rect hole;
  final EdgeInsets padding;
  final bool reduceMotion;
  final Widget balloon;

  const _BalloonPlacement({
    super.key,
    required this.screen,
    required this.hole,
    required this.padding,
    required this.reduceMotion,
    required this.balloon,
  });

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).extension<AppTokens>()!;
    final surface = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.darkSurfaceElevated
        : AppPalette.lightSurfaceElevated;
    final child = CustomMultiChildLayout(
      delegate: _BalloonLayout(screen: screen, hole: hole, padding: padding),
      children: [
        LayoutId(id: _BalloonPart.balloon, child: balloon),
        LayoutId(id: _BalloonPart.arrowUp, child: _Arrow(up: true, color: surface, border: fill.border)),
        LayoutId(id: _BalloonPart.arrowDown, child: _Arrow(up: false, color: surface, border: fill.border)),
      ],
    );
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c)),
      child: child,
    );
  }
}

enum _BalloonPart { balloon, arrowUp, arrowDown }

class _BalloonLayout extends MultiChildLayoutDelegate {
  final Size screen;
  final Rect hole;
  final EdgeInsets padding;

  _BalloonLayout({required this.screen, required this.hole, required this.padding});

  static const _gap = 12.0;
  static const _arrow = Size(16, 8);

  @override
  void performLayout(Size size) {
    final side = size.width <= 320 ? 12.0 : 16.0;
    final width = math.min(328.0, size.width - 2 * side);
    final balloon = layoutChild(_BalloonPart.balloon, BoxConstraints.tightFor(width: width));
    final left = ((size.width - width) / 2).clamp(side, size.width - side - width).toDouble();

    final top = padding.top + _gap;
    final bottom = size.height - padding.bottom - _gap;
    final needed = balloon.height + _arrow.height;
    final below = bottom - (hole.bottom + _gap);
    final above = (hole.top - _gap) - top;

    Offset position;
    _BalloonPart? arrow;
    if (needed <= below) {
      position = Offset(left, hole.bottom + _gap + _arrow.height);
      arrow = _BalloonPart.arrowUp;
    } else if (needed <= above) {
      position = Offset(left, hole.top - _gap - _arrow.height - balloon.height);
      arrow = _BalloonPart.arrowDown;
    } else {
      // Docked: the lit-up element keeps its ring, the balloon has no arrow.
      position = Offset(left, math.max(top, bottom - balloon.height));
    }
    positionChild(_BalloonPart.balloon, position);

    for (final part in [_BalloonPart.arrowUp, _BalloonPart.arrowDown]) {
      if (part == arrow) {
        layoutChild(part, BoxConstraints.tight(_arrow));
        final x = (hole.center.dx - _arrow.width / 2).clamp(left + 20, left + width - 20 - _arrow.width).toDouble();
        final y = part == _BalloonPart.arrowUp ? position.dy - _arrow.height + 1 : position.dy + balloon.height - 1;
        positionChild(part, Offset(x, y));
      } else {
        layoutChild(part, BoxConstraints.tight(Size.zero));
        positionChild(part, Offset.zero);
      }
    }
  }

  @override
  bool shouldRelayout(_BalloonLayout old) => old.screen != screen || old.hole != hole || old.padding != padding;
}

class _Arrow extends StatelessWidget {
  final bool up;
  final Color color;
  final Color border;

  const _Arrow({required this.up, required this.color, required this.border});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(painter: _ArrowPainter(up: up, color: color, border: border)),
      );
}

class _ArrowPainter extends CustomPainter {
  final bool up;
  final Color color;
  final Color border;

  _ArrowPainter({required this.up, required this.color, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(Path.from(path)..close(), Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up || old.color != color || old.border != border;
}

class _Balloon extends StatelessWidget {
  final int number;
  final int total;
  final String title;
  final String body;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Balloon({
    required this.number,
    required this.total,
    required this.title,
    required this.body,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>()!;
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? AppPalette.darkSurfaceElevated : AppPalette.lightSurfaceElevated;
    final ink = dark ? AppPalette.darkInkPrimary : AppPalette.lightInkPrimary;

    final counter = Text(
      l10n.tutorialStepCounter(number, total),
      style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 12, height: 16 / 12, color: tokens.subtle),
    );
    final actions = [
      TextButton(
        onPressed: onSkip,
        style: TextButton.styleFrom(
          foregroundColor: tokens.muted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(l10n.tutorialSkip),
      ),
      FilledButton(
        autofocus: true,
        onPressed: onNext,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Text(isLast ? l10n.tutorialGotIt : l10n.tutorialNext),
      ),
    ];

    return Material(
      color: surface,
      elevation: 3,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$number.',
                  style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, fontSize: 22, height: 26 / 22, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, fontSize: 18, height: 24 / 18, color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w400, fontSize: 15, height: 22 / 15, color: tokens.muted),
            ),
            const SizedBox(height: 4),
            // Counter on the left, buttons on the right; when the balloon is too
            // narrow for both (320 px screens, big fonts) the buttons wrap to
            // a second line instead of overflowing.
            Row(
              children: [
                counter,
                // Takes whatever the counter leaves; only wraps when the two
                // buttons really don't fit side by side.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: actions,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
