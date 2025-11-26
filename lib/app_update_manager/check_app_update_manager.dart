import 'dart:developer';
import 'dart:io';

import 'package:app_version_update/app_version_update.dart';
import 'package:app_version_update/data/models/app_version_result.dart';
import 'package:in_app_update/in_app_update.dart';

class CheckAppUpdateManager {
  CheckAppUpdateManager._();

  static final CheckAppUpdateManager instance = CheckAppUpdateManager._();

  Future<void> checkForUpdate({
    required String storeUrl,
    required String appStoreId,
    required void Function(String storeUrl) onUpdateAvailable,
    void Function(Object error)? onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroidUpdate(storeUrl, onUpdateAvailable);
      } else if (Platform.isIOS) {
        await _checkIOSUpdate(storeUrl, appStoreId, onUpdateAvailable);
      }
    } catch (e) {
      log(
        'Error checking for update: $e',
        name: 'CheckAppUpdateManager',
        error: e,
      );
      onError?.call(e);
    }
  }

  Future<void> _checkAndroidUpdate(
    String storeUrl,
    void Function(String storeUrl) onUpdateAvailable,
  ) async {
    final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      log('Update available - Android', name: 'CheckAppUpdateManager');
      onUpdateAvailable(storeUrl);
    }
  }

  Future<void> _checkIOSUpdate(
    String storeUrl,
    String appStoreId,
    void Function(String storeUrl) onUpdateAvailable,
  ) async {
    final AppVersionResult appVersionResult =
        await AppVersionUpdate.checkForUpdates(appleId: appStoreId);

    if (appVersionResult.canUpdate ?? false) {
      log('Update available - iOS', name: 'CheckAppUpdateManager');
      onUpdateAvailable(appVersionResult.storeUrl ?? storeUrl);
    }
  }

  Future<bool> updateApp() async {
    AppUpdateResult result = await InAppUpdate.performImmediateUpdate();

    return result == AppUpdateResult.success;
  }
}
