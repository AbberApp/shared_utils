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
    /// يُستدعى عند توفّر تحديث. الوسيط الثاني يحمل تفاصيل الإصدار (رقمه
    /// وملاحظاته وتاريخه) حين تتوفّر من المتجر، و`null` إن تعذّر جلبها.
    ///
    /// الوسيط اختياريّ عمداً: أربعة تطبيقات تستهلك هذه الدالة بدالّة من وسيط
    /// واحد، ودارت تقبل تمرير دالّة أقلّ وسائط — فلا يكسرها هذا التوسيع.
    required void Function(bool isMandatory, [AppReleaseInfo? info])
        onUpdateAvailable,
    void Function(Object error)? onError,
  }) async {
    // الـcallback يُستدعى **بعد** كتلة try لا داخلها: خطأٌ يقع في واجهة
    // التطبيق (شاشة التحديث الإجباريّ مثلاً) ليس فشلَ فحص، فلا يُبتلع في
    // onError ويُنسب زوراً إلى تعذّر الاتّصال بالمتجر.
    bool? isMandatory;
    AppReleaseInfo? info;
    try {
      if (Platform.isAndroid) {
        final (bool, AppReleaseInfo?)? result =
            await _checkAndroidUpdate(appStoreId);
        if (result != null) {
          isMandatory = result.$1;
          info = result.$2;
        }
      } else if (Platform.isIOS) {
        // checkIOSUpdate يتكفّل بنداء الـcallback وبـonError، فلا نكرّرهما.
        await checkIOSUpdate(appStoreId, onUpdateAvailable, onError);
        return;
      }
    } on Object catch (e, s) {
      // `on Object` لا `on Exception`: in_app_update قد يرمي Error لا Exception
      // (مثل StateError من firstWhere بلا orElse على installStatus غير معروف)،
      // و`on Exception` يتركه يهرب إلى الـzone فيسقط التطبيق.
      log(
        'Error checking for update: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
      onError?.call(e);
      return;
    }

    if (isMandatory != null) onUpdateAvailable(isMandatory, info);
  }

  /// يُرجع `(isMandatory, info)` عند توفّر تحديث، و`null` إن لم يتوفّر.
  Future<(bool, AppReleaseInfo?)?> _checkAndroidUpdate(
    String appStoreId,
  ) async {
    final updateInfo = await InAppUpdate.checkForUpdate();

    if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
      return null;
    }

    // Android exposes only versionCode (not versionName), so we can't tell a
    // minor bump from a patch → every available Android update is mandatory.
    log('Update available - Android (mandatory)', name: 'AppUpdateChecker');
    // Play لا يوفّر ملاحظات الإصدار بلا مصادقة، فنقرأها من آبل — النصّ نفسه
    // في المتجرين عملياً. عرضٌ فقط: يُسجَّل خطؤه ولا يعطّل التحديث.
    AppReleaseInfo? info;
    try {
      info = await fetchReleaseInfo(appStoreId);
    } on Object catch (e, s) {
      // لا يُبتلع صامتاً: يُسجَّل مع أثر المكدّس فيلتقطه Sentry، ثمّ يمضي
      // التحديث بلا ملاحظات — فشلُ العرض ليس فشلَ فحص.
      log(
        'Fetching release notes failed: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
      info = null;
    }
    return (true, info);
  }

  /// فحص تحديث iOS مباشرة من iTunes API
  Future<void> checkIOSUpdate(
    String appStoreId,
    void Function(bool isMandatory, [AppReleaseInfo? info]) onUpdateAvailable,
    void Function(Object error)? onError,
  ) async {
    // يُستدعى الـcallback بعد كتلة try لا داخلها — راجع التعليل في checkForUpdate.
    bool? pendingMandatory;
    AppReleaseInfo? pendingInfo;
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

        // التفاصيل تصل مع نفس النداء — نفس الاستجابة التي قارنّا بها الإصدار
        // تحمل `releaseNotes`، فلا طلبة ثانية ولا ردّ منفصل.
        //
        // الاحتياطيّ خريطةٌ فارغة لا `results.first`: العنصر الأوّل قد لا يكون
        // خريطةً أصلاً — `whereType` أسقطت غير الخرائط للتوّ — فيرمي التحويل
        // TypeError تبتلعه `on Object` أدناه فيضيع إشعار التحديث بأكمله. ولأنّ
        // `storeVersion` مشتقٌّ من هذه النتائج نفسها فالمطابقة تقع دائماً،
        // والاحتياطيّ حارسٌ لا مسار.
        final Map<String, dynamic> match = results
            .whereType<Map<String, dynamic>>()
            .firstWhere(
              (Map<String, dynamic> r) => r['version'] == storeVersion,
              orElse: () => const <String, dynamic>{},
            );

        pendingMandatory = isMandatory;
        pendingInfo = match.isEmpty
            ? null
            : AppReleaseInfo.fromItunes(match, isMandatory: isMandatory);
      }
    } on Object catch (e, s) {
      // `on Object` لا `on Exception`: التحويلات هنا (json.decode والـcast)
      // ترمي TypeError وهو Error لا Exception. وأثر المكدّس يُسجَّل داخلياً
      // فيلتقطه Sentry، ويبقى `onError` على وسيطه الواحد كما يستهلكه
      // المستدعون — لا توسيع للتوقيع من أجل وسيطٍ لا يقرؤه أحد.
      log(
        'Error checking for update - iOS: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
      onError?.call(e);
      return;
    }

    if (pendingMandatory != null) {
      onUpdateAvailable(pendingMandatory, pendingInfo);
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
    } on Object catch (e, s) {
      log(
        'fetchReleaseInfo failed: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
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
    } on Object catch (e, s) {
      // `on Object` لا `on Exception`: تفكيك الإصدار قد يرمي Error لا
      // Exception (RangeError مثلاً)، و`on Exception` يتركه يهرب إلى الـzone
      // فيُسقط الفحص كلّه بدل أن يُرجع «لا تحديث».
      log(
        'Error comparing versions: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// مقارنة أرقام الإصدار خانةً خانةً — هل في المتجر أحدث من المحلّي؟
  bool _compareVersions(String local, String store) {
    // نمرّ على كلّ الخانات لا ثلاثاً: App Store يقبل أربع خانات في
    // CFBundleShortVersionString، فالوقوف عند الثالثة يُعمي إصدار إصلاحٍ
    // عاجل مثل 10.8.6.1 ← 10.8.6.2 فلا يُكتشف التحديث أبداً.
    final List<String> localParts = _versionSegments(local);
    final List<String> storeParts = _versionSegments(store);
    final int length = localParts.length > storeParts.length
        ? localParts.length
        : storeParts.length;

    for (int i = 0; i < length; i++) {
      final BigInt localPart =
          i < localParts.length ? _segmentValue(localParts[i]) : BigInt.zero;
      final BigInt storePart =
          i < storeParts.length ? _segmentValue(storeParts[i]) : BigInt.zero;

      if (storePart != localPart) return storePart > localPart;
    }

    return false;
  }

  /// تحديد إجباريّة التحديث (iOS): إجباريّ إذا تغيّرت الخانة الكبرى أو الوسطى
  /// (major/minor)، واختياريّ إذا كان التغيير في الخانة الصغرى (patch) فقط.
  @visibleForTesting
  bool isMandatoryUpdate(String local, String store) {
    final List<BigInt> l = _versionParts(local);
    final List<BigInt> s = _versionParts(store);
    if (s[0] != l[0]) return s[0] > l[0]; // major
    if (s[1] != l[1]) return s[1] > l[1]; // minor
    return false; // patch only → اختياريّ
  }

  /// خانات الإصدار نصّاً بلا لاحقة البناء (+N أو -x) — مصدرٌ واحد للتفكيك
  /// تشترك فيه المقارنة وتحديد الإجباريّة فلا يختلفان.
  List<String> _versionSegments(String version) =>
      version.trim().split('+').first.split('-').first.split('.');

  /// قيمة خانةٍ واحدة عدداً، والخانة غير المفهومة صفر.
  ///
  /// `BigInt` لا `int`: خانةٌ تتجاوز سعة الـ64 بت (وسمٌ زمنيّ أو رقم بناءٍ
  /// طويل وُضع في خانة الإصدار) تُرجع `null` من `int.tryParse` فتُقرأ صفراً،
  /// فينقلب الحكم ويصير الإصدار الأحدث أقدمَ من المحلّيّ فلا يُكتشف التحديث.
  /// و`BigInt.tryParse` يقرأ أيّ طولٍ من الأرقام بلا فيضان، ويطابق
  /// `int.tryParse` في ردّ ما ليس رقماً (`abc`, `٢`, النصّ الفارغ) إلى `null`.
  BigInt _segmentValue(String raw) =>
      BigInt.tryParse(raw.trim()) ?? BigInt.zero;

  /// تفكيك الإصدار إلى [major, minor, patch] متجاهلاً لاحقة البناء (+N أو -x).
  List<BigInt> _versionParts(String version) {
    final List<String> parts = _versionSegments(version);
    return <BigInt>[
      parts.isNotEmpty ? _segmentValue(parts[0]) : BigInt.zero,
      parts.length > 1 ? _segmentValue(parts[1]) : BigInt.zero,
      parts.length > 2 ? _segmentValue(parts[2]) : BigInt.zero,
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
  ///
  /// يُرجع `false` بدل أن يرمي: النداء يعبر قناة المنصّة، فيرمي
  /// PlatformException عند فشل Play (مثل REQUIRE_CHECK_FOR_UPDATE إن لم
  /// يسبقه فحص)، وMissingPluginException على iOS حيث لا وجود للإضافة أصلاً.
  Future<bool> performImmediateUpdate({
    void Function(Object error)? onError,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result == AppUpdateResult.success;
    } on Object catch (e, s) {
      log(
        'performImmediateUpdate failed: $e',
        name: 'AppUpdateChecker',
        error: e,
        stackTrace: s,
      );
      onError?.call(e);
      return false;
    }
  }
}
