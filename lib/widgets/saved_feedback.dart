import 'package:flutter/material.dart';

/// Brief confirmation after a save went through. Forms clear their fields on
/// success and nothing else moves, so without this a successful save and a
/// silent no-op look the same.
///
/// Uses the nearest [ScaffoldMessenger] (the app shell's), so it still shows
/// when it's called right after a bottom sheet closed.
void showSavedSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}
