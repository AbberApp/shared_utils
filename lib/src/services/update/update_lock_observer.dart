import 'package:flutter/widgets.dart';

/// مراقب تنقّل يقفل التطبيق على شاشة معيّنة (عادةً شاشة التحديث الإجباريّ).
///
/// بمجرّد أن تُدفَع الشاشة ذات [lockRouteName] يصبح [locked] = true، ثمّ تُزال
/// فورًا أيّ شاشة تُدفَع فوقها — فلا يحدث أيّ توجيه بعدها (المخرج الوحيد: إعادة
/// تشغيل التطبيق، حيث يُصفَّر القفل تلقائيًّا لأنّه ثابت في الذاكرة).
///
/// عامّ وقابل لإعادة الاستخدام: كل مشروع يمرّر اسم مساره الخاصّ، ويُسجّله في
/// `MaterialApp.navigatorObservers`:
/// ```dart
/// UpdateLockObserver(lockRouteName: AppRoutes.appUpdateRoute)
/// ```
class UpdateLockObserver extends NavigatorObserver {
  UpdateLockObserver({required this.lockRouteName});

  /// اسم المسار الذي يُقفَل عليه التطبيق.
  final String lockRouteName;

  static bool _locked = false;

  /// true بعد الدخول للشاشة المقفولة. يُصفَّر عند إعادة تشغيل التطبيق.
  static bool get locked => _locked;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == lockRouteName) {
      _locked = true;
    } else if (_locked) {
      if (previousRoute?.settings.name == lockRouteName) {
        // الدخيل فوق الشاشة المقفولة مباشرةً وهي باقية → أزِل الدخيل فقط
        // (بلا إعادة توجيه لشاشة مفتوحة أصلًا).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route.isActive) navigator?.removeRoute(route);
        });
      } else {
        // الشاشة المقفولة ليست تحت الدخيل (أُزيلت عبر removeUntil مثلًا) →
        // استعِدها كجذر وحيد لتجنّب الشاشة السوداء.
        _restore();
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // pushReplacement استبدل الشاشة المقفولة بأخرى → استعِدها.
    if (_locked &&
        oldRoute?.settings.name == lockRouteName &&
        newRoute?.settings.name != lockRouteName) {
      _restore();
    }
  }

  void _restore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator?.pushNamedAndRemoveUntil(lockRouteName, (r) => false);
    });
  }
}
