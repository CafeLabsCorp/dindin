import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tutorial_progress.dart';
import '../../providers/providers.dart';
import 'tutorial.dart';

/// Starts [page]'s tutorial the first time the page is on screen and ready,
/// then records how it ended. Wrap the page's content in it (only once the
/// data has loaded: never over a spinner or an error state).
///
/// Waits for a calm moment (`docs/onboarding-design.md` §2.3): the saved
/// progress has loaded and says "not seen", the page is the visible tab, no
/// dialog or sheet is on top, and the keyboard is closed; then a short pause
/// so the screen settles. It checks again a few times and gives up quietly.
/// An unavailable target (the widget isn't on screen) is not recorded, so the
/// tutorial tries again the next time the page opens.
class TutorialHost extends ConsumerStatefulWidget {
  final TutorialPage page;

  /// Page name for the screen-reader announcement.
  final String pageName;

  /// Built at start time (not earlier) so it can read the current layout.
  final List<TutorialStep> Function(BuildContext context) steps;

  final Widget child;

  const TutorialHost({
    super.key,
    required this.page,
    required this.pageName,
    required this.steps,
    required this.child,
  });

  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost> {
  static const _settle = Duration(milliseconds: 400);
  static const _retry = Duration(milliseconds: 600);
  static const _maxAttempts = 30;

  Timer? _timer;
  bool _started = false;
  int _attempts = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tryStart);
  }

  bool get _calm {
    if (!TickerMode.valuesOf(context).enabled) return false; // another tab is showing
    if (ModalRoute.of(context)?.isCurrent == false) return false; // a dialog is on top
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return false; // keyboard open
    return true;
  }

  Future<void> _tryStart() async {
    if (!mounted || _started) return;
    if (ref.read(tutorialSeenProvider(widget.page)) != false) return;
    if (!_calm) {
      if (++_attempts < _maxAttempts) _schedule(_retry);
      return;
    }
    _started = true;
    final result = await showTutorial(context, pageName: widget.pageName, steps: widget.steps(context));
    if (!mounted) return;
    switch (result) {
      case TutorialResult.done:
        await markTutorialEnded(ref, widget.page, TutorialState.done);
      case TutorialResult.skipped:
        await markTutorialEnded(ref, widget.page, TutorialState.skipped);
      case TutorialResult.unavailable:
        break; // not recorded: it can try again next time
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the moment the saved progress arrives (or is reset from
    // Ajustes) this runs again. Scheduling twice is harmless: the timer is
    // replaced, and `_started` guards the start itself.
    final seen = ref.watch(tutorialSeenProvider(widget.page));
    if (seen == false && !_started && !(_timer?.isActive ?? false)) {
      _attempts = 0;
      _schedule(_settle);
    }
    if (seen == true && _started) {
      // "Rever" from Ajustes resets the page: allow it to start again.
      _started = false;
    }
    return widget.child;
  }
}
