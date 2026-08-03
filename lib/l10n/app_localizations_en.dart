// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get confirm => 'Confirm';

  @override
  String get dateLabel => 'Date';

  @override
  String get amountLabel => 'Amount';

  @override
  String get amountHint => '0.00';

  @override
  String get descriptionOptionalLabel => 'Description (optional)';

  @override
  String get filterFromLabel => 'From';

  @override
  String get filterToLabel => 'To';

  @override
  String get clearFilterButton => 'Clear filter';

  @override
  String get accountLabel => 'Account';

  @override
  String get caixinhaLabel => 'Envelope';

  @override
  String get removedCategoryLabel => 'removed category';

  @override
  String get invalidAmountError => 'Enter a valid amount.';

  @override
  String genericErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalidError => 'Invalid email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordMinLengthError => 'At least 6 characters';

  @override
  String get haveAccountToggle => 'I already have an account';

  @override
  String get createAccountToggle => 'Create an account';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardSubtitle =>
      'Overview of the account and the current month.';

  @override
  String get totalBalanceLabel => 'Total balance';

  @override
  String get accountBalanceDescription =>
      'Money received and not yet allocated to any envelope.';

  @override
  String get allocateButton => 'Allocate';

  @override
  String get receivedThisMonthLabel => 'Received this month';

  @override
  String get spentThisMonthLabel => 'Spent this month';

  @override
  String get monthBalanceLabel => 'Month balance';

  @override
  String get caixinhasTitle => 'Envelopes';

  @override
  String get transferButton => 'Transfer';

  @override
  String get caixinhasEmptyState =>
      'Create categories and allocate income to see your envelopes here.';

  @override
  String sinceDatePrefix(String date) {
    return 'since $date';
  }

  @override
  String get historyTitle => 'Monthly history — received vs. spent';

  @override
  String get historyEmptyState =>
      'Log income and expenses to see the monthly history.';

  @override
  String get allocateDialogTitle => 'Allocate to an envelope';

  @override
  String availableInAccountLabel(String amount) {
    return 'Available in the account: $amount';
  }

  @override
  String get transferDialogTitle => 'Transfer between envelopes';

  @override
  String availableAtOriginLabel(String amount) {
    return 'Available at the origin: $amount';
  }

  @override
  String get transferOriginLabel => 'From';

  @override
  String get transferDestinationLabel => 'To';

  @override
  String get originDestinationMustDifferError =>
      'Origin and destination must be different.';

  @override
  String get receivedLegend => 'Received';

  @override
  String get spentLegend => 'Spent';

  @override
  String get gastosTitle => 'Expenses';

  @override
  String get gastosSubtitle =>
      'Log a payment straight from the account or from a specific envelope.';

  @override
  String get frozenDebtBlockShort =>
      'This envelope is in debt and doesn\'t allow a negative balance. Allocate to it before logging new expenses.';

  @override
  String get frozenDebtBlockLong =>
      'This envelope is in debt and doesn\'t allow a negative balance. Allocate to it before logging new expenses, or turn on \"Allow negative balance\" on the category.';

  @override
  String get expenseSourceLabel => 'Paid from';

  @override
  String get expenseDescriptionHint => 'e.g. groceries';

  @override
  String availableLabel(String amount) {
    return 'Available: $amount';
  }

  @override
  String get submitExpenseButton => 'Log expense';

  @override
  String get expensesListTitle => 'Logged expenses';

  @override
  String get expensesEmptyState => 'No expenses logged yet.';

  @override
  String expensesEmptyFilteredRange(String from, String to) {
    return 'No expenses between $from and $to.';
  }

  @override
  String expensesEmptyFilteredFrom(String from) {
    return 'No expenses since $from.';
  }

  @override
  String expensesEmptyFilteredTo(String to) {
    return 'No expenses until $to.';
  }

  @override
  String get removeExpenseConfirmTitle => 'Remove this expense?';

  @override
  String get removeExpenseTooltip => 'Remove expense';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String get subscriptionsSubtitle =>
      'Fixed expenses that repeat every month — register once and the amount is charged automatically from the account on the right day.';

  @override
  String get subscriptionNameLabel => 'Name';

  @override
  String get subscriptionNameHint => 'e.g. Netflix';

  @override
  String get subscriptionDueDayLabel => 'Billing day';

  @override
  String get invalidDueDayError => 'Enter a day between 1 and 31.';

  @override
  String get submitSubscriptionButton => 'Add subscription';

  @override
  String get subscriptionsListTitle => 'Registered subscriptions';

  @override
  String get subscriptionsEmptyState => 'No subscriptions registered yet.';

  @override
  String subscriptionChargedOnLabel(String day) {
    return 'Charged on day $day';
  }

  @override
  String get removeSubscriptionConfirmTitle => 'Remove this subscription?';

  @override
  String get removeSubscriptionTooltip => 'Remove subscription';

  @override
  String get installmentPurchasesTitle => 'Installment purchases';

  @override
  String get installmentPurchasesSubtitle =>
      'A card purchase split into installments, billed automatically over the following months starting from the first charge.';

  @override
  String get installmentNameLabel => 'Name';

  @override
  String get installmentNameHint => 'e.g. Dell laptop';

  @override
  String get purchaseDateLabel => 'Purchase date';

  @override
  String get installmentsCountLabel => 'Installments';

  @override
  String get firstChargeDateLabel => 'First charge';

  @override
  String get invalidInstallmentsError => 'Enter between 2 and 36 installments.';

  @override
  String get submitInstallmentPurchaseButton => 'Add installment purchase';

  @override
  String get installmentPurchasesListTitle =>
      'Registered installment purchases';

  @override
  String get installmentPurchasesEmptyState =>
      'No installment purchases registered yet.';

  @override
  String installmentSummaryLabel(String count, String amount) {
    return '${count}x of $amount';
  }

  @override
  String installmentProgressLabel(String paid, String total) {
    return '$paid of $total installments paid';
  }

  @override
  String get removeInstallmentPurchaseConfirmTitle =>
      'Remove this installment purchase?';

  @override
  String get removeInstallmentPurchaseTooltip => 'Remove installment purchase';

  @override
  String pendingChargesWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count charges weren\'t posted because the account balance didn\'t cover them. They go through on their own once there\'s enough.',
      one:
          '1 charge wasn\'t posted because the account balance didn\'t cover it. It goes through on its own once there\'s enough.',
    );
    return '$_temp0';
  }

  @override
  String pendingChargesRowLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending charges',
      one: '1 pending charge',
    );
    return '$_temp0';
  }

  @override
  String get catchUpFailedWarning =>
      'Couldn\'t process automatic charges right now. The app tries again next time you open it.';

  @override
  String recurringChargesPosted(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count charges just posted · $amount',
      one: '1 charge just posted · $amount',
    );
    return '$_temp0';
  }

  @override
  String get generatedExpenseTooltip =>
      'Posted automatically by a subscription or installment purchase';

  @override
  String get chargeSourceLabel => 'Comes out of';

  @override
  String get chargeSourceMissingWarning =>
      'This charge\'s envelope was removed — pick another source so it can post again.';

  @override
  String get editSubscriptionTooltip => 'Edit subscription';

  @override
  String get editSubscriptionTitle => 'Edit subscription';

  @override
  String get editSubscriptionHint =>
      'Changing the amount or the day applies from the next unbilled month — months already posted don\'t change.';

  @override
  String get recurringEntryTitle => 'Subscriptions and installments';

  @override
  String recurringEntryCommitted(String amount) {
    return '$amount committed this month';
  }

  @override
  String installmentOutstandingLabel(String amount) {
    return '$amount left';
  }

  @override
  String get installmentSettledLabel => 'Paid off';

  @override
  String installmentPaidAheadLabel(String amount) {
    return '$amount paid ahead';
  }

  @override
  String get payInstallmentTooltip => 'Pay ahead or pay off';

  @override
  String payInstallmentTitle(String name) {
    return 'Pay $name';
  }

  @override
  String payInstallmentHint(String amount) {
    return 'Paying more than the installment reduces what\'s left and shortens the schedule — the installment itself stays the same size. Outstanding: $amount.';
  }

  @override
  String get payInstallmentButton => 'Pay this amount';

  @override
  String settleInstallmentButton(String amount) {
    return 'Pay it all off ($amount)';
  }

  @override
  String installmentPayAheadDescription(String name) {
    return '$name (extra payment)';
  }

  @override
  String installmentSettleDescription(String name) {
    return '$name (paid off)';
  }

  @override
  String get receitasTitle => 'Income';

  @override
  String get receitasSubtitle =>
      'Log how much came in and where from. The amount goes straight into your account —\nallocate it to envelopes whenever you want, from the Dashboard.';

  @override
  String get incomeSourceFieldLabel => 'Source';

  @override
  String get incomeDescriptionHint => 'e.g. July salary';

  @override
  String get submitIncomeButton => 'Log income';

  @override
  String get incomesListTitle => 'Logged income';

  @override
  String get incomesEmptyState => 'No income logged yet.';

  @override
  String incomesEmptyFilteredRange(String from, String to) {
    return 'No income between $from and $to.';
  }

  @override
  String incomesEmptyFilteredFrom(String from) {
    return 'No income since $from.';
  }

  @override
  String incomesEmptyFilteredTo(String to) {
    return 'No income until $to.';
  }

  @override
  String get removeIncomeConfirmTitle => 'Remove this income entry?';

  @override
  String get removeIncomeTooltip => 'Remove income';

  @override
  String get categoriasTitle => 'Categories';

  @override
  String get categoriasSubtitle =>
      'Each category becomes an envelope where you keep money every month.';

  @override
  String get invalidBudgetOrBlankError =>
      'Enter a valid limit, or leave it blank.';

  @override
  String get invalidGoalOrBlankError =>
      'Enter a valid goal, or leave it blank.';

  @override
  String get removeCategoryTitle => 'Remove category?';

  @override
  String get removeCategoryBody =>
      'This also deletes allocations and expenses linked to it.';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get categoryNameHint => 'e.g. Rent, Groceries...';

  @override
  String get kindSaveOption => 'Save';

  @override
  String get kindSpendOption => 'Spend';

  @override
  String get kindSaveDescription =>
      'Savings box: money you\'re setting aside (trip, emergency fund, project).';

  @override
  String get kindSpendDescription =>
      'Envelope: money you set aside to spend during the month.';

  @override
  String get monthlyBudgetLabel => 'Monthly spending limit (optional)';

  @override
  String get goalAmountLabel => 'Target amount (optional)';

  @override
  String get goalAmountHint => 'e.g. 5000.00';

  @override
  String get allowNegativeLabel => 'Allow negative balance';

  @override
  String get allowNegativeDescription =>
      'An expense can leave this envelope in debt. The next allocation automatically settles it.';

  @override
  String get recurringLabel => 'Recurring (repeats every month)';

  @override
  String get categoriesEmptyState =>
      'No categories yet. Create the first one above.';

  @override
  String get recurringChip => 'Recurring';

  @override
  String get oneTimeChip => 'One-time';

  @override
  String get deleteBlockedByDebtTooltip =>
      'Settle this envelope\'s debt (balance back to zero) before removing it';

  @override
  String get removeCategoryTooltip => 'Remove category';

  @override
  String get editCategoryTitle => 'Edit category';

  @override
  String get nameRequiredError => 'Enter a name.';

  @override
  String get debtBlocksSaveConversion =>
      'Settle this envelope\'s debt (balance back to zero) before converting it into a savings box.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Account, backup and data restore.';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get backupSectionLabel => 'Backup';

  @override
  String get backupDescription =>
      'Export your data to a .json file, or import a backup (replaces the current data).';

  @override
  String get exportBackupButton => 'Export backup';

  @override
  String get importBackupButton => 'Import backup';

  @override
  String get importConfirmTitle => 'Import backup?';

  @override
  String get importConfirmBody =>
      'This replaces all current data with the data from the chosen file.';

  @override
  String get importAction => 'Import';

  @override
  String get exportSuccessMessage => 'Backup exported.';

  @override
  String get importSuccessMessage => 'Backup imported.';

  @override
  String exportErrorMessage(String error) {
    return 'Export error: $error';
  }

  @override
  String importErrorMessage(String error) {
    return 'Import error: $error';
  }

  @override
  String get footerBrand => 'Dindin — a Café Labs product';

  @override
  String get languageSectionLabel => 'Language';

  @override
  String get languageSystemOption => 'System';

  @override
  String get themeSectionLabel => 'Theme';

  @override
  String get themeSystemOption => 'System';

  @override
  String get themeLightOption => 'Light';

  @override
  String get themeDarkOption => 'Dark';

  @override
  String get editIncomeTitle => 'Edit income';

  @override
  String get editExpenseTitle => 'Edit expense';

  @override
  String get editAllocationTitle => 'Edit allocation';

  @override
  String get cannotChangeCaixinhaNote =>
      'The envelope can\'t be changed here — remove it and log it again.';

  @override
  String get frozenDebtEditNote =>
      'This envelope is in debt and doesn\'t allow a negative balance — you can only lower the amount, not increase it.';

  @override
  String budgetSpentOfLimit(String spent, String limit) {
    return 'Spent: $spent of $limit this month';
  }

  @override
  String budgetOverLimit(String over) {
    return '+$over over the limit';
  }

  @override
  String goalReached(String saved, String goal) {
    return 'Goal reached: $saved of $goal saved';
  }

  @override
  String goalProgress(String saved, String goal, String pct) {
    return '$saved of $goal saved ($pct%)';
  }

  @override
  String savedThisMonthPositive(String amount) {
    return 'Saved +$amount this month';
  }

  @override
  String savedThisMonthNegative(String amount) {
    return 'Withdrew $amount this month';
  }

  @override
  String debtIndicator(String amount) {
    return 'In debt $amount';
  }

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navReceitas => 'Income';

  @override
  String get navGastos => 'Expenses';

  @override
  String get navAssinaturas => 'Subscriptions';

  @override
  String get navParcelamentos => 'Installments';

  @override
  String get navCategorias => 'Categories';

  @override
  String get navAjustes => 'Settings';

  @override
  String get navMenu => 'Menu';

  @override
  String get errorNotFound => 'This entry no longer exists.';

  @override
  String get errorUnsupportedEdit =>
      'This change isn\'t supported — remove it and log it again.';

  @override
  String get errorSettleDebt =>
      'Settle this envelope\'s debt (balance back to zero) before converting it into a savings box or removing it.';

  @override
  String get errorExceedsBalance =>
      'This amount exceeds the available balance.';

  @override
  String get errorGenericSave => 'Couldn\'t save. Please try again.';

  @override
  String get incomeSourceEstagio => 'Internship';

  @override
  String get incomeSourceFreela => 'Freelance';

  @override
  String get incomeSourceOutro => 'Other';
}
