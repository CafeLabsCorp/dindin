import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/theme_provider.dart';
import '../theme/colors.dart';

/// Plays the opening animation on top of [child] (the whole app, already
/// building underneath), then removes itself: the money bag rises limp, coins
/// drop into it, it fills out and the app shows through.
///
/// Not shown when the system asks for reduced motion. Lives in `main()`, above
/// `DindinApp`, so widget tests of the app never see it.
class SplashGate extends ConsumerStatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  /// Total length of the animation (the last tenth is the fade into the app).
  static const duration = Duration(milliseconds: 2000);

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

  static const _coinStarts = [0.20, 0.30, 0.40];
  static const _coinOffsets = [-0.035, 0.04, 0.0]; // x, in bag-sizes
  static const _fallSpan = 0.24;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        double phase(double from, double to, [Curve curve = Curves.linear]) =>
            curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

        final rise = phase(0.0, 0.30, Curves.easeOutCubic);
        final inflate = phase(0.62, 0.88, Curves.easeOutBack);
        final fadeOut = phase(0.90, 1.0, Curves.easeIn);

        return LayoutBuilder(
          builder: (context, box) {
            final s = (box.biggest.shortestSide * 0.75).clamp(180.0, 400.0);
            final coin = s * 0.17;
            return Opacity(
              opacity: 1 - fadeOut,
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
                        for (var i = 0; i < _coinStarts.length; i++)
                          () {
                            final fall = phase(_coinStarts[i], _coinStarts[i] + _fallSpan, Curves.easeIn);
                            return Positioned(
                              left: s * (0.5 + _coinOffsets[i]) - coin / 2,
                              top: s * (-0.40 + 0.72 * fall) - coin / 2 + s * 0.12 * (1 - rise),
                              child: Opacity(
                                opacity: fall > 0 && fall < 1 ? 1 : 0,
                                child: SvgPicture.asset('assets/illustrations/dindin-moeda.svg', width: coin, height: coin),
                              ),
                            );
                          }(),
                        Opacity(
                          opacity: rise,
                          child: Transform.translate(
                            offset: Offset(0, s * 0.18 * (1 - rise)),
                            child: Transform(
                              alignment: Alignment.bottomCenter,
                              // Limp (shorter and a bit wider) until it fills.
                              transform: Matrix4.diagonal3Values(
                                1.07 - 0.07 * inflate,
                                0.78 + 0.22 * inflate,
                                1,
                              ),
                              child: SvgPicture.asset('assets/logo.svg', width: s, height: s),
                            ),
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
