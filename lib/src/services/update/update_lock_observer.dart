import 'package:flutter/widgets.dart';

/// يقفل التطبيق على شاشة معيّنة (عادةً شاشة التحديث الإجباريّ) ويمنع الخروج منها.
///
/// حقيقة تقنيّة: واجهة [NavigatorObserver] كلّها دوالّ `did*` (إشعار **بعد** وقوع
/// الحدث) بلا أيّ دالّة تعترض أو تُرجع قيمة — فلا يستطيع أيّ مراقب منع
/// `onGenerateRoute` أو إلغاء دفعٍ من داخله. لذا يقوم هذا الصنف بدورين:
///
/// 1) **مراقب** يرصد دخول [lockRouteName] فيرفع [locked] (عبر [didPush]).
/// 2) **حارس** عبر [guard]: تُلَفّ به دالّة `onGenerateRoute` — وهي النقطة
///    الرسميّة الوحيدة التي تُستدعى **قبل** بناء الوجهة. أثناء القفل يُحوّل أيّ
///    إعدادات وجهة إلى إعدادات الشاشة المقفولة، فلا تُبنى الوجهة الدخيلة أصلًا
///    (بلا استبدال، بلا إزالة، بلا شاشة سوداء — وكأنّ التوجيه لم يحدث).
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [UpdateLockObserver(lockRouteName: AppRoutes.appUpdateRoute)],
///   onGenerateRoute: (settings) => AppRoutes.generate(UpdateLockObserver.guard(settings)),
/// )
/// ```
class UpdateLockObserver extends NavigatorObserver {
  UpdateLockObserver({required String lockRouteName}) {
    _lockRouteName = lockRouteName;
  }

  static String? _lockRouteName;
  static bool _locked = false;

  /// true بعد الدخول للشاشة المقفولة. يُصفَّر عند إعادة تشغيل التطبيق.
  static bool get locked => _locked;

  /// يُلَفّ به `onGenerateRoute`. أثناء القفل يُعيد إعدادات الشاشة المقفولة بدل
  /// أيّ وجهة جديدة — فلا تُبنى الوجهة الدخيلة إطلاقًا.
  static RouteSettings guard(RouteSettings settings) {
    if (_locked && _lockRouteName != null && settings.name != _lockRouteName) {
      return RouteSettings(name: _lockRouteName, arguments: settings.arguments);
    }
    return settings;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == _lockRouteName) {
      _locked = true;
    }
  }
}
