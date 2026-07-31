import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt'),
    Locale('en'),
  ];

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get save;

  /// No description provided for @add.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get remove;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @dateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Data'**
  String get dateLabel;

  /// No description provided for @amountLabel.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get amountLabel;

  /// No description provided for @amountHint.
  ///
  /// In pt, this message translates to:
  /// **'0,00'**
  String get amountHint;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição (opcional)'**
  String get descriptionOptionalLabel;

  /// No description provided for @filterFromLabel.
  ///
  /// In pt, this message translates to:
  /// **'De'**
  String get filterFromLabel;

  /// No description provided for @filterToLabel.
  ///
  /// In pt, this message translates to:
  /// **'Até'**
  String get filterToLabel;

  /// No description provided for @clearFilterButton.
  ///
  /// In pt, this message translates to:
  /// **'Limpar filtro'**
  String get clearFilterButton;

  /// No description provided for @accountLabel.
  ///
  /// In pt, this message translates to:
  /// **'Conta'**
  String get accountLabel;

  /// No description provided for @caixinhaLabel.
  ///
  /// In pt, this message translates to:
  /// **'Caixinha'**
  String get caixinhaLabel;

  /// No description provided for @removedCategoryLabel.
  ///
  /// In pt, this message translates to:
  /// **'categoria removida'**
  String get removedCategoryLabel;

  /// No description provided for @invalidAmountError.
  ///
  /// In pt, this message translates to:
  /// **'Informe um valor válido.'**
  String get invalidAmountError;

  /// No description provided for @genericErrorPrefix.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String genericErrorPrefix(String error);

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authCreateAccountTitle;

  /// No description provided for @authSignInTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignInTitle;

  /// No description provided for @emailLabel.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get emailLabel;

  /// No description provided for @emailInvalidError.
  ///
  /// In pt, this message translates to:
  /// **'E-mail inválido'**
  String get emailInvalidError;

  /// No description provided for @passwordLabel.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get passwordLabel;

  /// No description provided for @passwordMinLengthError.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get passwordMinLengthError;

  /// No description provided for @haveAccountToggle.
  ///
  /// In pt, this message translates to:
  /// **'Já tenho conta'**
  String get haveAccountToggle;

  /// No description provided for @createAccountToggle.
  ///
  /// In pt, this message translates to:
  /// **'Criar uma conta'**
  String get createAccountToggle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get signInWithGoogle;

  /// No description provided for @dashboardTitle.
  ///
  /// In pt, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Visão geral da conta e do mês atual.'**
  String get dashboardSubtitle;

  /// No description provided for @totalBalanceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Saldo total'**
  String get totalBalanceLabel;

  /// No description provided for @accountBalanceDescription.
  ///
  /// In pt, this message translates to:
  /// **'Dinheiro recebido e ainda não alocado em nenhuma caixinha.'**
  String get accountBalanceDescription;

  /// No description provided for @allocateButton.
  ///
  /// In pt, this message translates to:
  /// **'Alocar'**
  String get allocateButton;

  /// No description provided for @receivedThisMonthLabel.
  ///
  /// In pt, this message translates to:
  /// **'Recebido este mês'**
  String get receivedThisMonthLabel;

  /// No description provided for @spentThisMonthLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gasto este mês'**
  String get spentThisMonthLabel;

  /// No description provided for @monthBalanceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Saldo do mês'**
  String get monthBalanceLabel;

  /// No description provided for @caixinhasTitle.
  ///
  /// In pt, this message translates to:
  /// **'Caixinhas'**
  String get caixinhasTitle;

  /// No description provided for @transferButton.
  ///
  /// In pt, this message translates to:
  /// **'Transferir'**
  String get transferButton;

  /// No description provided for @caixinhasEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Crie categorias e aloque receitas para ver suas caixinhas aqui.'**
  String get caixinhasEmptyState;

  /// No description provided for @sinceDatePrefix.
  ///
  /// In pt, this message translates to:
  /// **'desde {date}'**
  String sinceDatePrefix(String date);

  /// No description provided for @historyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Histórico mensal — recebido x gasto'**
  String get historyTitle;

  /// No description provided for @historyEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Lance receitas e gastos para ver o histórico por mês.'**
  String get historyEmptyState;

  /// No description provided for @allocateDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alocar pra caixinha'**
  String get allocateDialogTitle;

  /// No description provided for @availableInAccountLabel.
  ///
  /// In pt, this message translates to:
  /// **'Disponível na conta: {amount}'**
  String availableInAccountLabel(String amount);

  /// No description provided for @transferDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Transferir entre caixinhas'**
  String get transferDialogTitle;

  /// No description provided for @availableAtOriginLabel.
  ///
  /// In pt, this message translates to:
  /// **'Disponível na origem: {amount}'**
  String availableAtOriginLabel(String amount);

  /// No description provided for @transferOriginLabel.
  ///
  /// In pt, this message translates to:
  /// **'Origem'**
  String get transferOriginLabel;

  /// No description provided for @transferDestinationLabel.
  ///
  /// In pt, this message translates to:
  /// **'Destino'**
  String get transferDestinationLabel;

  /// No description provided for @originDestinationMustDifferError.
  ///
  /// In pt, this message translates to:
  /// **'Origem e destino precisam ser diferentes.'**
  String get originDestinationMustDifferError;

  /// No description provided for @receivedLegend.
  ///
  /// In pt, this message translates to:
  /// **'Recebido'**
  String get receivedLegend;

  /// No description provided for @spentLegend.
  ///
  /// In pt, this message translates to:
  /// **'Gasto'**
  String get spentLegend;

  /// No description provided for @gastosTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gastos'**
  String get gastosTitle;

  /// No description provided for @gastosSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Registre uma saída direto da conta ou de uma caixinha específica.'**
  String get gastosSubtitle;

  /// No description provided for @frozenDebtBlockShort.
  ///
  /// In pt, this message translates to:
  /// **'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos.'**
  String get frozenDebtBlockShort;

  /// No description provided for @frozenDebtBlockLong.
  ///
  /// In pt, this message translates to:
  /// **'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos, ou ligue \"Permitir saldo negativo\" na categoria.'**
  String get frozenDebtBlockLong;

  /// No description provided for @expenseSourceLabel.
  ///
  /// In pt, this message translates to:
  /// **'De onde sai'**
  String get expenseSourceLabel;

  /// No description provided for @expenseDescriptionHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: supermercado'**
  String get expenseDescriptionHint;

  /// No description provided for @availableLabel.
  ///
  /// In pt, this message translates to:
  /// **'Disponível: {amount}'**
  String availableLabel(String amount);

  /// No description provided for @submitExpenseButton.
  ///
  /// In pt, this message translates to:
  /// **'Lançar gasto'**
  String get submitExpenseButton;

  /// No description provided for @expensesListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gastos lançados'**
  String get expensesListTitle;

  /// No description provided for @expensesEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gasto lançado ainda.'**
  String get expensesEmptyState;

  /// No description provided for @expensesEmptyFilteredRange.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gasto entre {from} e {to}.'**
  String expensesEmptyFilteredRange(String from, String to);

  /// No description provided for @expensesEmptyFilteredFrom.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gasto a partir de {from}.'**
  String expensesEmptyFilteredFrom(String from);

  /// No description provided for @expensesEmptyFilteredTo.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gasto até {to}.'**
  String expensesEmptyFilteredTo(String to);

  /// No description provided for @removeExpenseConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover esse gasto?'**
  String get removeExpenseConfirmTitle;

  /// No description provided for @removeExpenseTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover gasto'**
  String get removeExpenseTooltip;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Gastos fixos que se repetem todo mês — cadastre uma vez e o valor é lançado automaticamente da conta no dia certo.'**
  String get subscriptionsSubtitle;

  /// No description provided for @subscriptionNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get subscriptionNameLabel;

  /// No description provided for @subscriptionNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Netflix'**
  String get subscriptionNameHint;

  /// No description provided for @subscriptionDueDayLabel.
  ///
  /// In pt, this message translates to:
  /// **'Dia da cobrança'**
  String get subscriptionDueDayLabel;

  /// No description provided for @invalidDueDayError.
  ///
  /// In pt, this message translates to:
  /// **'Informe um dia entre 1 e 31.'**
  String get invalidDueDayError;

  /// No description provided for @submitSubscriptionButton.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar assinatura'**
  String get submitSubscriptionButton;

  /// No description provided for @subscriptionsListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas cadastradas'**
  String get subscriptionsListTitle;

  /// No description provided for @subscriptionsEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma assinatura cadastrada ainda.'**
  String get subscriptionsEmptyState;

  /// No description provided for @subscriptionChargedOnLabel.
  ///
  /// In pt, this message translates to:
  /// **'Cobra todo dia {day}'**
  String subscriptionChargedOnLabel(String day);

  /// No description provided for @removeSubscriptionConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover essa assinatura?'**
  String get removeSubscriptionConfirmTitle;

  /// No description provided for @removeSubscriptionTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover assinatura'**
  String get removeSubscriptionTooltip;

  /// No description provided for @installmentPurchasesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Compras parceladas'**
  String get installmentPurchasesTitle;

  /// No description provided for @installmentPurchasesSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Uma compra parcelada no cartão, dividida automaticamente pelos meses seguintes a partir da primeira cobrança.'**
  String get installmentPurchasesSubtitle;

  /// No description provided for @installmentNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get installmentNameLabel;

  /// No description provided for @installmentNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Notebook Dell'**
  String get installmentNameHint;

  /// No description provided for @purchaseDateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Data da compra'**
  String get purchaseDateLabel;

  /// No description provided for @installmentsCountLabel.
  ///
  /// In pt, this message translates to:
  /// **'Parcelas'**
  String get installmentsCountLabel;

  /// No description provided for @firstChargeDateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Primeira cobrança'**
  String get firstChargeDateLabel;

  /// No description provided for @invalidInstallmentsError.
  ///
  /// In pt, this message translates to:
  /// **'Informe entre 2 e 36 parcelas.'**
  String get invalidInstallmentsError;

  /// No description provided for @submitInstallmentPurchaseButton.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar parcelamento'**
  String get submitInstallmentPurchaseButton;

  /// No description provided for @installmentPurchasesListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Parcelamentos cadastrados'**
  String get installmentPurchasesListTitle;

  /// No description provided for @installmentPurchasesEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum parcelamento cadastrado ainda.'**
  String get installmentPurchasesEmptyState;

  /// No description provided for @installmentSummaryLabel.
  ///
  /// In pt, this message translates to:
  /// **'{count}x de {amount}'**
  String installmentSummaryLabel(String count, String amount);

  /// No description provided for @installmentProgressLabel.
  ///
  /// In pt, this message translates to:
  /// **'{paid} de {total} parcelas pagas'**
  String installmentProgressLabel(String paid, String total);

  /// No description provided for @removeInstallmentPurchaseConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover esse parcelamento?'**
  String get removeInstallmentPurchaseConfirmTitle;

  /// No description provided for @removeInstallmentPurchaseTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover parcelamento'**
  String get removeInstallmentPurchaseTooltip;

  /// No description provided for @pendingChargesWarning.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 cobrança não foi lançada porque o saldo da conta não cobriu. Ela entra sozinha assim que houver saldo.} other{{count} cobranças não foram lançadas porque o saldo da conta não cobriu. Elas entram sozinhas assim que houver saldo.}}'**
  String pendingChargesWarning(int count);

  /// No description provided for @pendingChargesRowLabel.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 cobrança pendente} other{{count} cobranças pendentes}}'**
  String pendingChargesRowLabel(int count);

  /// No description provided for @catchUpFailedWarning.
  ///
  /// In pt, this message translates to:
  /// **'Não deu pra processar as cobranças automáticas agora. O app tenta de novo na próxima vez que você abrir.'**
  String get catchUpFailedWarning;

  /// No description provided for @recurringChargesPosted.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 cobrança lançada agora · {amount}} other{{count} cobranças lançadas agora · {amount}}}'**
  String recurringChargesPosted(int count, String amount);

  /// No description provided for @generatedExpenseTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Lançado automaticamente por uma assinatura ou parcelamento'**
  String get generatedExpenseTooltip;

  /// No description provided for @chargeSourceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Sai de'**
  String get chargeSourceLabel;

  /// No description provided for @chargeSourceMissingWarning.
  ///
  /// In pt, this message translates to:
  /// **'A caixinha dessa cobrança foi removida — escolha outra origem pra ela voltar a ser lançada.'**
  String get chargeSourceMissingWarning;

  /// No description provided for @editSubscriptionTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Editar assinatura'**
  String get editSubscriptionTooltip;

  /// No description provided for @editSubscriptionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar assinatura'**
  String get editSubscriptionTitle;

  /// No description provided for @editSubscriptionHint.
  ///
  /// In pt, this message translates to:
  /// **'Mudar o valor ou o dia vale a partir do próximo mês ainda não cobrado — meses já lançados não mudam.'**
  String get editSubscriptionHint;

  /// No description provided for @recurringEntryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas e parcelamentos'**
  String get recurringEntryTitle;

  /// No description provided for @recurringEntryCommitted.
  ///
  /// In pt, this message translates to:
  /// **'{amount} comprometidos neste mês'**
  String recurringEntryCommitted(String amount);

  /// No description provided for @installmentOutstandingLabel.
  ///
  /// In pt, this message translates to:
  /// **'Faltam {amount}'**
  String installmentOutstandingLabel(String amount);

  /// No description provided for @installmentSettledLabel.
  ///
  /// In pt, this message translates to:
  /// **'Quitado'**
  String get installmentSettledLabel;

  /// No description provided for @installmentPaidAheadLabel.
  ///
  /// In pt, this message translates to:
  /// **'{amount} pagos adiantado'**
  String installmentPaidAheadLabel(String amount);

  /// No description provided for @payInstallmentTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Pagar adiantado ou quitar'**
  String get payInstallmentTooltip;

  /// No description provided for @payInstallmentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Pagar {name}'**
  String payInstallmentTitle(String name);

  /// No description provided for @payInstallmentHint.
  ///
  /// In pt, this message translates to:
  /// **'Pagar mais que a parcela reduz o que falta e encurta o prazo — a parcela continua do mesmo tamanho. Saldo devedor: {amount}.'**
  String payInstallmentHint(String amount);

  /// No description provided for @payInstallmentButton.
  ///
  /// In pt, this message translates to:
  /// **'Pagar esse valor'**
  String get payInstallmentButton;

  /// No description provided for @settleInstallmentButton.
  ///
  /// In pt, this message translates to:
  /// **'Quitar tudo ({amount})'**
  String settleInstallmentButton(String amount);

  /// No description provided for @installmentPayAheadDescription.
  ///
  /// In pt, this message translates to:
  /// **'{name} (adiantamento)'**
  String installmentPayAheadDescription(String name);

  /// No description provided for @installmentSettleDescription.
  ///
  /// In pt, this message translates to:
  /// **'{name} (quitação)'**
  String installmentSettleDescription(String name);

  /// No description provided for @receitasTitle.
  ///
  /// In pt, this message translates to:
  /// **'Receitas'**
  String get receitasTitle;

  /// No description provided for @receitasSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Lance o quanto entrou e de onde veio. O valor cai direto na sua conta —\naloque em caixinhas quando quiser, no Dashboard.'**
  String get receitasSubtitle;

  /// No description provided for @incomeSourceFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Origem'**
  String get incomeSourceFieldLabel;

  /// No description provided for @incomeDescriptionHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: salário julho'**
  String get incomeDescriptionHint;

  /// No description provided for @submitIncomeButton.
  ///
  /// In pt, this message translates to:
  /// **'Lançar receita'**
  String get submitIncomeButton;

  /// No description provided for @incomesListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Receitas lançadas'**
  String get incomesListTitle;

  /// No description provided for @incomesEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma receita lançada ainda.'**
  String get incomesEmptyState;

  /// No description provided for @incomesEmptyFilteredRange.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma receita entre {from} e {to}.'**
  String incomesEmptyFilteredRange(String from, String to);

  /// No description provided for @incomesEmptyFilteredFrom.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma receita a partir de {from}.'**
  String incomesEmptyFilteredFrom(String from);

  /// No description provided for @incomesEmptyFilteredTo.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma receita até {to}.'**
  String incomesEmptyFilteredTo(String to);

  /// No description provided for @removeIncomeConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover receita?'**
  String get removeIncomeConfirmTitle;

  /// No description provided for @removeIncomeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover receita'**
  String get removeIncomeTooltip;

  /// No description provided for @categoriasTitle.
  ///
  /// In pt, this message translates to:
  /// **'Categorias'**
  String get categoriasTitle;

  /// No description provided for @categoriasSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Cada categoria vira uma caixinha onde você guarda dinheiro todo mês.'**
  String get categoriasSubtitle;

  /// No description provided for @invalidBudgetOrBlankError.
  ///
  /// In pt, this message translates to:
  /// **'Informe um limite válido ou deixe em branco.'**
  String get invalidBudgetOrBlankError;

  /// No description provided for @invalidGoalOrBlankError.
  ///
  /// In pt, this message translates to:
  /// **'Informe uma meta válida ou deixe em branco.'**
  String get invalidGoalOrBlankError;

  /// No description provided for @removeCategoryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover categoria?'**
  String get removeCategoryTitle;

  /// No description provided for @removeCategoryBody.
  ///
  /// In pt, this message translates to:
  /// **'Isso também apaga alocações e gastos ligados a ela.'**
  String get removeCategoryBody;

  /// No description provided for @categoryNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome da categoria'**
  String get categoryNameLabel;

  /// No description provided for @categoryNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Aluguel, Mercado...'**
  String get categoryNameHint;

  /// No description provided for @kindSaveOption.
  ///
  /// In pt, this message translates to:
  /// **'Guardar'**
  String get kindSaveOption;

  /// No description provided for @kindSpendOption.
  ///
  /// In pt, this message translates to:
  /// **'Gastar'**
  String get kindSpendOption;

  /// No description provided for @kindSaveDescription.
  ///
  /// In pt, this message translates to:
  /// **'Cofrinho: dinheiro que você junta (viagem, reserva, projeto).'**
  String get kindSaveDescription;

  /// No description provided for @kindSpendDescription.
  ///
  /// In pt, this message translates to:
  /// **'Envelope: dinheiro que você separa pra gastar no mês.'**
  String get kindSpendDescription;

  /// No description provided for @monthlyBudgetLabel.
  ///
  /// In pt, this message translates to:
  /// **'Limite mensal de gasto (opcional)'**
  String get monthlyBudgetLabel;

  /// No description provided for @goalAmountLabel.
  ///
  /// In pt, this message translates to:
  /// **'Meta de valor (opcional)'**
  String get goalAmountLabel;

  /// No description provided for @goalAmountHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: 5000,00'**
  String get goalAmountHint;

  /// No description provided for @allowNegativeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Permitir saldo negativo'**
  String get allowNegativeLabel;

  /// No description provided for @allowNegativeDescription.
  ///
  /// In pt, this message translates to:
  /// **'Um gasto pode deixar essa caixinha devendo. A próxima alocação quita a dívida automaticamente.'**
  String get allowNegativeDescription;

  /// No description provided for @recurringLabel.
  ///
  /// In pt, this message translates to:
  /// **'Recorrente (repete todo mês)'**
  String get recurringLabel;

  /// No description provided for @categoriesEmptyState.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma categoria ainda. Crie a primeira acima.'**
  String get categoriesEmptyState;

  /// No description provided for @recurringChip.
  ///
  /// In pt, this message translates to:
  /// **'Recorrente'**
  String get recurringChip;

  /// No description provided for @oneTimeChip.
  ///
  /// In pt, this message translates to:
  /// **'Pontual'**
  String get oneTimeChip;

  /// No description provided for @deleteBlockedByDebtTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Quite a dívida dessa caixinha (saldo de volta a zero) antes de removê-la'**
  String get deleteBlockedByDebtTooltip;

  /// No description provided for @removeCategoryTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover categoria'**
  String get removeCategoryTooltip;

  /// No description provided for @editCategoryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar categoria'**
  String get editCategoryTitle;

  /// No description provided for @nameRequiredError.
  ///
  /// In pt, this message translates to:
  /// **'Informe um nome.'**
  String get nameRequiredError;

  /// No description provided for @debtBlocksSaveConversion.
  ///
  /// In pt, this message translates to:
  /// **'Quite a dívida dessa caixinha (saldo de volta a zero) antes de convertê-la em cofrinho.'**
  String get debtBlocksSaveConversion;

  /// No description provided for @settingsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Conta, backup e restauração de dados.'**
  String get settingsSubtitle;

  /// No description provided for @signOutButton.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get signOutButton;

  /// No description provided for @backupSectionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Backup'**
  String get backupSectionLabel;

  /// No description provided for @backupDescription.
  ///
  /// In pt, this message translates to:
  /// **'Exporte seus dados para um arquivo .json, ou importe um backup (substitui os dados atuais).'**
  String get backupDescription;

  /// No description provided for @exportBackupButton.
  ///
  /// In pt, this message translates to:
  /// **'Exportar backup'**
  String get exportBackupButton;

  /// No description provided for @importBackupButton.
  ///
  /// In pt, this message translates to:
  /// **'Importar backup'**
  String get importBackupButton;

  /// No description provided for @importConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Importar backup?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In pt, this message translates to:
  /// **'Isso substitui todos os dados atuais pelos dados do arquivo escolhido.'**
  String get importConfirmBody;

  /// No description provided for @importAction.
  ///
  /// In pt, this message translates to:
  /// **'Importar'**
  String get importAction;

  /// No description provided for @exportSuccessMessage.
  ///
  /// In pt, this message translates to:
  /// **'Backup exportado.'**
  String get exportSuccessMessage;

  /// No description provided for @importSuccessMessage.
  ///
  /// In pt, this message translates to:
  /// **'Backup importado.'**
  String get importSuccessMessage;

  /// No description provided for @exportErrorMessage.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao exportar: {error}'**
  String exportErrorMessage(String error);

  /// No description provided for @importErrorMessage.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao importar: {error}'**
  String importErrorMessage(String error);

  /// No description provided for @footerBrand.
  ///
  /// In pt, this message translates to:
  /// **'Dindin — um produto Café Labs'**
  String get footerBrand;

  /// No description provided for @languageSectionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get languageSectionLabel;

  /// No description provided for @languageSystemOption.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get languageSystemOption;

  /// No description provided for @editIncomeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar receita'**
  String get editIncomeTitle;

  /// No description provided for @editExpenseTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar gasto'**
  String get editExpenseTitle;

  /// No description provided for @editAllocationTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar alocação'**
  String get editAllocationTitle;

  /// No description provided for @cannotChangeCaixinhaNote.
  ///
  /// In pt, this message translates to:
  /// **'Não é possível mudar a caixinha por aqui — remova e lance de novo.'**
  String get cannotChangeCaixinhaNote;

  /// No description provided for @frozenDebtEditNote.
  ///
  /// In pt, this message translates to:
  /// **'Essa caixinha está devendo e não permite saldo negativo — só é possível reduzir o valor, não aumentá-lo.'**
  String get frozenDebtEditNote;

  /// No description provided for @budgetSpentOfLimit.
  ///
  /// In pt, this message translates to:
  /// **'Gasto: {spent} de {limit} este mês'**
  String budgetSpentOfLimit(String spent, String limit);

  /// No description provided for @budgetOverLimit.
  ///
  /// In pt, this message translates to:
  /// **'+{over} acima do limite'**
  String budgetOverLimit(String over);

  /// No description provided for @goalReached.
  ///
  /// In pt, this message translates to:
  /// **'Meta atingida: {saved} de {goal} guardados'**
  String goalReached(String saved, String goal);

  /// No description provided for @goalProgress.
  ///
  /// In pt, this message translates to:
  /// **'{saved} de {goal} guardados ({pct}%)'**
  String goalProgress(String saved, String goal, String pct);

  /// No description provided for @savedThisMonthPositive.
  ///
  /// In pt, this message translates to:
  /// **'Guardou +{amount} este mês'**
  String savedThisMonthPositive(String amount);

  /// No description provided for @savedThisMonthNegative.
  ///
  /// In pt, this message translates to:
  /// **'Retirou {amount} este mês'**
  String savedThisMonthNegative(String amount);

  /// No description provided for @debtIndicator.
  ///
  /// In pt, this message translates to:
  /// **'Devendo {amount}'**
  String debtIndicator(String amount);

  /// No description provided for @navDashboard.
  ///
  /// In pt, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navReceitas.
  ///
  /// In pt, this message translates to:
  /// **'Receitas'**
  String get navReceitas;

  /// No description provided for @navGastos.
  ///
  /// In pt, this message translates to:
  /// **'Gastos'**
  String get navGastos;

  /// No description provided for @navAssinaturas.
  ///
  /// In pt, this message translates to:
  /// **'Assinaturas'**
  String get navAssinaturas;

  /// No description provided for @navParcelamentos.
  ///
  /// In pt, this message translates to:
  /// **'Parcelas'**
  String get navParcelamentos;

  /// No description provided for @navCategorias.
  ///
  /// In pt, this message translates to:
  /// **'Categorias'**
  String get navCategorias;

  /// No description provided for @navAjustes.
  ///
  /// In pt, this message translates to:
  /// **'Ajustes'**
  String get navAjustes;

  /// No description provided for @navMore.
  ///
  /// In pt, this message translates to:
  /// **'Mais'**
  String get navMore;

  /// No description provided for @errorNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Esse lançamento não existe mais.'**
  String get errorNotFound;

  /// No description provided for @errorUnsupportedEdit.
  ///
  /// In pt, this message translates to:
  /// **'Essa alteração não é suportada — remova e lance de novo.'**
  String get errorUnsupportedEdit;

  /// No description provided for @errorSettleDebt.
  ///
  /// In pt, this message translates to:
  /// **'Quite a dívida dessa caixinha (saldo de volta a zero) antes de convertê-la em cofrinho ou removê-la.'**
  String get errorSettleDebt;

  /// No description provided for @errorExceedsBalance.
  ///
  /// In pt, this message translates to:
  /// **'Esse valor ultrapassa o saldo disponível.'**
  String get errorExceedsBalance;

  /// No description provided for @errorGenericSave.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar. Tente novamente.'**
  String get errorGenericSave;

  /// No description provided for @incomeSourceEstagio.
  ///
  /// In pt, this message translates to:
  /// **'Estágio'**
  String get incomeSourceEstagio;

  /// No description provided for @incomeSourceFreela.
  ///
  /// In pt, this message translates to:
  /// **'Freela'**
  String get incomeSourceFreela;

  /// No description provided for @incomeSourceOutro.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get incomeSourceOutro;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
