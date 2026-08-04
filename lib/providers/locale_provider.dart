import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// null means "follow the system locale" — a simple, non-persisted,
/// in-memory choice overridable from Ajustes (see settings_page.dart). PT is
/// what `AppLocalizations` falls back to when the resolved locale isn't
/// supported (see l10n.yaml's `preferred-supported-locales`), matching this
/// product's Portuguese-first copy.
final localeProvider = StateProvider<Locale?>((ref) => null);
