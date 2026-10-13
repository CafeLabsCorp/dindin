import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/theme.dart';
import '../utils/errors.dart';

/// What a full-screen view shows while its data isn't there yet.
///
/// A spinner by itself is a dead end when the data never comes — e.g. the app
/// opened offline, or a listener failed. So: after [slowAfter] the spinner
/// gains a "taking longer than usual, check your connection" line and a retry
/// button, and an [error] replaces it with a plain message and the same button.
class DataLoadingView extends StatefulWidget {
  /// The failure to explain, or null while it's still just loading.
  final Object? error;

  /// Re-subscribes to whatever feeds the screen.
  final VoidCallback onRetry;

  final Duration slowAfter;

  const DataLoadingView({
    super.key,
    required this.onRetry,
    this.error,
    this.slowAfter = const Duration(seconds: 8),
  });

  @override
  State<DataLoadingView> createState() => _DataLoadingViewState();
}

class _DataLoadingViewState extends State<DataLoadingView> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = widget.error;
    final showMessage = error != null || _slow;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error == null) const CircularProgressIndicator(),
            if (showMessage) ...[
              if (error == null) const SizedBox(height: 20),
              Text(
                error != null ? friendlyLoadErrorMessage(l10n, error) : l10n.loadingSlowMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: widget.onRetry, child: Text(l10n.retryButton)),
            ],
          ],
        ),
      ),
    );
  }
}
