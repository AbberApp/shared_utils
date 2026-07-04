import 'package:flutter/widgets.dart';

/// يقفل التطبيق على شاشة معيّنة (عادةً شاشة التحديث الإجباريّ) ويمنع الخروج منها
/// **من جذر التوجيه** — لا استبدال، لا إزالة، لا شاشة سوداء.
///
/// لماذا من الجذر؟ لأنّ `NavigatorObserver` يرصد **بعد** حدوث الدفع (وقد يكون
/// التنقّل أزال الشاشة المقفولة عبر `pushNamedAndRemoveUntil` فتظهر شاشة سوداء).
/// أمّا `onGenerateRoute` فيُستدعى **قبل** إنشاء الوجهة — فهو الجذر الصحيح للمنع.
///
/// الاستخدام:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [UpdateLockObserver(lockRouteName: AppRoutes.appUpdateRoute)],
///   onGenerateRoute: (settings) {
///     final name = UpdateLockObserver.resolve(settings.name); // ← المنع من الجذر
///     switch (name) { ... }
///   },
/// )
/// ```
/// حين يكون مقفلًا، يُحوّل [resolve] أيّ وجهة جديدة إلى الشاشة المقفولة، فتُبنى
/// شاشة القفل بدل الوجهة الدخيلة — الوجهة الدخيلة **لا تُبنى إطلاقًا**.
class UpdateLockObserver extends NavigatorObserver {
  UpdateLockObserver({required String lockRouteName}) {
    _lockRouteName = lockRouteName;
  }

  static String? _lockRouteName;
  static bool _locked = false;

  /// true بعد الدخول للشاشة المقفولة. يُصفَّر عند إعادة تشغيل التطبيق.
  static bool get locked => _locked;

  /// يُستدعى في أعلى `onGenerateRoute` (جذر التوجيه). أثناء القفل يُعيد اسم
  /// الشاشة المقفولة بدل أيّ وجهة جديدة — فلا تُبنى الوجهة الدخيلة أصلًا.
  static String? resolve(String? requestedRouteName) {
    if (_locked &&
        _lockRouteName != null &&
        requestedRouteName != _lockRouteName) {
      return _lockRouteName;
    }
    return requestedRouteName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // رصد فقط: يُرفَع القفل بمجرّد دخول الشاشة المقفولة. المنع الفعليّ في [resolve].
    if (route.settings.name == _lockRouteName) {
      _locked = true;
    }
  }
}
