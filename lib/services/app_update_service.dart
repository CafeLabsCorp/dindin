import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:in_app_update/in_app_update.dart';

/// Google Play's in-app update, for telling someone a newer version is out
/// without relying on them noticing on the store.
///
/// Android + installed from Play only. Everywhere else (web, a debug build, an
/// APK installed by hand, a store that isn't Play) the plugin has nothing to
/// ask, so every call here quietly says "no update" instead of throwing — the
/// reminder is a courtesy, never something that may break the app.
class AppUpdateService {
  const AppUpdateService();

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether Play has a newer build that can be installed without leaving the
  /// app (a "flexible" update: downloads in the background).
  Future<bool> isUpdateAvailable() async {
    if (!_supported) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable && info.flexibleUpdateAllowed;
    } catch (_) {
      return false;
    }
  }

  /// Asks Play to download the update and waits for the download to finish.
  /// Play shows its own progress UI. Returns true only once the new version is
  /// downloaded and ready: the caller then offers [restartToInstall], because
  /// restarting is the user's call (it may be mid-entry). Best-effort: false
  /// when the user declined, the download failed or Play is not available.
  Future<bool> startUpdate() async {
    if (!_supported) return false;
    try {
      // Listen before starting so a fast download can't slip past.
      final done = InAppUpdate.installUpdateListener.firstWhere(
        (s) => s == InstallStatus.downloaded || s == InstallStatus.failed || s == InstallStatus.canceled,
      );
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return false;
      return await done == InstallStatus.downloaded;
    } catch (_) {
      return false;
    }
  }

  /// Installs the downloaded update and restarts the app on it.
  Future<void> restartToInstall() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }
}
