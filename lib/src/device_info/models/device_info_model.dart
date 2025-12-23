/// نموذج يحتوي على جميع معلومات الجهاز والتطبيق
class DeviceInfoModel {
  // معلومات التطبيق
  final AppInfo app;

  // معلومات الجهاز
  final DeviceDetails device;

  // معلومات النظام
  final SystemInfo system;

  // معلومات الشاشة
  final ScreenInfo screen;

  // معلومات إضافية
  final Map<String, dynamic> extra;

  // وقت جمع المعلومات
  final DateTime collectedAt;

  /// معرف الجهاز الثابت الذي يبقى حتى بعد حذف التطبيق
  ///
  /// - على Android: يستخدم MediaDrm (يبقى حتى بعد Factory Reset غالباً)
  /// - على iOS: يستخدم Keychain (يبقى بعد حذف التطبيق)
  ///
  /// **ملاحظة**: مضمون أن يُرجع قيمة على Android و iOS
  /// المكتبة تستخدم UUID كـ fallback إذا فشل MediaDrm أو Keychain
  final String persistentId;

  const DeviceInfoModel({
    required this.app,
    required this.device,
    required this.system,
    required this.screen,
    this.extra = const {},
    required this.collectedAt,
    required this.persistentId,
  });

  /// تحويل إلى Map لإرسالها للسيرفر
  Map<String, dynamic> toJson() {
    return {
      'persistent_id': persistentId,
      'app': app.toJson(),
      'device': device.toJson(),
      'system': system.toJson(),
      'screen': screen.toJson(),
      'extra': extra,
      'collected_at': collectedAt.toIso8601String(),
    };
  }

  /// تحويل إلى Map مسطح (مفيد للـ headers أو analytics)
  Map<String, String> toFlatMap() {
    return {
      // Persistent ID
      'persistent_id': persistentId,

      // App
      // 'app_name': app.name, // قد يحتوي على مسافات أو أحرف خاصة
      'app_version': app.version,
      'app_build': app.buildNumber,
      'app_full_version': app.fullVersion,
      'app_package': app.packageName,

      // Device
      'device_id': device.id,
      'device_brand': device.brand,
      'device_model': device.model,
      'device_name': device.name,
      'device_type': device.type,
      'device_is_physical': device.isPhysicalDevice.toString(),

      // System
      'os_name': system.osName,
      'os_version': system.osVersion,
      'platform': system.platform,
      'locale': system.locale,
      'timezone': system.timezone,

      // Screen
      'screen_width': screen.width.toString(),
      'screen_height': screen.height.toString(),
      'screen_pixel_ratio': screen.pixelRatio.toString(),
    };
  }

  @override
  String toString() {
    return 'DeviceInfoModel(app: $app, device: $device, system: $system, screen: $screen)';
  }
}

/// معلومات التطبيق
class AppInfo {
  final String name;
  final String version;
  final String buildNumber;
  final String packageName;

  const AppInfo({
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.packageName,
  });

  /// الإصدار الكامل (version + build)
  String get fullVersion => '$version+$buildNumber';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'build_number': buildNumber,
      'package_name': packageName,
      'full_version': fullVersion,
    };
  }

  @override
  String toString() => 'AppInfo(name: $name, version: $fullVersion)';
}

/// تفاصيل الجهاز
class DeviceDetails {
  final String id;
  final String brand;
  final String model;
  final String name;
  final String type; // phone, tablet, desktop, web
  final bool isPhysicalDevice;

  // معلومات إضافية حسب النظام
  final String? androidId;
  final String? iosIdentifierForVendor;
  final int? sdkInt; // Android SDK version
  final String? systemVersion; // iOS version

  const DeviceDetails({
    required this.id,
    required this.brand,
    required this.model,
    required this.name,
    required this.type,
    required this.isPhysicalDevice,
    this.androidId,
    this.iosIdentifierForVendor,
    this.sdkInt,
    this.systemVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'name': name,
      'type': type,
      'is_physical_device': isPhysicalDevice,
      if (androidId != null) 'android_id': androidId,
      if (iosIdentifierForVendor != null) 'ios_identifier': iosIdentifierForVendor,
      if (sdkInt != null) 'sdk_int': sdkInt,
      if (systemVersion != null) 'system_version': systemVersion,
    };
  }

  @override
  String toString() => 'DeviceDetails(brand: $brand, model: $model, type: $type)';
}

/// معلومات النظام
class SystemInfo {
  final String osName; // Android, iOS, Windows, macOS, Linux
  final String osVersion;
  final String platform; // android, ios, web, windows, macos, linux
  final String locale;
  final String timezone;
  final String? kernelVersion;

  const SystemInfo({
    required this.osName,
    required this.osVersion,
    required this.platform,
    required this.locale,
    required this.timezone,
    this.kernelVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'os_name': osName,
      'os_version': osVersion,
      'platform': platform,
      'locale': locale,
      'timezone': timezone,
      if (kernelVersion != null) 'kernel_version': kernelVersion,
    };
  }

  @override
  String toString() => 'SystemInfo(os: $osName $osVersion, platform: $platform)';
}

/// معلومات الشاشة
class ScreenInfo {
  final double width;
  final double height;
  final double pixelRatio;
  final double textScaleFactor;

  const ScreenInfo({
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.textScaleFactor,
  });

  /// الدقة الفعلية بالبكسل
  double get physicalWidth => width * pixelRatio;
  double get physicalHeight => height * pixelRatio;

  /// نسبة العرض إلى الارتفاع
  double get aspectRatio => width / height;

  /// تحديد نوع الشاشة
  String get screenType {
    if (width < 600) return 'mobile';
    if (width < 1200) return 'tablet';
    return 'desktop';
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'pixel_ratio': pixelRatio,
      'text_scale_factor': textScaleFactor,
      'physical_width': physicalWidth,
      'physical_height': physicalHeight,
      'aspect_ratio': aspectRatio,
      'screen_type': screenType,
    };
  }

  @override
  String toString() => 'ScreenInfo(${width}x$height, ratio: $pixelRatio, type: $screenType)';
}
