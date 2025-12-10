import 'dart:developer';
import 'dart:io';

import 'package:app_version_update/app_version_update.dart';
import 'package:in_app_update/in_app_update.dart';

/// مدقق تحديثات التطبيق
class AppUpdateChecker {
  AppUpdateChecker._();

  static final instance = AppUpdateChecker._();

  /// التحقق من توفر تحديث
  Future<void> checkForUpdate({
    required String playStoreUrl,
    required String appStoreId,
    required void Function(String storeUrl) onUpdateAvailable,
    void Function(Object error)? onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroidUpdate(playStoreUrl, onUpdateAvailable);
      } else if (Platform.isIOS) {
        await _checkIOSUpdate(playStoreUrl, appStoreId, onUpdateAvailable);
      }
    } catch (e) {
      log('Error checking for update: $e', name: 'AppUpdateChecker', error: e);
      onError?.call(e);
    }
  }

  Future<void> _checkAndroidUpdate(
    String storeUrl,
    void Function(String storeUrl) onUpdateAvailable,
  ) async {
    final updateInfo = await InAppUpdate.checkForUpdate();

    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      log('Update available - Android', name: 'AppUpdateChecker');
      onUpdateAvailable(storeUrl);
    }
  }

  Future<void> _checkIOSUpdate(
    String storeUrl,
    String appStoreId,
    void Function(String storeUrl) onUpdateAvailable,
  ) async {
    final result = await AppVersionUpdate.checkForUpdates(appleId: appStoreId);

    if (result.canUpdate ?? false) {
      log('Update available - iOS', name: 'AppUpdateChecker');
      onUpdateAvailable(result.storeUrl ?? storeUrl);
    }
  }

  /// تنفيذ التحديث الفوري (Android فقط)
  Future<bool> performImmediateUpdate() async {
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  }
}
