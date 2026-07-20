// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get add => 'Adicionar';

  @override
  String get remove => 'Remover';

  @override
  String get confirm => 'Confirmar';

  @override
  String get dateLabel => 'Data';

  @override
  String get amountLabel => 'Valor';

  @override
  String get amountHint => '0,00';

  @override
  String get descriptionOptionalLabel => 'Descrição (opcional)';

  @override
  String get filterFromLabel => 'De';

  @override
  String get filterToLabel => 'Até';

  @override
  String get clearFilterButton => 'Limpar filtro';

  @override
  String get accountLabel => 'Conta';

  @override
  String get caixinhaLabel => 'Caixinha';

  @override
  String get removedCategoryLabel => 'categoria removida';

  @override
  String get invalidAmountError => 'Informe um valor válido.';

  @override
  String genericErrorPrefix(String error) {
    return 'Erro: $error';
  }

  @override
  String get authCreateAccountTitle => 'Criar conta';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailInvalidError => 'E-mail inválido';

  @override
  String get passwordLabel => 'Senha';

  @override
  String get passwordMinLengthError => 'Mínimo 6 caracteres';

  @override
  String get haveAccountToggle => 'Já tenho conta';

  @override
  String get createAccountToggle => 'Criar uma conta';

  @override
  String get signInWithGoogle => 'Entrar com Google';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardSubtitle => 'Visão geral da conta e do mês atual.';

  @override
  String get totalBalanceLabel => 'Saldo total';

  @override
  String get accountBalanceDescription =>
      'Dinheiro recebido e ainda não alocado em nenhuma caixinha.';

  @override
  String get allocateButton => 'Alocar';

  @override
  String get receivedThisMonthLabel => 'Recebido este mês';

  @override
  String get spentThisMonthLabel => 'Gasto este mês';

  @override
  String get monthBalanceLabel => 'Saldo do mês';

  @override
  String get caixinhasTitle => 'Caixinhas';

  @override
  String get transferButton => 'Transferir';

  @override
  String get caixinhasEmptyState =>
      'Crie categorias e aloque receitas para ver suas caixinhas aqui.';

  @override
  String sinceDatePrefix(String date) {
    return 'desde $date';
  }

  @override
  String get historyTitle => 'Histórico mensal — recebido x gasto';

  @override
  String get historyEmptyState =>
      'Lance receitas e gastos para ver o histórico por mês.';

  @override
  String get allocateDialogTitle => 'Alocar pra caixinha';

  @override
  String availableInAccountLabel(String amount) {
    return 'Disponível na conta: $amount';
  }

  @override
  String get transferDialogTitle => 'Transferir entre caixinhas';

  @override
  String availableAtOriginLabel(String amount) {
    return 'Disponível na origem: $amount';
  }

  @override
  String get transferOriginLabel => 'Origem';

  @override
  String get transferDestinationLabel => 'Destino';

  @override
  String get originDestinationMustDifferError =>
      'Origem e destino precisam ser diferentes.';

  @override
  String get receivedLegend => 'Recebido';

  @override
  String get spentLegend => 'Gasto';

  @override
  String get gastosTitle => 'Gastos';

  @override
  String get gastosSubtitle =>
      'Registre uma saída direto da conta ou de uma caixinha específica.';

  @override
  String get frozenDebtBlockShort =>
      'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos.';

  @override
  String get frozenDebtBlockLong =>
      'Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos, ou ligue \"Permitir saldo negativo\" na categoria.';

  @override
  String get expenseSourceLabel => 'De onde sai';

  @override
  String get expenseDescriptionHint => 'Ex: supermercado';

  @override
  String availableLabel(String amount) {
    return 'Disponível: $amount';
  }

  @override
  String get submitExpenseButton => 'Lançar gasto';

  @override
  String get expensesListTitle => 'Gastos lançados';

  @override
  String get expensesEmptyState => 'Nenhum gasto lançado ainda.';

  @override
  String expensesEmptyFilteredRange(String from, String to) {
    return 'Nenhum gasto entre $from e $to.';
  }

  @override
  String expensesEmptyFilteredFrom(String from) {
    return 'Nenhum gasto a partir de $from.';
  }

  @override
  String expensesEmptyFilteredTo(String to) {
    return 'Nenhum gasto até $to.';
  }

  @override
  String get removeExpenseConfirmTitle => 'Remover esse gasto?';

  @override
  String get removeExpenseTooltip => 'Remover gasto';

  @override
  String get receitasTitle => 'Receitas';

  @override
  String get receitasSubtitle =>
      'Lance o quanto entrou e de onde veio. O valor cai direto na sua conta —\naloque em caixinhas quando quiser, no Dashboard.';

  @override
  String get incomeSourceFieldLabel => 'Origem';

  @override
  String get incomeDescriptionHint => 'Ex: salário julho';

  @override
  String get submitIncomeButton => 'Lançar receita';

  @override
  String get incomesListTitle => 'Receitas lançadas';

  @override
  String get incomesEmptyState => 'Nenhuma receita lançada ainda.';

  @override
  String incomesEmptyFilteredRange(String from, String to) {
    return 'Nenhuma receita entre $from e $to.';
  }

  @override
  String incomesEmptyFilteredFrom(String from) {
    return 'Nenhuma receita a partir de $from.';
  }

  @override
  String incomesEmptyFilteredTo(String to) {
    return 'Nenhuma receita até $to.';
  }

  @override
  String get removeIncomeConfirmTitle => 'Remover receita?';

  @override
  String get removeIncomeTooltip => 'Remover receita';

  @override
  String get categoriasTitle => 'Categorias';

  @override
  String get categoriasSubtitle =>
      'Cada categoria vira uma caixinha onde você guarda dinheiro todo mês.';

  @override
  String get invalidBudgetOrBlankError =>
      'Informe um limite válido ou deixe em branco.';

  @override
  String get invalidGoalOrBlankError =>
      'Informe uma meta válida ou deixe em branco.';

  @override
  String get removeCategoryTitle => 'Remover categoria?';

  @override
  String get removeCategoryBody =>
      'Isso também apaga alocações e gastos ligados a ela.';

  @override
  String get categoryNameLabel => 'Nome da categoria';

  @override
  String get categoryNameHint => 'Ex: Aluguel, Mercado...';

  @override
  String get kindSaveOption => 'Guardar';

  @override
  String get kindSpendOption => 'Gastar';

  @override
  String get kindSaveDescription =>
      'Cofrinho: dinheiro que você junta (viagem, reserva, projeto).';

  @override
  String get kindSpendDescription =>
      'Envelope: dinheiro que você separa pra gastar no mês.';

  @override
  String get monthlyBudgetLabel => 'Limite mensal de gasto (opcional)';

  @override
  String get goalAmountLabel => 'Meta de valor (opcional)';

  @override
  String get goalAmountHint => 'Ex: 5000,00';

  @override
  String get allowNegativeLabel => 'Permitir saldo negativo';

  @override
  String get allowNegativeDescription =>
      'Um gasto pode deixar essa caixinha devendo. A próxima alocação quita a dívida automaticamente.';

  @override
  String get recurringLabel => 'Recorrente (repete todo mês)';

  @override
  String get categoriesEmptyState =>
      'Nenhuma categoria ainda. Crie a primeira acima.';

  @override
  String get recurringChip => 'Recorrente';

  @override
  String get oneTimeChip => 'Pontual';

  @override
  String get deleteBlockedByDebtTooltip =>
      'Quite a dívida dessa caixinha (saldo de volta a zero) antes de removê-la';

  @override
  String get removeCategoryTooltip => 'Remover categoria';

  @override
  String get editCategoryTitle => 'Editar categoria';

  @override
  String get nameRequiredError => 'Informe um nome.';

  @override
  String get debtBlocksSaveConversion =>
      'Quite a dívida dessa caixinha (saldo de volta a zero) antes de convertê-la em cofrinho.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSubtitle => 'Conta, backup e restauração de dados.';

  @override
  String get signOutButton => 'Sair';

  @override
  String get backupSectionLabel => 'Backup';

  @override
  String get backupDescription =>
      'Exporte seus dados para um arquivo .json, ou importe um backup (substitui os dados atuais).';

  @override
  String get exportBackupButton => 'Exportar backup';

  @override
  String get importBackupButton => 'Importar backup';

  @override
  String get importConfirmTitle => 'Importar backup?';

  @override
  String get importConfirmBody =>
      'Isso substitui todos os dados atuais pelos dados do arquivo escolhido.';

  @override
  String get importAction => 'Importar';

  @override
  String get exportSuccessMessage => 'Backup exportado.';

  @override
  String get importSuccessMessage => 'Backup importado.';

  @override
  String exportErrorMessage(String error) {
    return 'Erro ao exportar: $error';
  }

  @override
  String importErrorMessage(String error) {
    return 'Erro ao importar: $error';
  }

  @override
  String get footerBrand => 'Dindin — um produto Café Labs';

  @override
  String get languageSectionLabel => 'Idioma';

  @override
  String get languageSystemOption => 'Sistema';

  @override
  String get editIncomeTitle => 'Editar receita';

  @override
  String get editExpenseTitle => 'Editar gasto';

  @override
  String get editAllocationTitle => 'Editar alocação';

  @override
  String get cannotChangeCaixinhaNote =>
      'Não é possível mudar a caixinha por aqui — remova e lance de novo.';

  @override
  String get frozenDebtEditNote =>
      'Essa caixinha está devendo e não permite saldo negativo — só é possível reduzir o valor, não aumentá-lo.';

  @override
  String budgetSpentOfLimit(String spent, String limit) {
    return 'Gasto: $spent de $limit este mês';
  }

  @override
  String budgetOverLimit(String over) {
    return '+$over acima do limite';
  }

  @override
  String goalReached(String saved, String goal) {
    return 'Meta atingida: $saved de $goal guardados';
  }

  @override
  String goalProgress(String saved, String goal, String pct) {
    return '$saved de $goal guardados ($pct%)';
  }

  @override
  String savedThisMonthPositive(String amount) {
    return 'Guardou +$amount este mês';
  }

  @override
  String savedThisMonthNegative(String amount) {
    return 'Retirou $amount este mês';
  }

  @override
  String debtIndicator(String amount) {
    return 'Devendo $amount';
  }

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navReceitas => 'Receitas';

  @override
  String get navGastos => 'Gastos';

  @override
  String get navCategorias => 'Categorias';

  @override
  String get navAjustes => 'Ajustes';

  @override
  String get errorNotFound => 'Esse lançamento não existe mais.';

  @override
  String get errorUnsupportedEdit =>
      'Essa alteração não é suportada — remova e lance de novo.';

  @override
  String get errorSettleDebt =>
      'Quite a dívida dessa caixinha (saldo de volta a zero) antes de convertê-la em cofrinho ou removê-la.';

  @override
  String get errorExceedsBalance => 'Esse valor ultrapassa o saldo disponível.';

  @override
  String get errorGenericSave => 'Não foi possível salvar. Tente novamente.';

  @override
  String get incomeSourceEstagio => 'Estágio';

  @override
  String get incomeSourceFreela => 'Freela';

  @override
  String get incomeSourceOutro => 'Outro';
}
