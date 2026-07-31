import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/installment_purchase.dart';
import '../../providers/providers.dart';
import '../../services/recurring_schedule.dart' as schedule;
import '../../theme/theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/charge_source_field.dart';
import '../../widgets/responsive_form_row.dart';

/// Card purchases split into monthly installments, on their own screen —
/// same reasoning as `AssinaturasPage`.
class ParcelamentosPage extends ConsumerStatefulWidget {
  const ParcelamentosPage({super.key});

  @override
  ConsumerState<ParcelamentosPage> createState() => _ParcelamentosPageState();
}

class _ParcelamentosPageState extends ConsumerState<ParcelamentosPage> {
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  DateTime _firstChargeDate = DateTime.now();
  int _installments = 2;
  String _source = chargeSourceAccount;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.nameRequiredError);
      return;
    }
    final value = double.tryParse(_totalController.text.replaceAll(',', '.'));
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
      await firestore.createInstallmentPurchase(
        name: name,
        totalAmount: value,
        installments: _installments,
        purchaseDate: isoDateFrom(_purchaseDate),
        firstChargeDate: isoDateFrom(_firstChargeDate),
        categoryId: ChargeSourceField.toCategoryId(_source),
      );
      _nameController.clear();
      _totalController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(InstallmentPurchase purchase) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeInstallmentPurchaseConfirmTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.remove)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider)!.deleteInstallmentPurchase(purchase.id);
  }

  Future<void> _pay(InstallmentPurchase purchase, List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PayInstallmentSheet(purchase: purchase, categories: categories),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final purchasesAsync = ref.watch(installmentPurchasesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final catchUpState = ref.watch(recurringChargesCatchUpProvider);
    final showPending = catchUpState.hasValue;
    final today = ref.watch(todayProvider);

    return ListView(
      children: [
        Text(
          l10n.installmentPurchasesTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(l10n.installmentPurchasesSubtitle, style: TextStyle(color: context.tokens.muted)),
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
                        labelText: l10n.installmentNameLabel,
                        hintText: l10n.installmentNameHint,
                      ),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: _DateField(
                      label: l10n.purchaseDateLabel,
                      value: _purchaseDate,
                      enabled: !_submitting,
                      onChanged: (d) => setState(() => _purchaseDate = d),
                    ),
                  ),
                  (
                    width: 140.0,
                    child: TextField(
                      controller: _totalController,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.amountLabel,
                        hintText: l10n.amountHint,
                      ),
                    ),
                  ),
                  (
                    width: 120.0,
                    child: DropdownButtonFormField<int>(
                      initialValue: _installments,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.installmentsCountLabel),
                      items: [
                        for (var n = 2; n <= 36; n++)
                          DropdownMenuItem(value: n, child: Text('${n}x')),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _installments = v ?? _installments),
                    ),
                  ),
                  (
                    width: 160.0,
                    child: _DateField(
                      label: l10n.firstChargeDateLabel,
                      value: _firstChargeDate,
                      enabled: !_submitting,
                      onChanged: (d) => setState(() => _firstChargeDate = d),
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
                child: Text(l10n.submitInstallmentPurchaseButton),
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
                l10n.installmentPurchasesListTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              purchasesAsync.when(
                data: (purchases) {
                  if (purchases.isEmpty) {
                    return EmptyState(l10n.installmentPurchasesEmptyState);
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < purchases.length; i++)
                        _InstallmentPurchaseRow(
                          purchase: purchases[i],
                          categories: categories,
                          pendingCharges: showPending
                              ? schedule.pendingInstallmentIndexes(purchases[i], today).length
                              : 0,
                          onPay: () => _pay(purchases[i], categories),
                          onDelete: () => _delete(purchases[i]),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(formatDate(isoDateFrom(value))),
      ),
    );
  }
}

class _InstallmentPurchaseRow extends StatelessWidget {
  final InstallmentPurchase purchase;
  final List<Category> categories;
  final int pendingCharges;
  final VoidCallback onPay;
  final VoidCallback onDelete;
  final bool divider;

  const _InstallmentPurchaseRow({
    required this.purchase,
    required this.categories,
    required this.pendingCharges,
    required this.onPay,
    required this.onDelete,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = Theme.of(context).colorScheme.error;
    final outstanding = schedule.outstandingAmount(purchase);
    final settled = schedule.isSettled(purchase);
    // Display-only approximation (Nx de R$Y): the actual last charge may be a
    // cent higher to absorb rounding, or smaller after an early payment —
    // see recurring_schedule.installmentChargeAmount.
    final perInstallment = purchase.totalAmount / purchase.installments;
    final missingCaixinha =
        purchase.chargesCaixinha && !categories.any((c) => c.id == purchase.categoryId);

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
                        text: formatCurrency(purchase.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · ${purchase.name} · ${l10n.installmentSummaryLabel('${purchase.installments}', formatCurrency(perInstallment))}',
                        style: TextStyle(color: context.tokens.subtle),
                      ),
                    ],
                  ),
                ),
                Text(
                  settled
                      ? l10n.installmentSettledLabel
                      : l10n.installmentOutstandingLabel(formatCurrency(outstanding)),
                  style: TextStyle(fontSize: 12, color: context.tokens.subtle),
                ),
                if (purchase.amortizedAmount > 0)
                  Text(
                    l10n.installmentPaidAheadLabel(formatCurrency(purchase.amortizedAmount)),
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
          if (!settled)
            IconButton(
              onPressed: onPay,
              icon: const Icon(Icons.payments_outlined),
              tooltip: l10n.payInstallmentTooltip,
            ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.removeInstallmentPurchaseTooltip,
            color: error,
          ),
        ],
      ),
    );
  }
}

/// Paying more than the scheduled installment, or settling the whole thing.
///
/// The money leaves now, from wherever the user picks — deliberately
/// independent of where the monthly charges come from, since settling a card
/// purchase is a one-off you might fund from anywhere.
class _PayInstallmentSheet extends ConsumerStatefulWidget {
  final InstallmentPurchase purchase;
  final List<Category> categories;

  const _PayInstallmentSheet({required this.purchase, required this.categories});

  @override
  ConsumerState<_PayInstallmentSheet> createState() => _PayInstallmentSheetState();
}

class _PayInstallmentSheetState extends ConsumerState<_PayInstallmentSheet> {
  final _amountController = TextEditingController();
  late String _source;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _source = widget.purchase.categoryId ?? chargeSourceAccount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay(double amount, {required bool settling}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(firestoreServiceProvider)!
          .payInstallmentPurchase(
            widget.purchase.id,
            amount: amount,
            date: isoDateFrom(ref.read(todayProvider)),
            categoryId: ChargeSourceField.toCategoryId(_source),
            description: settling
                ? l10n.installmentSettleDescription(widget.purchase.name)
                : l10n.installmentPayAheadDescription(widget.purchase.name),
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

  Future<void> _submitTyped() async {
    final l10n = AppLocalizations.of(context)!;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      setState(() => _error = l10n.invalidAmountError);
      return;
    }
    await _pay(value, settling: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outstanding = schedule.outstandingAmount(widget.purchase);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.payInstallmentTitle(widget.purchase.name),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.payInstallmentHint(formatCurrency(outstanding)),
            style: TextStyle(fontSize: 12, color: context.tokens.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amountLabel, hintText: l10n.amountHint),
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
            onPressed: _submitting ? null : _submitTyped,
            child: Text(l10n.payInstallmentButton),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _submitting ? null : () => _pay(outstanding, settling: true),
            child: Text(l10n.settleInstallmentButton(formatCurrency(outstanding))),
          ),
        ],
      ),
    );
  }
}
