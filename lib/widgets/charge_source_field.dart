import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/category.dart';

/// Sentinel for the "Conta" entry — a charge taken straight from the general
/// account balance instead of a caixinha. Mirrors `_accountOption` on the
/// Gastos form: a dropdown needs a non-null value for "no category", and
/// `null` already means "nothing selected".
const chargeSourceAccount = '__account__';

/// Dropdown picking where a recurring charge's money comes from: the account,
/// or one of the caixinhas.
///
/// Only `spend` caixinhas are offered. A `save` caixinha is a savings goal —
/// draining it every month to pay a subscription works against the one thing
/// it exists to do, and it can't go negative either, so it would just fail at
/// charge time. Shared by the Assinaturas and Parcelamentos forms so the two
/// can't drift apart on that rule.
class ChargeSourceField extends StatelessWidget {
  final List<Category> categories;

  /// [chargeSourceAccount] or a category id.
  final String value;
  final ValueChanged<String>? onChanged;

  const ChargeSourceField({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  /// The `spend` caixinhas, which are the only valid sources.
  static List<Category> eligible(List<Category> categories) =>
      categories.where((c) => c.effectiveKind == CategoryKind.spend).toList();

  /// Maps a dropdown value back to what the service expects: `null` for the
  /// account, or the caixinha id.
  static String? toCategoryId(String value) =>
      value == chargeSourceAccount ? null : value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = eligible(categories);
    // A stored caixinha that has since been deleted (or was never a `spend`
    // one) would not be in `options`, and a DropdownButton whose value has no
    // matching item throws. Fall back to showing the account rather than
    // crashing the screen; the row itself warns about the missing caixinha.
    final safeValue = value == chargeSourceAccount || options.any((c) => c.id == value)
        ? value
        : chargeSourceAccount;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.chargeSourceLabel),
      items: [
        DropdownMenuItem(value: chargeSourceAccount, child: Text(l10n.accountLabel)),
        for (final c in options) DropdownMenuItem(value: c.id, child: Text(c.name)),
      ],
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? chargeSourceAccount),
    );
  }
}
