import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:persistent_device_id/persistent_device_id.dart';

import 'models/device_info_model.dart';

/// مدير معلومات الجهاز
///
/// يتم تهيئته مرة واحدة في main ويمكن الوصول للمعلومات طوال دورة حياة التطبيق.
///
/// **المنصّات المدعومة**: Android و iOS و macOS و Windows و Linux.
/// الويب غير مدعوم: الملف يستورد `dart:io` مباشرة فيفشل بناء الويب وقت
/// الترجمة، ولا فائدة من فروعٍ خاصة بالمتصفّح لا تُترجَم أصلاً.
///
/// **لا يرمي عند فشل جمع المعلومات**: فشل أي قناة منصّة يُنتج قيمة ناقصة
/// (`unknown`) مع رفع [isDegraded]. السبب أن معلومات الجهاز بيانات مساعدة لا
/// يجوز أن تُسقط الإقلاع، وأن الطريقة 2 أدناه تستدعي التهيئة بلا await فلا
/// يوجد من يلتقط ما يُرمى.
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

  SharedDeviceInfo? _deviceInfo;
  bool _isInitialized = false;
  bool _isDegraded = false;
  bool _frameRefreshScheduled = false;
  Future<SharedDeviceInfo>? _initializeFuture;

  /// التحقق من التهيئة
  bool get isInitialized => _isInitialized;

  /// هل النتيجة ناقصة؟
  ///
  /// `true` إذا فشلت قناة منصّة أثناء الجمع، فبعض الحقول قيمتها `unknown`.
  /// نداء [initialize] مرّة أخرى يُعيد المحاولة في هذه الحالة.
  bool get isDegraded => _isDegraded;

  /// الحصول على معلومات الجهاز
  /// يُلقي Exception إذا لم يتم التهيئة
  SharedDeviceInfo get info {
    if (!_isInitialized || _deviceInfo == null) {
      throw StateError(
        'DeviceInfoManager لم يتم تهيئته. '
        'استدعِ DeviceInfoManager.instance.initialize() في main أولاً.',
      );
    }
    return _deviceInfo!;
  }

  /// الحصول على معلومات الجهاز (nullable)
  SharedDeviceInfo? get infoOrNull => _deviceInfo;

  /// تهيئة المدير وجمع المعلومات
  ///
  /// يمكن استدعاؤها مع await أو بدونها:
  /// - مع await: ينتظر حتى تكتمل التهيئة
  /// - بدون await: تبدأ التهيئة في الخلفية
  ///
  /// [extraInfo] - معلومات إضافية مخصصة
  /// [screenSize] - حجم الشاشة (اختياري، يمكن تحديثه لاحقاً)
  Future<SharedDeviceInfo> initialize({
    Map<String, dynamic>? extraInfo,
    Size? screenSize,
  }) {
    // إذا تمت التهيئة، أرجع النتيجة مباشرة
    // أما النتيجة الناقصة فنسمح بإعادة جمعها عند نداءٍ جديد صريح
    if (_isInitialized && _deviceInfo != null && !_isDegraded) {
      // الوسائط لا تُهمَل لمجرّد سبق غيرُنا إلى التهيئة: SentryBootstrap يُهيّئ
      // المدير بلا وسائط داخل optionsConfiguration — أي قبل runApp — فلو ارتدّ
      // نداء التطبيق من هنا صامتاً لضاعت extraInfo وscreenSize إلى الأبد.
      _applyInitArgs(extraInfo: extraInfo, screenSize: screenSize);
      return Future.value(_deviceInfo!);
    }

    // إذا التهيئة جارية، أرجع نفس الـ Future
    if (_initializeFuture != null) {
      // وللسبب نفسه: نداءٌ بوسائط يلحق تهيئةً جارية بلا وسائط يجب أن تُطبَّق
      // وسائطه بعد اكتمالها لا أن تُطرح. وبلا وسائط نُعيد الـ Future ذاته.
      if (extraInfo == null && screenSize == null) return _initializeFuture!;
      return _initializeFuture!.then((model) {
        _applyInitArgs(extraInfo: extraInfo, screenSize: screenSize);
        return _deviceInfo ?? model;
      });
    }

    // بدء التهيئة
    _initializeFuture = _doInitialize(extraInfo: extraInfo, screenSize: screenSize);
    return _initializeFuture!;
  }

  /// انتظار اكتمال التهيئة
  ///
  /// مفيدة عند استدعاء initialize() بدون await في main
  /// ثم تحتاج الانتظار لاحقاً
  Future<SharedDeviceInfo> ensureInitialized() {
    if (_isInitialized && _deviceInfo != null) {
      return Future.value(_deviceInfo!);
    }
    if (_initializeFuture != null) {
      return _initializeFuture!;
    }
    return initialize();
  }

  Future<SharedDeviceInfo> _doInitialize({
    Map<String, dynamic>? extraInfo,
    Size? screenSize,
  }) async {
    _isDegraded = false;

    try {
      // الحصول على المعرف الثابت أولاً (Android/iOS فقط)
      final persistentId = await _getPersistentId();

      // بيانات القناة تُجلب مرّة واحدة وتُمرَّر: الذاكرة المؤقتة في
      // DeviceInfoPlugin مرتبطة بالكائن لا بالصنف، وإنشاء كائنٍ ثانٍ في
      // _getSystemInfo كان يكرّر الرحلة عبر القناة في مسار الإقلاع.
      final androidInfo = await _getAndroidInfo();
      final iosInfo = await _getIosInfo();

      final results = await Future.wait([
        _getAppInfo(),
        _getDeviceDetails(
          persistentId: persistentId,
          androidInfo: androidInfo,
          iosInfo: iosInfo,
        ),
      ]);

      _deviceInfo = SharedDeviceInfo(
        persistentId: persistentId,
        app: results[0] as SharedAppInfo,
        device: results[1] as SharedDeviceDetails,
        system: _getSystemInfo(androidInfo: androidInfo, iosInfo: iosInfo),
        screen: _getScreenInfo(screenSize),
        extra: extraInfo ?? {},
        collectedAt: DateTime.now(),
      );

      _isInitialized = true;
      // مسار النجاح هذا يُبلَغ أيضاً حين تفشل قناةٌ واحدة وتُمسك داخلياً
      // (_markDegraded يرفع العلم بلا استثناء)، فلا تمرّ كتلة catch — وهي
      // الموضع الوحيد الذي كان يصفّر الـ Future. وببقائه مُسنَداً يستحيل ما
      // يعد به التوثيق: الحارس الأوّل يُخطّى للتدهور، والثاني يُعيد الـ Future
      // المكتمل بالنتيجة الناقصة نفسها، فلا يُعاد الجمع أبداً.
      if (_isDegraded) _initializeFuture = null;
      _scheduleFirstFrameRefresh();
      return _deviceInfo!;
    } on Object catch (e) {
      // لا rethrow هنا: التوثيق يوصي بنداء initialize() بلا await، فالرمي
      // يتحوّل إلى رفض Future بلا مستمع يصل إلى zone الأخطاء عند كل إقلاع.
      // نُكمل بنموذجٍ ناقص كي لا يرمي getter info لاحقاً، ونسمح بإعادة
      // المحاولة عبر تصفير _initializeFuture ورفع _isDegraded.
      _initializeFuture = null; // السماح بإعادة المحاولة
      debugPrint('خطأ في تهيئة DeviceInfoManager: $e');

      _deviceInfo = _degradedInfo(extraInfo: extraInfo, screenSize: screenSize);
      _isDegraded = true;
      _isInitialized = true;
      // النموذج الناقص يحمل شاشة 0×0 ونوعاً مجهولاً، وهما قابلان للقياس بعد
      // أوّل إطار كما في المسار الناجح — فلا سبب لتجميدهما هنا وحدهما.
      _scheduleFirstFrameRefresh();
      return _deviceInfo!;
    }
  }

  /// تحديث معلومات الشاشة (مفيد بعد تغيير الاتجاه)
  void updateScreenInfo(Size screenSize, double textScaleFactor) {
    final info = _deviceInfo;
    if (info == null) return;

    // لا نافذة في isolate خلفي: نُبقي النسبة السابقة بدل رمي StateError
    final view = _currentView;
    final pixelRatio = view == null
        ? info.screen.pixelRatio
        : _safePixelRatio(view.devicePixelRatio);

    _deviceInfo = SharedDeviceInfo(
      persistentId: info.persistentId,
      app: info.app,
      device: info.device,
      system: info.system,
      screen: SharedScreenInfo(
        width: screenSize.width,
        height: screenSize.height,
        pixelRatio: pixelRatio,
        textScaleFactor: textScaleFactor,
      ),
      extra: info.extra,
      collectedAt: info.collectedAt,
    );
  }

  /// إضافة معلومات إضافية
  void addExtraInfo(String key, dynamic value) {
    if (_deviceInfo == null) return;

    final newExtra = Map<String, dynamic>.from(_deviceInfo!.extra);
    newExtra[key] = value;

    _deviceInfo = SharedDeviceInfo(
      persistentId: _deviceInfo!.persistentId,
      app: _deviceInfo!.app,
      device: _deviceInfo!.device,
      system: _deviceInfo!.system,
      screen: _deviceInfo!.screen,
      extra: newExtra,
      collectedAt: _deviceInfo!.collectedAt,
    );
  }

  /// تطبيق وسائط [initialize] على نموذجٍ مُهيّأ سلفاً
  ///
  /// دمجٌ لا استبدال: قد يكون طرفٌ آخر أضاف مفاتيح إلى `extra` قبلنا.
  void _applyInitArgs({Map<String, dynamic>? extraInfo, Size? screenSize}) {
    final info = _deviceInfo;
    if (info == null) return;

    if (extraInfo != null && extraInfo.isNotEmpty) {
      _deviceInfo = SharedDeviceInfo(
        persistentId: info.persistentId,
        app: info.app,
        device: info.device,
        system: info.system,
        screen: info.screen,
        extra: {...info.extra, ...extraInfo},
        collectedAt: info.collectedAt,
      );
    }

    // updateScreenInfo تُعيد قراءة pixelRatio من النافذة وتحفظ باقي الحقول
    if (screenSize != null) {
      updateScreenInfo(screenSize, _deviceInfo!.screen.textScaleFactor);
    }
  }

  /// إعادة تعيين (للاختبار)
  @visibleForTesting
  void reset() {
    _deviceInfo = null;
    _isInitialized = false;
    _isDegraded = false;
    _frameRefreshScheduled = false;
    // بدون تصفير الـ Future تبقى التهيئة السابقة محفوظة، فيُرجعها أوّل نداء
    // لـ initialize() بعد reset() ولا تُجمع المعلومات من جديد أبداً
    _initializeFuture = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private Methods
  // ═══════════════════════════════════════════════════════════════════════════

  Future<SharedAppInfo> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      return SharedAppInfo(
        name: packageInfo.appName,
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        packageName: packageInfo.packageName,
      );
    } on Object catch (e) {
      _markDegraded('تعذّر جلب معلومات التطبيق: $e');
      return const SharedAppInfo(
        name: 'unknown',
        version: '0.0.0',
        buildNumber: '0',
        packageName: 'unknown',
      );
    }
  }

  /// الحصول على المعرف الثابت الذي يبقى بعد حذف التطبيق
  /// يستخدم MediaDrm على Android و Keychain على iOS
  ///
  /// **ملاحظة**: الحزمة تسجّل Android و iOS فقط — لا تنفيذ لسطح المكتب —
  /// وتوقيعها `Future<String?>` لأن التنفيذ الأصلي قد يعجز عن إنتاج معرّف.
  /// لذلك نحرس المنصّة ونلتقط الاستثناء ونُميّز null بدل تمريرها كنصّ.
  Future<String> _getPersistentId() async {
    if (!Platform.isAndroid && !Platform.isIOS) return 'unsupported';

    try {
      final id = await PersistentDeviceId.getDeviceId();
      // `id.toString()` على null يُنتج النص الحرفي "null" فيُخزَّن معرّفاً
      if (id == null || id.isEmpty) return 'unknown';
      return id;
    } on Object catch (e) {
      _markDegraded('تعذّر جلب المعرّف الثابت: $e');
      return 'unknown';
    }
  }

  /// بيانات Android من القناة، أو null على غير Android أو عند فشل القناة
  Future<AndroidDeviceInfo?> _getAndroidInfo() async {
    if (!Platform.isAndroid) return null;

    try {
      return await DeviceInfoPlugin().androidInfo;
    } on Object catch (e) {
      _markDegraded('تعذّر جلب بيانات Android: $e');
      return null;
    }
  }

  /// بيانات iOS من القناة، أو null على غير iOS أو عند فشل القناة
  Future<IosDeviceInfo?> _getIosInfo() async {
    if (!Platform.isIOS) return null;

    try {
      return await DeviceInfoPlugin().iosInfo;
    } on Object catch (e) {
      _markDegraded('تعذّر جلب بيانات iOS: $e');
      return null;
    }
  }

  Future<SharedDeviceDetails> _getDeviceDetails({
    required String persistentId,
    AndroidDeviceInfo? androidInfo,
    IosDeviceInfo? iosInfo,
  }) async {
    try {
      if (androidInfo != null) {
        return SharedDeviceDetails(
          // `androidInfo.id` هو Build.ID — رقم بناء النظام لا معرّف جهاز —
          // ويتكرّر على كل جهازٍ يعمل بالبناء نفسه. المعرّف الثابت هو الوحيد
          // الذي يميّز الجهاز فعلاً، والحقل buildId يبقى لقيمة Build.ID.
          id: persistentId,
          brand: androidInfo.brand,
          model: androidInfo.model,
          name: androidInfo.device,
          type: _getAndroidDeviceType(),
          isPhysicalDevice: androidInfo.isPhysicalDevice,
          buildId: androidInfo.id,
          sdkInt: androidInfo.version.sdkInt,
        );
      }

      if (iosInfo != null) {
        return SharedDeviceDetails(
          id: iosInfo.identifierForVendor ?? persistentId,
          brand: 'Apple',
          model: iosInfo.model,
          name: iosInfo.name,
          type: _getIOSDeviceType(iosInfo),
          isPhysicalDevice: iosInfo.isPhysicalDevice,
          iosIdentifierForVendor: iosInfo.identifierForVendor,
          systemVersion: iosInfo.systemVersion,
        );
      }

      final deviceInfoPlugin = DeviceInfoPlugin();

      if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        return SharedDeviceDetails(
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
        return SharedDeviceDetails(
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
        return SharedDeviceDetails(
          id: linuxInfo.machineId ?? 'unknown',
          brand: linuxInfo.name,
          model: linuxInfo.prettyName,
          name: linuxInfo.name,
          type: 'desktop',
          isPhysicalDevice: true,
        );
      }
    } on Object catch (e) {
      // فشل قناة واحدة يُنقص حقولاً ولا يُسقط التهيئة كلّها
      _markDegraded('تعذّر جلب تفاصيل الجهاز: $e');
    }

    return const SharedDeviceDetails(
      id: 'unknown',
      brand: 'Unknown',
      model: 'Unknown',
      name: 'Unknown',
      type: 'unknown',
      isPhysicalDevice: true,
    );
  }

  SharedSystemInfo _getSystemInfo({
    AndroidDeviceInfo? androidInfo,
    IosDeviceInfo? iosInfo,
  }) {
    String osName = Platform.operatingSystem;
    String osVersion = Platform.operatingSystemVersion;
    final String platform = Platform.operatingSystem.toLowerCase();

    // تنظيف اسم النظام
    if (Platform.isAndroid) {
      osName = 'Android';
      if (androidInfo != null) {
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      }
    } else if (Platform.isIOS) {
      osName = 'iOS';
      if (iosInfo != null) {
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }
    } else if (Platform.isMacOS) {
      osName = 'macOS';
    } else if (Platform.isWindows) {
      osName = 'Windows';
    } else if (Platform.isLinux) {
      osName = 'Linux';
    }

    return SharedSystemInfo(
      osName: osName,
      osVersion: osVersion,
      platform: platform,
      locale: _currentLocale,
      timezone: DateTime.now().timeZoneName,
      // ليس `Platform.version`: ذاك إصدار زمن تشغيل Dart — نصّ طويل فيه
      // التاريخ والمنصّة وعلامات اقتباس — وإرساله في حقل `kernel_version`
      // يجعل كلّ تصنيفٍ للأجهزة بنواتها بلا معنى. المصدر الحقيقيّ الوحيد
      // المتاح لنا هو `utsname.release` على iOS (إصدار نواة Darwin)، وفي
      // سواه نترك الحقل فارغاً فيُحذف من الـ JSON أصلاً.
      kernelVersion: iosInfo?.utsname.release,
    );
  }

  /// `PlatformDispatcher.locale` هي `locales.first` وترمي StateError إذا لم
  /// تكن المنصّة قد بلّغت لغاتها بعد (isolate خلفي، إقلاع بلا واجهة)
  String get _currentLocale {
    final locales = PlatformDispatcher.instance.locales;
    if (locales.isEmpty) return 'und';
    return locales.first.toString();
  }

  /// النافذة الحالية إن وُجدت
  ///
  /// `views` قد تكون فارغة حين لا توجد نافذة مرتبطة بالمحرّك — إقلاع في
  /// الخلفية لمعالجة رسالة FCM، أو isolate خلفي، أو اختبار بلا binding —
  /// و`views.first` ترمي StateError حينها فتُسقط التهيئة كلّها.
  FlutterView? get _currentView {
    final dispatcher = PlatformDispatcher.instance;
    final implicitView = dispatcher.implicitView;
    if (implicitView != null) return implicitView;
    return dispatcher.views.isEmpty ? null : dispatcher.views.first;
  }

  /// نسبة البكسل قد تكون صفراً قبل أوّل إطار، والقسمة عليها تُنتج ∞ أو NaN
  double _safePixelRatio(double pixelRatio) =>
      (pixelRatio > 0 && pixelRatio.isFinite) ? pixelRatio : 1.0;

  SharedScreenInfo _getScreenInfo(Size? screenSize) {
    final view = _currentView;

    if (view == null) {
      return SharedScreenInfo(
        width: screenSize?.width ?? 0,
        height: screenSize?.height ?? 0,
        pixelRatio: 1,
        textScaleFactor: PlatformDispatcher.instance.textScaleFactor,
      );
    }

    final pixelRatio = _safePixelRatio(view.devicePixelRatio);
    final size = screenSize ?? (view.physicalSize / pixelRatio);

    return SharedScreenInfo(
      width: size.width,
      height: size.height,
      pixelRatio: pixelRatio,
      textScaleFactor: view.platformDispatcher.textScaleFactor,
    );
  }

  /// إعادة قياس ما لا يكون متاحاً قبل أوّل إطار
  ///
  /// `physicalSize` تساوي صفراً وقت التهيئة في main — وهو النمط الموصى به —
  /// فيتجمّد 0×0 في نموذجٍ غير قابل للتغيير ويبقى نوع الجهاز مجهولاً. نجدول
  /// إعادة قياسٍ واحدة بعد أوّل إطار بدل تجميد قيمٍ خاطئة إلى الأبد.
  void _scheduleFirstFrameRefresh() {
    if (_frameRefreshScheduled) return;

    final info = _deviceInfo;
    if (info == null) return;
    if (info.screen.width > 0 && info.device.type != 'unknown') return;

    _frameRefreshScheduled = true;
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) => _refreshAfterFirstFrame());
    } on Object catch (e) {
      // لا binding (اختبار أو isolate خلفي): نترك القيم كما هي
      _frameRefreshScheduled = false;
      debugPrint('تعذّر جدولة إعادة قياس الشاشة: $e');
    }
  }

  void _refreshAfterFirstFrame() {
    final info = _deviceInfo;
    final view = _currentView;
    if (info == null || view == null) return;

    final pixelRatio = _safePixelRatio(view.devicePixelRatio);
    final size = view.physicalSize / pixelRatio;
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    // لا نستبدل قيمة مرّرها المستدعي صراحةً، بل ما تعذّر قياسه فقط
    final needScreen = info.screen.width <= 0 || info.screen.height <= 0;
    final needType = Platform.isAndroid && info.device.type == 'unknown';
    if (!needScreen && !needType) return;

    _deviceInfo = SharedDeviceInfo(
      persistentId: info.persistentId,
      app: info.app,
      device: needType
          ? _withDeviceType(info.device, _deviceTypeOf(size.shortestSide))
          : info.device,
      system: info.system,
      screen: needScreen
          ? SharedScreenInfo(
              width: size.width,
              height: size.height,
              pixelRatio: pixelRatio,
              textScaleFactor: view.platformDispatcher.textScaleFactor,
            )
          : info.screen,
      extra: info.extra,
      collectedAt: info.collectedAt,
    );
  }

  SharedDeviceDetails _withDeviceType(SharedDeviceDetails device, String type) {
    return SharedDeviceDetails(
      id: device.id,
      brand: device.brand,
      model: device.model,
      name: device.name,
      type: type,
      isPhysicalDevice: device.isPhysicalDevice,
      buildId: device.buildId,
      iosIdentifierForVendor: device.iosIdentifierForVendor,
      sdkInt: device.sdkInt,
      systemVersion: device.systemVersion,
    );
  }

  /// نموذج ناقص يُستعمل حين يفشل الجمع كلّه، كي لا يرمي getter info لاحقاً
  SharedDeviceInfo _degradedInfo({
    Map<String, dynamic>? extraInfo,
    Size? screenSize,
  }) {
    return SharedDeviceInfo(
      persistentId: 'unknown',
      app: const SharedAppInfo(
        name: 'unknown',
        version: '0.0.0',
        buildNumber: '0',
        packageName: 'unknown',
      ),
      device: const SharedDeviceDetails(
        id: 'unknown',
        brand: 'Unknown',
        model: 'Unknown',
        name: 'Unknown',
        type: 'unknown',
        isPhysicalDevice: true,
      ),
      system: _getSystemInfo(),
      screen: _getScreenInfo(screenSize),
      extra: extraInfo ?? {},
      collectedAt: DateTime.now(),
    );
  }

  void _markDegraded(String message) {
    _isDegraded = true;
    debugPrint('DeviceInfoManager: $message');
  }

  /// تصنيف نوع جهاز Android
  ///
  /// قبل أوّل إطار تكون أبعاد الشاشة صفراً، وإرجاع 'phone' حينها يُصنّف كل
  /// جهازٍ لوحيّ هاتفاً في كل تقرير تحليلات. نُرجع 'unknown' ويُصحَّح
  /// التصنيف في [_refreshAfterFirstFrame] بعد أوّل إطار.
  String _getAndroidDeviceType() {
    final view = _currentView;
    if (view == null) return 'unknown';

    final size = view.physicalSize / _safePixelRatio(view.devicePixelRatio);
    return _deviceTypeOf(size.shortestSide);
  }

  /// المعيار هو أقصر بُعد (sw600dp) لا العرض وحده: عرض الهاتف في الوضع
  /// الأفقي يتجاوز 600 أيضاً
  String _deviceTypeOf(double shortestSide) {
    if (shortestSide <= 0 || !shortestSide.isFinite) return 'unknown';
    return shortestSide >= 600 ? 'tablet' : 'phone';
  }

  String _getIOSDeviceType(IosDeviceInfo info) {
    final model = info.model.toLowerCase();
    if (model.contains('ipad')) return 'tablet';
    if (model.contains('ipod')) return 'ipod';
    return 'phone';
  }
}
