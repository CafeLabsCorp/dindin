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
  String get googleSignInErrorMessage =>
      'Couldn\'t sign in with Google right now. Please try again in a moment.';

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
  String subscriptionChargedOnLabel(String day) {
    return 'Charged on day $day';
  }

  @override
  String get removeSubscriptionConfirmTitle => 'Remove this subscription?';

  @override
  String get removeSubscriptionTooltip => 'Remove subscription';

  @override
  String get autoChargeSwitchTooltip => 'Automatic billing';

  @override
  String get chargeNowTooltip => 'Charge now';

  @override
  String get chargeNowInsufficientBalance =>
      'Charge not posted — insufficient balance.';

  @override
  String get chargeNowNothingDue => 'Nothing pending to charge.';

  @override
  String get chargeNowSuperseded => 'This charge was already posted.';

  @override
  String get chargeNowMissingCaixinha =>
      'This subscription\'s caixinha no longer exists — edit the subscription.';

  @override
  String pastDueDayTitle(int day) {
    return 'Day $day already passed this month';
  }

  @override
  String get pastDueDayBody =>
      'Charge this month\'s payment now, or start only next month?';

  @override
  String get pastDueDayChargeNow => 'Charge now';

  @override
  String get pastDueDayNextMonth => 'Next month';

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
  String settledInstallmentPurchasesTitle(int count) {
    return 'Paid-off installment purchases ($count)';
  }

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
  String get installmentDetailsToggleShow => 'View installments';

  @override
  String get installmentDetailsToggleHide => 'Hide installments';

  @override
  String get installmentPaidTooltip => 'Paid installment';

  @override
  String get installmentPendingTooltip => 'Pending installment';

  @override
  String installmentDueLabel(String date) {
    return 'due $date';
  }

  @override
  String installmentPaidOnLabel(String date) {
    return 'paid $date';
  }

  @override
  String installmentDueDayLabel(String day) {
    return 'due on day $day each month';
  }

  @override
  String get installmentDueDayEditTooltip => 'Change the due day';

  @override
  String get installmentDueDayDialogTitle => 'Due day';

  @override
  String get installmentDueDayDialogHint =>
      'Applies from the next installment on — what was already charged keeps its date.';

  @override
  String get installmentDueDayReset => 'Back to the original day';

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
      other: '$count pending charges (insufficient balance)',
      one: '1 pending charge (insufficient balance)',
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
  String get recurringGoalHint =>
      'With a target amount, this becomes a monthly target: the bar resets every day 1, but the envelope\'s total balance keeps accumulating separately.';

  @override
  String get recurringChip => 'Recurring';

  @override
  String get oneTimeChip => 'One-time';

  @override
  String get deleteBlockedByTransferTooltip =>
      'Undo this envelope\'s transfers before removing it';

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
  String get legalSectionLabel => 'Legal';

  @override
  String get legalDescription =>
      'How your data is handled and Dindin\'s terms of use.';

  @override
  String get privacyPolicyLinkLabel => 'Privacy Policy';

  @override
  String get termsOfUseLinkLabel => 'Terms of Use';

  @override
  String get linkOpenErrorMessage => 'Couldn\'t open the link.';

  @override
  String get privacySectionLabel => 'Privacy';

  @override
  String get analyticsOptOutLabel => 'Share anonymous usage data';

  @override
  String get analyticsOptOutDescription =>
      'Helps Café Labs understand how Dindin is used (no amount, balance, or expense description is ever sent). You can turn this off at any time.';

  @override
  String get emailNotVerifiedMessage =>
      'Your email hasn\'t been confirmed yet. This doesn\'t limit what you can do in the app, but confirming it helps make sure you can recover your account.';

  @override
  String get resendVerificationEmailButton => 'Resend verification email';

  @override
  String get verificationEmailSentMessage =>
      'Verification email sent. Check your inbox (and spam folder).';

  @override
  String get verificationEmailRateLimitedMessage =>
      'Too many attempts in a short time. Wait a few minutes before requesting another email.';

  @override
  String verificationEmailErrorMessage(String error) {
    return 'Couldn\'t send the email right now: $error';
  }

  @override
  String get dangerZoneSectionLabel => 'Danger zone';

  @override
  String get deleteAccountDescription =>
      'Deleting your account erases all your data immediately — caixinhas, income, expenses, subscriptions, and installment purchases. This cannot be undone.';

  @override
  String get deleteAccountButton => 'Delete account';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmBody =>
      'This erases your account and all your data right now, permanently — there is no grace period or recovery afterward. If you\'d like to keep a copy first, export a backup.';

  @override
  String get deleteAccountConfirmDeleteAction => 'Delete permanently';

  @override
  String get deleteAccountReauthRequiredMessage =>
      'For security, account deletion requires a recent sign-in. Sign out and back in, then try deleting your account again.';

  @override
  String deleteAccountErrorMessage(String error) {
    return 'Error deleting account: $error';
  }

  @override
  String get footerBrand => 'Dindin — a Café Labs product';

  @override
  String get languageSectionLabel => 'Language';

  @override
  String get themeSectionLabel => 'Theme';

  @override
  String get themeSystemOption => 'System';

  @override
  String get themeLightOption => 'Light';

  @override
  String get themeDarkOption => 'Dark';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialGotIt => 'Got it';

  @override
  String tutorialStepCounter(int current, int total) {
    return '$current of $total';
  }

  @override
  String get tutorialDashboard1Title => 'This is where you switch screens';

  @override
  String get tutorialDashboard1Body =>
      'Tap the page name to open the menu with Income, Expenses and the other screens.';

  @override
  String get tutorialDashboard1BodyWide =>
      'The app\'s screens are in this bar.';

  @override
  String get tutorialDashboard2Title => 'Money lands in your account';

  @override
  String get tutorialDashboard2Body =>
      'Every income you add shows up here. It isn\'t in any envelope yet.';

  @override
  String get tutorialDashboard3Title => 'Then split it up';

  @override
  String get tutorialDashboard3Body =>
      'Allocate moves part of your account into an envelope. You create envelopes in Categories.';

  @override
  String get tutorialDashboard4Title => 'Your envelopes';

  @override
  String get tutorialDashboard4Body =>
      'Each one shows how much it holds. Transfer moves money from one to another.';

  @override
  String get tutorialReceitas1Title => 'Add what came in';

  @override
  String get tutorialReceitas1Body =>
      'Fill in the amount and where it came from. The date starts as today.';

  @override
  String get tutorialReceitas2Title => 'Then add it';

  @override
  String get tutorialReceitas2Body =>
      'The amount goes to your account. To split it into envelopes, use Allocate on the Dashboard.';

  @override
  String get tutorialReceitas3Title => 'Everything that came in';

  @override
  String get tutorialReceitas3Body =>
      'Tap an income to fix it. The dates above filter the list.';

  @override
  String get tutorialGastos1Title => 'Add an expense';

  @override
  String get tutorialGastos1Body =>
      'Amount and date. The description is optional, but it helps later.';

  @override
  String get tutorialGastos2Title => 'Choose where it comes from';

  @override
  String get tutorialGastos2Body =>
      'Your account or an envelope. The available balance shows right below.';

  @override
  String get tutorialGastos3Title => 'Your expenses';

  @override
  String get tutorialGastos3Body =>
      'Tap one to edit it. The dates above filter the list.';

  @override
  String get tutorialAssinaturas1Title => 'Set it up once';

  @override
  String get tutorialAssinaturas1Body =>
      'Name, amount and billing day. Streaming, gym, rent.';

  @override
  String get tutorialAssinaturas2Title => 'Charged on the right day';

  @override
  String get tutorialAssinaturas2Body =>
      'On the billing day, the expense comes out of the account or envelope you picked, the next time you open the app.';

  @override
  String get tutorialAssinaturas3Title => 'Your subscriptions';

  @override
  String get tutorialAssinaturas3Body =>
      'Tap one to edit it. Charge now posts it before the day.';

  @override
  String get tutorialParcelamentos1Title => 'One purchase, many installments';

  @override
  String get tutorialParcelamentos1Body =>
      'Enter the total and how many installments. Dindin splits it across the months.';

  @override
  String get tutorialParcelamentos2Title => 'Each installment comes from here';

  @override
  String get tutorialParcelamentos2Body =>
      'Your account or an envelope, in each billing month.';

  @override
  String get tutorialParcelamentos3Title => 'Pay early or pay off';

  @override
  String get tutorialParcelamentos3Body =>
      'On each purchase you can pay more than the installment or pay off the rest.';

  @override
  String get tutorialCategorias1Title => 'Each category becomes an envelope';

  @override
  String get tutorialCategorias1Body =>
      'Give it a name, like Groceries or Travel, and tap Add.';

  @override
  String get tutorialCategorias2Title => 'Save or spend';

  @override
  String get tutorialCategorias2Body =>
      'Save is for reaching a goal. Spend is for a monthly limit.';

  @override
  String get tutorialCategorias3Title => 'Your envelopes';

  @override
  String get tutorialCategorias3Body =>
      'Tap one to change its name, goal or limit.';

  @override
  String get tutorialsSectionLabel => 'Tutorials';

  @override
  String get tutorialStatusSeen => 'Seen';

  @override
  String get tutorialStatusSkipped => 'Skipped';

  @override
  String get tutorialStatusNotYet => 'Not yet';

  @override
  String get tutorialActionReview => 'Review';

  @override
  String get tutorialActionView => 'View';

  @override
  String get tutorialReviewAll => 'Review all';

  @override
  String get tutorialsResetMessage =>
      'Tutorials will show again when you open each page.';

  @override
  String tutorialsProgress(int seen, int total) {
    return '$seen of $total seen';
  }

  @override
  String tutorialRowSemantics(String name, String status, String action) {
    return '$name, $status, $action button';
  }

  @override
  String get tutorialSettings1Title => 'Keep a copy';

  @override
  String get tutorialSettings1Body =>
      'Export a backup of your data whenever you want.';

  @override
  String get tutorialSettings2Title => 'See tips again';

  @override
  String get tutorialSettings2Body =>
      'Want to see a tutorial again? It\'s here.';

  @override
  String get emptyReceitasTitle => 'No income yet';

  @override
  String get emptyReceitasBody =>
      'Add your salary or any money that came in. It goes to your account.';

  @override
  String get emptyReceitasAction => 'Add income';

  @override
  String get emptyGastosTitle => 'No expenses yet';

  @override
  String get emptyGastosBody =>
      'Add today\'s groceries, a bill or a coffee. You choose where it comes from.';

  @override
  String get emptyGastosAction => 'Add expense';

  @override
  String get emptyAssinaturasTitle => 'No subscriptions yet';

  @override
  String get emptyAssinaturasBody =>
      'Streaming, gym, rent. Set it up once with the billing day.';

  @override
  String get emptyAssinaturasAction => 'Set up subscription';

  @override
  String get emptyParcelamentosTitle => 'No installment purchases yet';

  @override
  String get emptyParcelamentosBody =>
      'Add the purchase once, with the total and the number of installments.';

  @override
  String get emptyParcelamentosAction => 'Set up installment purchase';

  @override
  String get emptyCategoriasTitle => 'No envelopes yet';

  @override
  String get emptyCategoriasBody =>
      'Groceries, Travel, Savings. Create the first one above.';

  @override
  String get emptyCategoriasAction => 'Create envelope';

  @override
  String get firstStepsTitle => 'First steps';

  @override
  String get firstStepsIntro => 'Three things and Dindin starts to make sense.';

  @override
  String get firstStepCreate => 'Create an envelope';

  @override
  String get firstStepCreateAction => 'Create';

  @override
  String get firstStepIncome => 'Add an income';

  @override
  String get firstStepIncomeAction => 'Add';

  @override
  String get firstStepAllocate => 'Allocate to an envelope';

  @override
  String get firstStepAllocateAction => 'Allocate';

  @override
  String get firstStepDone => 'Done';

  @override
  String get incomesEmptyState => 'No income logged yet.';

  @override
  String get expensesEmptyState => 'No expenses logged yet.';

  @override
  String get navDashboardDescription => 'Balance, account and envelopes';

  @override
  String get navReceitasDescription => 'What came in';

  @override
  String get navGastosDescription => 'What went out';

  @override
  String get navAssinaturasDescription => 'Recurring expenses';

  @override
  String get navParcelamentosDescription => 'Purchases in installments';

  @override
  String get navCategoriasDescription => 'Your envelopes';

  @override
  String get navAjustesDescription => 'Account, theme and backup';

  @override
  String get dashboardQuickIncome => 'Add income';

  @override
  String get dashboardQuickExpense => 'Add expense';

  @override
  String get historyEmptyAction => 'Go to Income';

  @override
  String tutorialAnnouncement(
    String page,
    int current,
    int total,
    String title,
    String body,
  ) {
    return '$page tutorial, step $current of $total. $title. $body';
  }

  @override
  String get languageSystemOption => 'System';

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
  String goalReachedMonthly(String saved, String goal) {
    return 'This month\'s goal reached: $saved of $goal saved';
  }

  @override
  String caixinhaMonthlyGoalTotalCaption(String amount) {
    return 'Total balance: $amount';
  }

  @override
  String goalProgressMonthly(String saved, String goal, String pct) {
    return '$saved of $goal saved this month ($pct%)';
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
  String get errorCategoryHasTransfer =>
      'This envelope took part in a transfer. Undo the transfer first, then remove it.';

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

  @override
  String get signingInWithGoogle => 'Signing in…';

  @override
  String get savedExpense => 'Expense saved.';

  @override
  String get savedIncome => 'Income saved.';

  @override
  String get savedEdit => 'Changes saved.';

  @override
  String get savedSubscription => 'Subscription created.';

  @override
  String get savedInstallment => 'Installment purchase created.';

  @override
  String get savedCategory => 'Envelope saved.';

  @override
  String get savedAllocation => 'Amount allocated.';

  @override
  String get savedTransfer => 'Transfer done.';

  @override
  String errorGenericSaveCode(String code) {
    return 'Couldn\'t save (error: $code). Please try again.';
  }

  @override
  String get passwordConfirmLabel => 'Confirm password';

  @override
  String get passwordMismatchError => 'Passwords don\'t match';

  @override
  String get showPasswordTooltip => 'Show password';

  @override
  String get hidePasswordTooltip => 'Hide password';

  @override
  String get authInvalidCredentialError => 'Incorrect e-mail or password.';

  @override
  String get authEmailInUseError =>
      'An account with this e-mail already exists. Try signing in.';

  @override
  String get authInvalidEmailError => 'That e-mail doesn\'t look valid.';

  @override
  String get authWeakPasswordError =>
      'Password too weak. Use at least 6 characters.';

  @override
  String get authTooManyRequestsError =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authNetworkError =>
      'No internet connection. Check it and try again.';

  @override
  String get authUserDisabledError => 'This account has been disabled.';

  @override
  String get authGenericError => 'Couldn\'t complete that. Please try again.';

  @override
  String get emailVerifyPromptTitle => 'Confirm your email';

  @override
  String get emailVerifyPromptLater => 'Not now';

  @override
  String get updateAvailableMessage => 'A new version of Dindin is available.';

  @override
  String get updateAction => 'Update';

  @override
  String get removedExpense => 'Expense removed.';

  @override
  String get removedIncome => 'Income removed.';

  @override
  String get removedSubscription => 'Subscription removed.';

  @override
  String get removedInstallment => 'Installment purchase removed.';

  @override
  String get removedCategory => 'Envelope removed.';

  @override
  String get autoChargeOnMessage => 'Automatic billing turned on.';

  @override
  String get autoChargeOffMessage => 'Automatic billing turned off.';

  @override
  String get dueDayChangedMessage => 'Due day changed.';

  @override
  String get chargedNowMessage => 'Charge posted.';

  @override
  String get paymentRecordedMessage => 'Payment recorded.';

  @override
  String get errorNetwork => 'No internet connection. Check it and try again.';

  @override
  String get loadErrorMessage => 'Couldn\'t load your data.';

  @override
  String get loadingSlowMessage =>
      'This is taking longer than usual. Check your connection.';

  @override
  String get retryButton => 'Try again';

  @override
  String get undoAction => 'Undo';

  @override
  String get restoredMessage => 'Restored.';
}
