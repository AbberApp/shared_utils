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
    required String playStoreUrl,
    required String appStoreId,
    required void Function(String storeUrl) onUpdateAvailable,
    void Function(Object error)? onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroidUpdate(playStoreUrl, onUpdateAvailable);
      } else if (Platform.isIOS) {
        await checkIOSUpdate(
          playStoreUrl,
          appStoreId,
          onUpdateAvailable,
          onError,
        );
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
      updateRequired = true;
      onUpdateAvailable(storeUrl);
    }
  }

  /// فحص تحديث iOS مباشرة من iTunes API
  /// [testLocalVersion] للاختبار فقط - لتجاوز الإصدار المحلي
  Future<void> checkIOSUpdate(
    String storeUrl,
    String appStoreId,
    void Function(String storeUrl) onUpdateAvailable,
    void Function(Object error)? onError,
  ) async {
    try {
      log('Checking for update - iOS', name: 'AppUpdateChecker');
      final String localVersion;

      final packageInfo = await PackageInfo.fromPlatform();
      localVersion = packageInfo.version;

      final response = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {'id': appStoreId, 'version': '2'},
      );

      print('AppUpdateChecker Fetched app info from App Store {${response.data.toString()}- ${response.statusCode}}',);

      if (response.statusCode != 200) {
        log('Failed to fetch app info from App Store', name: 'AppUpdateChecker');
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

      final appData = results.first as Map<String, dynamic>;
      final storeVersion = appData['version'] as String?;

      if (storeVersion == null) {
        log('Store version not found', name: 'AppUpdateChecker');
        return;
      }

      final updateAvailable = _isUpdateAvailable(localVersion, storeVersion);

      if (updateAvailable) {
        updateRequired = true;
        onUpdateAvailable(storeUrl);
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  /// مقارنة الإصدارات
  bool _isUpdateAvailable(String localVersion, String storeVersion) {
    final localParts = localVersion.split('+').first.split('.');
    final storeParts = storeVersion.split('+').first.split('.');

    final maxLength = localParts.length > storeParts.length
        ? localParts.length
        : storeParts.length;

    for (int i = 0; i < maxLength; i++) {
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

  /// تنفيذ التحديث الفوري (Android فقط)
  Future<bool> performImmediateUpdate() async {
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  }
}
