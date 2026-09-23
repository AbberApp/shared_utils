/// نموذج يحتوي على جميع معلومات الجهاز والتطبيق
///
/// **بادئة `Shared` مقصودة**: هذا الصنف — ومعه [SharedAppInfo]
/// و[SharedDeviceDetails] و[SharedSystemInfo] و[SharedScreenInfo] — يُصدَّر من
/// `shared_utils.dart` بلا نطاق، فيدخل مجال أسماء كلّ ملفّ يستورد المكتبة.
/// وكان اسمه `DeviceInfoModel` فاصطدم بصنفٍ يحمل الاسم نفسه في أحد تطبيقات
/// المجموعة فحجبه محلّياً بلا خطأ ترجمة. البادئة تمنع تكرار ذلك: لا تُسقَط،
/// ولا يُعاد الاسم القديم ولو عبر `typedef`.
class SharedDeviceInfo {
  // معلومات التطبيق
  final SharedAppInfo app;

  // معلومات الجهاز
  final SharedDeviceDetails device;

  // معلومات النظام
  final SharedSystemInfo system;

  // معلومات الشاشة
  final SharedScreenInfo screen;

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

  const SharedDeviceInfo({
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
      'extra': extra.map((k, v) => MapEntry(k, _jsonSafeExtra(v))),
      'collected_at': collectedAt.toIso8601String(),
    };
  }

  /// أقصى عمق نغوص إليه داخل قيم `extra`
  static const int _extraMaxDepth = 8;

  /// يُطبّع قيمة من `extra` إلى ما يقبله `jsonEncode`.
  ///
  /// `addExtraInfo(String key, dynamic value)` لا يتحقّق من النوع، فقد يصل
  /// إلى هنا `DateTime` أو `enum` أو نموذج مخصّص — وحينها يرمي `jsonEncode`
  /// في طبقة الشبكة أو في Sentry، بعيداً عن موضع الإضافة، فيسقط الطلب كلّه
  /// من أجل حقلٍ وصفيّ. نحوّل ما لا يُسلسَل إلى نصّ بدل إسقاط الطلب.
  static dynamic _jsonSafeExtra(dynamic value, [int depth = 0]) {
    if (value == null || value is String || value is bool) return value;
    // NaN و∞ يرميهما `jsonEncode` أيضاً رغم أنّهما num
    if (value is num) return value.isFinite ? value : value.toString();
    // حدّ العمق يحمي من مرجعٍ دائريّ: تجاوز المكدّس في Dart لا يُلتقط ويُسقط
    // التطبيق، بخلاف استثناء `jsonEncode`
    if (depth >= _extraMaxDepth) return value.toString();
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _jsonSafeExtra(v, depth + 1)),
      );
    }
    if (value is Iterable) {
      return value.map((v) => _jsonSafeExtra(v, depth + 1)).toList();
    }
    return value.toString();
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
    return 'SharedDeviceInfo(app: $app, device: $device, system: $system, screen: $screen)';
  }
}

/// معلومات التطبيق
class SharedAppInfo {
  final String name;
  final String version;
  final String buildNumber;
  final String packageName;

  const SharedAppInfo({
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
  String toString() => 'SharedAppInfo(name: $name, version: $fullVersion)';
}

/// تفاصيل الجهاز
class SharedDeviceDetails {
  final String id;
  final String brand;
  final String model;
  final String name;
  final String type; // phone, tablet, desktop, web
  final bool isPhysicalDevice;

  // معلومات إضافية حسب النظام

  /// رقم بناء نظام Android (`Build.ID`) — **ليس معرّف جهاز**
  ///
  /// قيمة تُوصَف البناء لا الجهاز، فتتكرّر على ملايين الأجهزة التي تعمل
  /// بالبناء نفسه. لتمييز جهازٍ بعينه استعمل [id] (المعرّف الثابت).
  final String? buildId;
  final String? iosIdentifierForVendor;
  final int? sdkInt; // Android SDK version
  final String? systemVersion; // iOS version

  const SharedDeviceDetails({
    required this.id,
    required this.brand,
    required this.model,
    required this.name,
    required this.type,
    required this.isPhysicalDevice,
    this.buildId,
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
      if (buildId != null) 'build_id': buildId,
      if (iosIdentifierForVendor != null) 'ios_identifier': iosIdentifierForVendor,
      if (sdkInt != null) 'sdk_int': sdkInt,
      if (systemVersion != null) 'system_version': systemVersion,
    };
  }

  @override
  String toString() => 'SharedDeviceDetails(brand: $brand, model: $model, type: $type)';
}

/// معلومات النظام
class SharedSystemInfo {
  final String osName; // Android, iOS, Windows, macOS, Linux
  final String osVersion;
  final String platform; // android, ios, web, windows, macos, linux
  final String locale;
  final String timezone;
  final String? kernelVersion;

  const SharedSystemInfo({
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
  String toString() => 'SharedSystemInfo(os: $osName $osVersion, platform: $platform)';
}

/// معلومات الشاشة
class SharedScreenInfo {
  final double width;
  final double height;
  final double pixelRatio;
  final double textScaleFactor;

  const SharedScreenInfo({
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.textScaleFactor,
  });

  /// الدقة الفعلية بالبكسل
  double get physicalWidth => width * pixelRatio;
  double get physicalHeight => height * pixelRatio;

  /// نسبة العرض إلى الارتفاع
  ///
  /// الارتفاع يساوي صفراً قبل أوّل إطار، و`0/0` يُنتج NaN — وNaN يرمي
  /// `JsonUnsupportedObjectError` عند `jsonEncode` وقت إرسال معلومات الجهاز.
  double get aspectRatio => height == 0 ? 0 : width / height;

  /// يمنع NaN و∞ من الوصول إلى JSON.
  static double _jsonSafe(double v) => v.isFinite ? v : 0;

  /// تحديد نوع الشاشة
  String get screenType {
    if (width < 600) return 'mobile';
    if (width < 1200) return 'tablet';
    return 'desktop';
  }

  Map<String, dynamic> toJson() {
    return {
      'width': _jsonSafe(width),
      'height': _jsonSafe(height),
      'pixel_ratio': _jsonSafe(pixelRatio),
      'text_scale_factor': _jsonSafe(textScaleFactor),
      'physical_width': _jsonSafe(physicalWidth),
      'physical_height': _jsonSafe(physicalHeight),
      'aspect_ratio': _jsonSafe(aspectRatio),
      'screen_type': screenType,
    };
  }

  @override
  String toString() => 'SharedScreenInfo(${width}x$height, ratio: $pixelRatio, type: $screenType)';
}
