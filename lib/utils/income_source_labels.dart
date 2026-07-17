import '../l10n/app_localizations.dart';
import '../models/income_source.dart';

/// [IncomeSource] values shared between the Receitas create form and the
/// edit-income sheet (moved out of a private `_sources` constant that used
/// to live only in `receitas_page.dart`, so the edit form doesn't need to
/// duplicate it).
const incomeSourceValues = [IncomeSource.estagio, IncomeSource.freela, IncomeSource.outro];

/// Localized display label for an [IncomeSource] — separate from
/// `IncomeSource.value` (the fixed, Portuguese-only string stored in
/// Firestore's `income.source` field; changing it would be a data
/// migration, not a translation). Mirrors the `categoriaLabel`-style pattern
/// used elsewhere in the ecosystem for fixed/data identifiers vs. display
/// copy.
String incomeSourceLabel(AppLocalizations l10n, IncomeSource source) {
  return switch (source) {
    IncomeSource.estagio => l10n.incomeSourceEstagio,
    IncomeSource.freela => l10n.incomeSourceFreela,
    IncomeSource.outro => l10n.incomeSourceOutro,
  };
}
