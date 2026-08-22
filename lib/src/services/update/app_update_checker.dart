import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_release_info.dart';

/// مدقق تحديثات التطبيق
class AppUpdateChecker {
  AppUpdateChecker._();

  static final instance = AppUpdateChecker._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// التحقق من توفر تحديث
  Future<void> checkForUpdate({
    required String appStoreId,
    required void Function(bool isMandatory) onUpdateAvailable,
    void Function(Object error)? onError,
    /// تفاصيل الإصدار (رقمه وملاحظاته وتاريخه) — تُستدعى قبل [onUpdateAvailable]
    /// حين تتوفّر. تُقرأ من iTunes، وتصل على أندرويد أيضاً (نصّ «ما الجديد»
    /// واحد في المتجرين عملياً، وPlay لا يوفّره بلا مصادقة).
    void Function(AppReleaseInfo info)? onReleaseInfo,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroidUpdate(onUpdateAvailable);
        // أندرويد لا يمنحنا الملاحظات؛ نجلبها من آبل لعرضها كما هي.
        if (onReleaseInfo != null) {
          await fetchReleaseInfo(appStoreId)
              .then((AppReleaseInfo? info) {
                if (info != null) onReleaseInfo(info);
              })
              // ميزة عرضٍ فقط: تفشل بصمت ولا تمنع تدفّق التحديث.
              .catchError((Object _) {});
        }
      } else if (Platform.isIOS) {
        await checkIOSUpdate(appStoreId, onUpdateAvailable, onError,
            onReleaseInfo: onReleaseInfo);
      }
    } catch (e) {
      log('Error checking for update: $e', name: 'AppUpdateChecker', error: e);
      onError?.call(e);
    }
  }

  Future<void> _checkAndroidUpdate(void Function(bool isMandatory) onUpdateAvailable) async {
    final updateInfo = await InAppUpdate.checkForUpdate();

    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      // Android exposes only versionCode (not versionName), so we can't tell a
      // minor bump from a patch → every available Android update is mandatory.
      log('Update available - Android (mandatory)', name: 'AppUpdateChecker');
      onUpdateAvailable(true);
    }
  }

  /// فحص تحديث iOS مباشرة من iTunes API
  Future<void> checkIOSUpdate(
    String appStoreId,
    void Function(bool isMandatory) onUpdateAvailable,
    void Function(Object error)? onError, {
    void Function(AppReleaseInfo info)? onReleaseInfo,
  }) async {
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
        // iOS gives the store versionName → mandatory only when the major or
        // minor segment changed; a patch-only bump is optional.
        final bool isMandatory = isMandatoryUpdate(localVersion, storeVersion);

        // التفاصيل أوّلاً: الواجهة تعرضها في نفس نافذة التحديث، فلا يجوز أن
        // تُفتح النافذة ثم تُملأ الملاحظات بعدها.
        if (onReleaseInfo != null) {
          final Map<String, dynamic>? match = results
              .whereType<Map<String, dynamic>>()
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (Map<String, dynamic>? r) => r?['version'] == storeVersion,
                orElse: () => results.first as Map<String, dynamic>,
              );
          if (match != null) {
            onReleaseInfo(
              AppReleaseInfo.fromItunes(match, isMandatory: isMandatory),
            );
          }
        }

        onUpdateAvailable(isMandatory);
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  /// يجلب تفاصيل الإصدار المنشور في المتجر (رقمه، ملاحظاته، تاريخه، رابطه)
  /// بلا مقارنة ولا شرط تحديث — يصلح لعرض «ما الجديد» في أي موضع.
  ///
  /// المصدر iTunes Lookup: طلبة `GET` واحدة بلا مصادقة. Google Play لا يوفّر
  /// مقابلاً عامّاً (يلزمه Play Developer API بحساب خدمة، أو كشط الصفحة).
  Future<AppReleaseInfo?> fetchReleaseInfo(String appStoreId) async {
    try {
      final response = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: <String, dynamic>{
          'id': appStoreId,
          't': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: const <String, String>{
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );
      if (response.statusCode != 200) return null;

      final Map<String, dynamic> data = response.data is String
          ? json.decode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      final List<dynamic>? results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final Map<String, dynamic> first = results.first as Map<String, dynamic>;
      final String storeVersion = (first['version'] as String?) ?? '';
      final String localVersion = (await PackageInfo.fromPlatform()).version;

      return AppReleaseInfo.fromItunes(
        first,
        isMandatory: storeVersion.isEmpty
            ? false
            : isMandatoryUpdate(localVersion, storeVersion),
      );
    } catch (e) {
      log('fetchReleaseInfo failed: $e', name: 'AppUpdateChecker', error: e);
      return null;
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

  /// تحديد إجباريّة التحديث (iOS): إجباريّ إذا تغيّرت الخانة الكبرى أو الوسطى
  /// (major/minor)، واختياريّ إذا كان التغيير في الخانة الصغرى (patch) فقط.
  @visibleForTesting
  bool isMandatoryUpdate(String local, String store) {
    final List<int> l = _versionParts(local);
    final List<int> s = _versionParts(store);
    if (s[0] != l[0]) return s[0] > l[0]; // major
    if (s[1] != l[1]) return s[1] > l[1]; // minor
    return false; // patch only → اختياريّ
  }

  /// تفكيك الإصدار إلى [major, minor, patch] متجاهلاً لاحقة البناء (+N أو -x).
  List<int> _versionParts(String version) {
    final String core = version.trim().split('+').first.split('-').first;
    final List<String> parts = core.split('.');
    return [
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    ];
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
