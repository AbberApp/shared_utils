import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// مدقق تحديثات التطبيق
class AppUpdateChecker {
  AppUpdateChecker._();

  static final instance = AppUpdateChecker._();

  /// هل تم العثور على تحديث ويجب منع الانتقال لشاشات أخرى
  bool updateRequired = false;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// التحقق من توفر تحديث
  Future<void> checkForUpdate({
    required String appStoreId,
    required void Function() onUpdateAvailable,
    void Function(Object error)? onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroidUpdate(onUpdateAvailable);
      } else if (Platform.isIOS) {
        await checkIOSUpdate(appStoreId, onUpdateAvailable, onError);
      }
    } catch (e) {
      log('Error checking for update: $e', name: 'AppUpdateChecker', error: e);
      onError?.call(e);
    }
  }

  Future<void> _checkAndroidUpdate(void Function() onUpdateAvailable) async {
    final updateInfo = await InAppUpdate.checkForUpdate();

    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      log('Update available - Android', name: 'AppUpdateChecker');
      updateRequired = true;
      onUpdateAvailable();
    }
  }

  /// فحص تحديث iOS مباشرة من iTunes API
  /// [testLocalVersion] للاختبار فقط - لتجاوز الإصدار المحلي
  Future<void> checkIOSUpdate(
    String appStoreId,
    void Function() onUpdateAvailable,
    void Function(Object error)? onError,
  ) async {
    try {
      log('Checking for update - iOS', name: 'AppUpdateChecker');
      log('App Store ID: $appStoreId', name: 'AppUpdateChecker');
      final String localVersion;

      final packageInfo = await PackageInfo.fromPlatform();

      // إضافة timestamp لمنع cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {
          'id': appStoreId,
          't': timestamp, // لمنع cache
        },
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
      );

      if (response.statusCode != 200) {
        log(
          'Failed to fetch app info from App Store',
          name: 'AppUpdateChecker',
        );
        throw Exception(
          'Failed to fetch app info from App Store: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> jsonResult;
      if (response.data is String) {
        jsonResult = json.decode(response.data as String);
      } else {
        jsonResult = response.data as Map<String, dynamic>;
      }
      final results = jsonResult['results'] as List?;

      if (results == null || results.isEmpty) {
        log('App not found in App Store', name: 'AppUpdateChecker');
        return;
      }

      // استخراج جميع الإصدارات من النتائج
      final storeVersions = <String>[];

      log('Number of results: ${results.length}', name: 'AppUpdateChecker');

      for (final result in results) {
        if (result is Map<String, dynamic>) {
          // استخراج version (مثل "9.9.6")
          final version = result['version'] as String?;
          log('Extracted version from result: $version', name: 'AppUpdateChecker');
          if (version != null && version.isNotEmpty) {
            storeVersions.add(version);
          }
        }
      }

      log('Found store versions: $storeVersions', name: 'AppUpdateChecker');

      if (storeVersions.isEmpty) {
        log('No valid versions found in App Store', name: 'AppUpdateChecker');
        return;
      }

      // إيجاد أكبر إصدار
      final storeVersion = _findLatestVersion(storeVersions);

      localVersion = packageInfo.version;

      log('Local version: $localVersion', name: 'AppUpdateChecker');
      log('Local build number: ${packageInfo.buildNumber}', name: 'AppUpdateChecker');
      log('Store version (latest): $storeVersion', name: 'AppUpdateChecker');

      final updateAvailable = _isUpdateAvailable(
        localVersion: localVersion,
        storeVersion: storeVersion,
      );

      log('Update available: $updateAvailable', name: 'AppUpdateChecker');

      if (updateAvailable) {
        updateRequired = true;
        onUpdateAvailable();
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  /// مقارنة الإصدارات (major.minor.patch)
  bool _isUpdateAvailable({
    required String localVersion,
    required String storeVersion,
  }) {
    try {
      localVersion = localVersion.trim();
      storeVersion = storeVersion.trim();

      log(
        'Comparing versions: local=$localVersion, store=$storeVersion',
        name: 'AppUpdateChecker',
      );

      if (localVersion == storeVersion) return false;

      return _compareVersions(localVersion, storeVersion);
    } catch (e) {
      log('Error comparing versions: $e', name: 'AppUpdateChecker', error: e);
      return false;
    }
  }

  /// مقارنة أرقام الإصدار (major.minor.patch)
  bool _compareVersions(String local, String store) {
    final localParts = local.split('.');
    final storeParts = store.split('.');

    // مقارنة حتى 3 أجزاء (major, minor, patch)
    for (int i = 0; i < 3; i++) {
      final localPart = i < localParts.length
          ? int.tryParse(localParts[i]) ?? 0
          : 0;
      final storePart = i < storeParts.length
          ? int.tryParse(storeParts[i]) ?? 0
          : 0;

      if (storePart > localPart) return true;
      if (storePart < localPart) return false;
    }

    return false;
  }

  /// إيجاد أكبر إصدار من قائمة الإصدارات
  String _findLatestVersion(List<String> versions) {
    if (versions.isEmpty) return '0.0.0';
    if (versions.length == 1) return versions.first;

    String latest = versions.first;

    for (int i = 1; i < versions.length; i++) {
      final current = versions[i];

      if (_compareVersions(latest, current)) {
        latest = current;
      }
    }

    return latest;
  }

  /// تنفيذ التحديث الفوري (Android فقط)
  Future<bool> performImmediateUpdate() async {
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  }
}
