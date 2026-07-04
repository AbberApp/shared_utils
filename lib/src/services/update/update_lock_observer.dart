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
      // شاشة دخيلة أثناء القفل. لا نُزيلها فقط (قد يكون الدخيل استبدل/أزال الشاشة
      // المقفولة عبر pushReplacement/removeUntil فتبقى شاشة سوداء)؛ بل نستعيد
      // الشاشة المقفولة كجذر وحيد → تُلغى الشاشة الدخيلة والمكدّس معًا. لا خروج،
      // لا شاشة سوداء، لا تكديس، ولا حلقة (دفع lockRouteName لا يُفعّل هذا الفرع).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator?.pushNamedAndRemoveUntil(lockRouteName, (r) => false);
      });
    }
  }
}
