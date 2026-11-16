import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/theme_provider.dart';
import '../theme/colors.dart';

/// Plays the opening animation on top of [child] (the whole app, already
/// building underneath), then removes itself: the money bag sits at its normal
/// size, coins fall into it from above the screen and each one makes it shake a
/// little; then it comes forward and the app shows through.
///
/// Not shown when the system asks for reduced motion. Lives in `main()`, above
/// `DindinApp`, so widget tests of the app never see it.
class SplashGate extends ConsumerStatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  /// Total length of the animation (the last ~20% is the way into the app).
  static const duration = Duration(milliseconds: 1500);

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _playing;

  @override
  void initState() {
    super.initState();
    _playing = !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _controller = AnimationController(vsync: this, duration: SplashGate.duration);
    if (_playing) {
      _controller.forward().whenComplete(() {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_playing) return widget.child;
    final mode = ref.watch(themeModeProvider);
    final platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final dark = mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        widget.child,
        // Absorbs touches until the animation ends, and stays out of the
        // screen reader: it is decoration.
        ExcludeSemantics(
          // Above the MaterialApp, so there is no Directionality yet.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AbsorbPointer(
              child: _SplashOverlay(
                animation: _controller,
                background: dark ? AppPalette.darkBackground : AppPalette.lightBackground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Color background;
  const _SplashOverlay({required this.animation, required this.background});

  static const _totalMs = 1500.0;
  // Each coin: when it starts to fall, how long the fall takes (ms), its x
  // offset (in bag-sizes) and a little tilt (radians) so they don't look cloned.
  static const _coinStartMs = [120.0, 320.0, 520.0];
  static const _fallMs = 300.0;
  static const _coinX = [-0.04, 0.045, 0.0];
  static const _coinTilt = [-0.25, 0.3, -0.15];
  // How hard each landing shakes the bag (the last one a bit more).
  static const _hit = [0.8, 1.0, 1.3];
  static const _exitStartMs = 1180.0;

  /// A damped shake that starts at 0, swings and dies out: the bag's reaction
  /// to a coin landing. [since] is the time since the landing, in ms.
  static double _shake(double since) {
    if (since <= 0) return 0;
    final x = since / 1000;
    return math.exp(-x * 9) * math.sin(x * 34);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final ms = animation.value * _totalMs;
        final exit = Curves.easeInCubic.transform(((ms - _exitStartMs) / (_totalMs - _exitStartMs)).clamp(0.0, 1.0));

        // Uniform, small deformations only: the bag keeps its shape.
        var squash = 0.0; // + = pressed down
        var sway = 0.0; // rotation, radians
        for (var i = 0; i < _coinStartMs.length; i++) {
          final j = _shake(ms - (_coinStartMs[i] + _fallMs));
          squash += _hit[i] * j;
          sway += _hit[i] * j * (i.isEven ? 1 : -1);
        }
        final sy = 1 - 0.045 * squash;
        final sx = 1 + 0.03 * squash;
        final angle = 0.022 * sway;
        // On the way out it comes toward you while the screen opens.
        final zoom = 1 + 0.14 * exit;

        return LayoutBuilder(
          builder: (context, box) {
            final s = (box.biggest.shortestSide * 0.75).clamp(180.0, 400.0);
            final coin = s * 0.17;
            // Where the top edge of the screen is, in the bag box's own
            // coordinates: coins start just above it, so they come from
            // outside the screen instead of appearing.
            final screenTop = -(box.maxHeight - s) / 2 - coin;
            final landY = s * 0.30; // hidden behind the bag's mouth by then
            return Opacity(
              opacity: 1 - exit,
              child: ColoredBox(
                color: background,
                child: Center(
                  child: SizedBox(
                    width: s,
                    height: s,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Coins first: they drop out of sight behind the bag's
                        // mouth, so they read as falling inside.
                        for (var i = 0; i < _coinStartMs.length; i++)
                          () {
                            final f = ((ms - _coinStartMs[i]) / _fallMs).clamp(0.0, 1.0);
                            final fall = Curves.easeInQuad.transform(f);
                            final y = screenTop + (landY - screenTop) * fall;
                            return Positioned(
                              left: s * (0.5 + _coinX[i]) - coin / 2,
                              top: y - coin / 2,
                              child: Visibility(
                                visible: f > 0 && f < 1,
                                child: Transform.rotate(
                                  angle: _coinTilt[i] * (1 - f),
                                  child: SvgPicture.asset(
                                    'assets/illustrations/dindin-moeda.svg',
                                    width: coin,
                                    height: coin,
                                  ),
                                ),
                              ),
                            );
                          }(),
                        Transform.scale(
                          scale: zoom,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..rotateZ(angle)
                              ..scaleByDouble(sx, sy, 1, 1),
                            child: SvgPicture.asset('assets/logo.svg', width: s, height: s),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
