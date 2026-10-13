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

  /// Downloads the update, then restarts the app on the new version once it is
  /// ready. Play shows its own progress UI while it downloads. Best-effort.
  Future<void> startUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {}
  }
}
