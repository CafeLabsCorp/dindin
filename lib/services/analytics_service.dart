import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Analytics — decision 7 (ratified 2026-08-31, see
/// docs/BACKEND.md): instrument the MINIMUM with Google Analytics for
/// Firebase, opt-out (not opt-in), no financial content in any event.
///
/// Every event here carries ONLY the fact that an action happened — never an
/// amount, balance, description, or any other financial content. That
/// boundary is enforced by this class's method signatures taking no
/// parameters at all: there is nothing for a call site to accidentally pass
/// through.
///
/// `AD_ID` / Google Advertising signals are turned off in
/// `android/app/src/main/AndroidManifest.xml` (the `google_analytics_*`
/// meta-data and the `AD_ID` permission removal) — nothing in THIS file
/// requests or forwards an advertising id; that is a manifest-level
/// guarantee, not a runtime one, on purpose (it holds even if a future call
/// site here got it wrong).
class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  /// Applies the Analytics opt-out toggle (Ajustes -> Privacidade). Called
  /// once with the stored preference on every app start/sign-in (see
  /// `analyticsOptOutProvider`'s `ref.listen(..., fireImmediately: true)` in
  /// `AppShell`) and again the moment the user flips it.
  Future<void> setEnabled(bool enabled) => _analytics.setAnalyticsCollectionEnabled(enabled);

  /// A Firebase Auth account was just created — either an email/password
  /// registration or the FIRST Google sign-in for this person (see
  /// `LoginPage`, which checks `UserCredential.additionalUserInfo?.isNewUser`
  /// so this fires exactly once per account, regardless of which method
  /// created it).
  Future<void> logAccountCreated() => _analytics.logEvent(name: 'account_created');

  /// A caixinha (category) was created — see `CategoriasPage`.
  Future<void> logCaixinhaCreated() => _analytics.logEvent(name: 'caixinha_created');

  /// The FIRST expense this account has ever logged (checked by the caller
  /// against the previously-empty `expensesProvider` list — see
  /// `GastosPage._submit`).
  Future<void> logFirstExpenseLogged() => _analytics.logEvent(name: 'first_expense_logged');

  /// The user exported their data as a JSON backup — see
  /// `ImportExportService.exportToFile`.
  Future<void> logExportUsed() => _analytics.logEvent(name: 'export_used');
}
