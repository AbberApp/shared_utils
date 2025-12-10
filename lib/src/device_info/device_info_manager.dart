import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models/device_info_model.dart';

/// مدير معلومات الجهاز
///
/// يتم تهيئته مرة واحدة في main ويمكن الوصول للمعلومات طوال دورة حياة التطبيق.
///
/// ## الاستخدام:
///
/// ### الطريقة 1: التهيئة مع الانتظار (موصى بها)
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await DeviceInfoManager.instance.initialize();
///   runApp(MyApp());
/// }
/// ```
///
/// ### الطريقة 2: التهيئة في الخلفية (بدون انتظار)
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   DeviceInfoManager.instance.initialize(); // بدون await
///   runApp(MyApp());
/// }
///
/// // ثم في أي مكان تحتاج المعلومات:
/// final info = await DeviceInfoManager.instance.ensureInitialized();
/// ```
///
/// ### الوصول للمعلومات:
/// ```dart
/// final deviceInfo = DeviceInfoManager.instance.info;
/// print(deviceInfo.device.model);
/// print(deviceInfo.toJson());
/// ```
class DeviceInfoManager {
  DeviceInfoManager._();

  static final DeviceInfoManager _instance = DeviceInfoManager._();

  /// الحصول على instance الوحيد
  static DeviceInfoManager get instance => _instance;

  DeviceInfoModel? _deviceInfo;
  bool _isInitialized = false;
  Future<DeviceInfoModel>? _initializeFuture;

  /// التحقق من التهيئة
  bool get isInitialized => _isInitialized;

  /// الحصول على معلومات الجهاز
  /// يُلقي Exception إذا لم يتم التهيئة
  DeviceInfoModel get info {
    if (!_isInitialized || _deviceInfo == null) {
      throw StateError(
        'DeviceInfoManager لم يتم تهيئته. '
        'استدعِ DeviceInfoManager.instance.initialize() في main أولاً.',
      );
    }
    return _deviceInfo!;
  }

  /// الحصول على معلومات الجهاز (nullable)
  DeviceInfoModel? get infoOrNull => _deviceInfo;

  /// تهيئة المدير وجمع المعلومات
  ///
  /// يمكن استدعاؤها مع await أو بدونها:
  /// - مع await: ينتظر حتى تكتمل التهيئة
  /// - بدون await: تبدأ التهيئة في الخلفية
  ///
  /// [extraInfo] - معلومات إضافية مخصصة
  /// [screenSize] - حجم الشاشة (اختياري، يمكن تحديثه لاحقاً)
  Future<DeviceInfoModel> initialize({
    Map<String, dynamic>? extraInfo,
    Size? screenSize,
  }) {
    // إذا تمت التهيئة، أرجع النتيجة مباشرة
    if (_isInitialized && _deviceInfo != null) {
      return Future.value(_deviceInfo!);
    }

    // إذا التهيئة جارية، أرجع نفس الـ Future
    if (_initializeFuture != null) {
      return _initializeFuture!;
    }

    // بدء التهيئة
    _initializeFuture = _doInitialize(extraInfo: extraInfo, screenSize: screenSize);
    return _initializeFuture!;
  }

  /// انتظار اكتمال التهيئة
  ///
  /// مفيدة عند استدعاء initialize() بدون await في main
  /// ثم تحتاج الانتظار لاحقاً
  Future<DeviceInfoModel> ensureInitialized() {
    if (_isInitialized && _deviceInfo != null) {
      return Future.value(_deviceInfo!);
    }
    if (_initializeFuture != null) {
      return _initializeFuture!;
    }
    return initialize();
  }

  Future<DeviceInfoModel> _doInitialize({
    Map<String, dynamic>? extraInfo,
    Size? screenSize,
  }) async {
    try {
      final results = await Future.wait([
        _getAppInfo(),
        _getDeviceDetails(),
        _getSystemInfo(),
      ]);

      _deviceInfo = DeviceInfoModel(
        app: results[0] as AppInfo,
        device: results[1] as DeviceDetails,
        system: results[2] as SystemInfo,
        screen: _getScreenInfo(screenSize),
        extra: extraInfo ?? {},
        collectedAt: DateTime.now(),
      );

      _isInitialized = true;
      return _deviceInfo!;
    } catch (e) {
      _initializeFuture = null; // السماح بإعادة المحاولة
      debugPrint('خطأ في تهيئة DeviceInfoManager: $e');
      rethrow;
    }
  }

  /// تحديث معلومات الشاشة (مفيد بعد تغيير الاتجاه)
  void updateScreenInfo(Size screenSize, double textScaleFactor) {
    if (_deviceInfo == null) return;

    final window = PlatformDispatcher.instance.views.first;
    _deviceInfo = DeviceInfoModel(
      app: _deviceInfo!.app,
      device: _deviceInfo!.device,
      system: _deviceInfo!.system,
      screen: ScreenInfo(
        width: screenSize.width,
        height: screenSize.height,
        pixelRatio: window.devicePixelRatio,
        textScaleFactor: textScaleFactor,
      ),
      extra: _deviceInfo!.extra,
      collectedAt: _deviceInfo!.collectedAt,
    );
  }

  /// إضافة معلومات إضافية
  void addExtraInfo(String key, dynamic value) {
    if (_deviceInfo == null) return;

    final newExtra = Map<String, dynamic>.from(_deviceInfo!.extra);
    newExtra[key] = value;

    _deviceInfo = DeviceInfoModel(
      app: _deviceInfo!.app,
      device: _deviceInfo!.device,
      system: _deviceInfo!.system,
      screen: _deviceInfo!.screen,
      extra: newExtra,
      collectedAt: _deviceInfo!.collectedAt,
    );
  }

  /// إعادة تعيين (للاختبار)
  @visibleForTesting
  void reset() {
    _deviceInfo = null;
    _isInitialized = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private Methods
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AppInfo> _getAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    return AppInfo(
      name: packageInfo.appName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      packageName: packageInfo.packageName,
    );
  }

  Future<DeviceDetails> _getDeviceDetails() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfoPlugin.webBrowserInfo;
      return DeviceDetails(
        id: '${webInfo.vendor ?? 'unknown'}_${webInfo.userAgent?.hashCode ?? 0}',
        brand: webInfo.vendor ?? 'Unknown',
        model: webInfo.browserName.name,
        name: webInfo.appName ?? 'Web Browser',
        type: 'web',
        isPhysicalDevice: true,
      );
    }

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return DeviceDetails(
        id: androidInfo.id,
        brand: androidInfo.brand,
        model: androidInfo.model,
        name: androidInfo.device,
        type: _getAndroidDeviceType(androidInfo),
        isPhysicalDevice: androidInfo.isPhysicalDevice,
        androidId: androidInfo.id,
        sdkInt: androidInfo.version.sdkInt,
      );
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return DeviceDetails(
        id: iosInfo.identifierForVendor ?? 'unknown',
        brand: 'Apple',
        model: iosInfo.model,
        name: iosInfo.name,
        type: _getIOSDeviceType(iosInfo),
        isPhysicalDevice: iosInfo.isPhysicalDevice,
        iosIdentifierForVendor: iosInfo.identifierForVendor,
        systemVersion: iosInfo.systemVersion,
      );
    }

    if (Platform.isMacOS) {
      final macInfo = await deviceInfoPlugin.macOsInfo;
      return DeviceDetails(
        id: macInfo.systemGUID ?? 'unknown',
        brand: 'Apple',
        model: macInfo.model,
        name: macInfo.computerName,
        type: 'desktop',
        isPhysicalDevice: true,
      );
    }

    if (Platform.isWindows) {
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      return DeviceDetails(
        id: windowsInfo.deviceId,
        brand: 'Microsoft',
        model: windowsInfo.productName,
        name: windowsInfo.computerName,
        type: 'desktop',
        isPhysicalDevice: true,
      );
    }

    if (Platform.isLinux) {
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      return DeviceDetails(
        id: linuxInfo.machineId ?? 'unknown',
        brand: linuxInfo.name,
        model: linuxInfo.prettyName,
        name: linuxInfo.name,
        type: 'desktop',
        isPhysicalDevice: true,
      );
    }

    return const DeviceDetails(
      id: 'unknown',
      brand: 'Unknown',
      model: 'Unknown',
      name: 'Unknown',
      type: 'unknown',
      isPhysicalDevice: true,
    );
  }

  Future<SystemInfo> _getSystemInfo() async {
    final locale = PlatformDispatcher.instance.locale;

    if (kIsWeb) {
      return SystemInfo(
        osName: 'Web',
        osVersion: 'N/A',
        platform: 'web',
        locale: locale.toString(),
        timezone: DateTime.now().timeZoneName,
      );
    }

    String osName = Platform.operatingSystem;
    String osVersion = Platform.operatingSystemVersion;
    String platform = Platform.operatingSystem.toLowerCase();

    // تنظيف اسم النظام
    if (Platform.isAndroid) {
      osName = 'Android';
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      osVersion = 'Android ${deviceInfo.version.release} (SDK ${deviceInfo.version.sdkInt})';
    } else if (Platform.isIOS) {
      osName = 'iOS';
      final deviceInfo = await DeviceInfoPlugin().iosInfo;
      osVersion = 'iOS ${deviceInfo.systemVersion}';
    } else if (Platform.isMacOS) {
      osName = 'macOS';
    } else if (Platform.isWindows) {
      osName = 'Windows';
    } else if (Platform.isLinux) {
      osName = 'Linux';
    }

    return SystemInfo(
      osName: osName,
      osVersion: osVersion,
      platform: platform,
      locale: locale.toString(),
      timezone: DateTime.now().timeZoneName,
      kernelVersion: !kIsWeb ? Platform.version : null,
    );
  }

  ScreenInfo _getScreenInfo(Size? screenSize) {
    final window = PlatformDispatcher.instance.views.first;
    final size = screenSize ?? (window.physicalSize / window.devicePixelRatio);

    return ScreenInfo(
      width: size.width,
      height: size.height,
      pixelRatio: window.devicePixelRatio,
      textScaleFactor: window.platformDispatcher.textScaleFactor,
    );
  }

  String _getAndroidDeviceType(AndroidDeviceInfo info) {
    // تحديد نوع الجهاز بناءً على خصائص الشاشة
    // نستخدم حجم الشاشة من PlatformDispatcher
    final window = PlatformDispatcher.instance.views.first;
    final screenWidth = window.physicalSize.width / window.devicePixelRatio;
    if (screenWidth >= 600) return 'tablet';
    return 'phone';
  }

  String _getIOSDeviceType(IosDeviceInfo info) {
    final model = info.model.toLowerCase();
    if (model.contains('ipad')) return 'tablet';
    if (model.contains('ipod')) return 'ipod';
    return 'phone';
  }
}
