import '../models/income_source.dart';

/// pt-BR labels for [IncomeSource], shared between the Receitas create form
/// and the new edit-income sheet (moved out of a private `_sources` constant
/// that used to live only in `receitas_page.dart`, so the edit form doesn't
/// need to duplicate it).
const incomeSourceOptions = [
  (value: IncomeSource.estagio, label: 'Estágio'),
  (value: IncomeSource.freela, label: 'Freela'),
  (value: IncomeSource.outro, label: 'Outro'),
];
