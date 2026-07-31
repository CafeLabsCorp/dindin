import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/subscription.dart';
import '../../providers/providers.dart';
import '../../services/recurring_schedule.dart' as schedule;
import '../../theme/theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charge_source_field.dart';
import '../../widgets/responsive_form_row.dart';

/// Fixed recurring monthly charges, on their own screen.
///
/// This used to be a card at the bottom of Gastos, below the (unbounded)
/// expense list — which made it effectively unreachable. Setting up a
/// subscription is configuration you do once; the expense list is a daily
/// routine. They don't belong on the same screen.
class AssinaturasPage extends ConsumerStatefulWidget {
  const AssinaturasPage({super.key});

  @override
  ConsumerState<AssinaturasPage> createState() => _AssinaturasPageState();
}

class _AssinaturasPageState extends ConsumerState<AssinaturasPage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  int _dueDay = 5;
  String _source = chargeSourceAccount;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.nameRequiredError);
      return;
    }
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await firestore.createSubscription(
        name: name,
        amount: value,
        dueDay: _dueDay,
        categoryId: ChargeSourceField.toCategoryId(_source),
      );
      _nameController.clear();
      _amountController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(Subscription subscription) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeSubscriptionConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteSubscription(subscription.id);
  }

  Future<void> _edit(Subscription subscription, List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSubscriptionSheet(
        subscription: subscription,
        categories: categories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final catchUpState = ref.watch(recurringChargesCatchUpProvider);
    final showPending = catchUpState.hasValue;
    final today = ref.watch(todayProvider);

    return ListView(
      children: [
        Text(
          l10n.subscriptionsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(l10n.subscriptionsSubtitle, style: TextStyle(color: context.tokens.muted)),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveFormRow(
                fields: [
                  (
                    width: 200.0,
                    child: TextField(
                      controller: _nameController,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        labelText: l10n.subscriptionNameLabel,
                        hintText: l10n.subscriptionNameHint,
                      ),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: DropdownButtonFormField<int>(
                      initialValue: _dueDay,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.subscriptionDueDayLabel),
                      items: [
                        for (var d = 1; d <= 31; d++)
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: _submitting ? null : (v) => setState(() => _dueDay = v ?? _dueDay),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _amountController,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.amountLabel,
                        hintText: l10n.amountHint,
                      ),
                    ),
                  ),
                  (
                    width: 180.0,
                    child: ChargeSourceField(
                      categories: categories,
                      value: _source,
                      onChanged: _submitting ? null : (v) => setState(() => _source = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(l10n.submitSubscriptionButton),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.subscriptionsListTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              subscriptionsAsync.when(
                data: (subscriptions) {
                  if (subscriptions.isEmpty) return EmptyState(l10n.subscriptionsEmptyState);
                  return Column(
                    children: [
                      for (var i = 0; i < subscriptions.length; i++)
                        _SubscriptionRow(
                          subscription: subscriptions[i],
                          categories: categories,
                          pendingCharges: showPending
                              ? schedule.pendingDueDates(subscriptions[i], today).length
                              : 0,
                          onEdit: () => _edit(subscriptions[i], categories),
                          onDelete: () => _delete(subscriptions[i]),
                          divider: i > 0,
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(l10n.genericErrorPrefix(e.toString())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  final Subscription subscription;
  final List<Category> categories;
  final int pendingCharges;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool divider;

  const _SubscriptionRow({
    required this.subscription,
    required this.categories,
    required this.pendingCharges,
    required this.onEdit,
    required this.onDelete,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = Theme.of(context).colorScheme.error;
    // A caixinha that no longer exists is a dead end for catch-up: it can
    // never charge, and no amount of money fixes it. Says so plainly instead
    // of leaving the user staring at a charge that silently never lands.
    final missingCaixinha =
        subscription.chargesCaixinha &&
        !categories.any((c) => c.id == subscription.categoryId);
    final sourceName = subscription.categoryId == null
        ? l10n.accountLabel
        : categories
                  .where((c) => c.id == subscription.categoryId)
                  .map((c) => c.name)
                  .firstOrNull ??
              l10n.removedCategoryLabel;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: context.tokens.border)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatCurrency(subscription.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' · ${subscription.name}',
                        style: TextStyle(color: context.tokens.subtle),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${l10n.subscriptionChargedOnLabel('${subscription.dueDay}')} · $sourceName',
                  style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                ),
                if (missingCaixinha)
                  Text(
                    l10n.chargeSourceMissingWarning,
                    style: TextStyle(fontSize: 12, color: error),
                  )
                else if (pendingCharges > 0)
                  Text(
                    l10n.pendingChargesRowLabel(pendingCharges),
                    style: TextStyle(fontSize: 12, color: error),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editSubscriptionTooltip,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.removeSubscriptionTooltip,
            color: error,
          ),
        ],
      ),
    );
  }
}

/// Editing instead of delete-and-recreate: recreating would lose the billing
/// history (`lastChargedDate`) and orphan the link on every expense already
/// generated — see `FirestoreService.updateSubscription`.
class _EditSubscriptionSheet extends ConsumerStatefulWidget {
  final Subscription subscription;
  final List<Category> categories;

  const _EditSubscriptionSheet({required this.subscription, required this.categories});

  @override
  ConsumerState<_EditSubscriptionSheet> createState() => _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends ConsumerState<_EditSubscriptionSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late int _dueDay;
  late String _source;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subscription.name);
    _amountController = TextEditingController(
      text: widget.subscription.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _dueDay = widget.subscription.dueDay;
    _source = widget.subscription.categoryId ?? chargeSourceAccount;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.nameRequiredError);
      return;
    }
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(firestoreServiceProvider)!
          .updateSubscription(
            widget.subscription.id,
            name: name,
            amount: value,
            dueDay: _dueDay,
            categoryId: ChargeSourceField.toCategoryId(_source),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(l10n, e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editSubscriptionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // A day change only ever applies from the next unbilled month —
          // worth saying, because "cobra todo dia 5" changing to 15 looks
          // like it should move a charge that already happened.
          Text(
            l10n.editSubscriptionHint,
            style: TextStyle(fontSize: 12, color: context.tokens.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: !_submitting,
            decoration: InputDecoration(labelText: l10n.subscriptionNameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amountLabel),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _dueDay,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.subscriptionDueDayLabel),
            items: [
              for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: _submitting ? null : (v) => setState(() => _dueDay = v ?? _dueDay),
          ),
          const SizedBox(height: 12),
          ChargeSourceField(
            categories: widget.categories,
            value: _source,
            onChanged: _submitting ? null : (v) => setState(() => _source = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
