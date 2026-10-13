import 'package:flutter/material.dart';

/// Brief confirmation after a save went through. Forms clear their fields on
/// success and nothing else moves, so without this a successful save and a
/// silent no-op look the same.
///
/// Uses the nearest [ScaffoldMessenger] (the app shell's), so it still shows
/// when it's called right after a bottom sheet closed.
///
/// With [actionLabel] and [onAction] the snackbar carries a button (e.g.
/// "Desfazer" after a removal) and stays a little longer so it can be tapped.
void showSavedSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final hasAction = actionLabel != null && onAction != null;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: hasAction ? 6 : 3),
        action: hasAction ? SnackBarAction(label: actionLabel, onPressed: onAction) : null,
      ),
    );
}
