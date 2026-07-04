import 'package:flutter/widgets.dart';

/// `Navigator` يوقِف كلّ التوجيه بمجرّد استدعاء [lock].
///
/// الفكرة: تجاوز دوالّ الدفع في [NavigatorState] بحيث — وهو مقفول — **تعود
/// مبكّرًا دون استدعاء `super`**. وبما أنّ `super` هو الذي يستدعي `onGenerateRoute`
/// ويعدّل المكدّس، فإنّ **الدفع لا يُنفَّذ إطلاقًا ولا يُبنى أيّ Route** — لا استبدال،
/// لا إزالة، لا شاشة سوداء، وكأنّ الاستدعاء لم يحدث. يُستخدَم لمنع الخروج من شاشة
/// حاجبة (كشاشة التحديث الإجباريّ) بعد عرضها.
///
/// القفل ثابت في الذاكرة → يُصفَّر تلقائيًّا عند إعادة تشغيل التطبيق.
///
/// يُحقَن بدل الـNavigator الافتراضيّ (مثلًا عبر `MaterialApp.builder`):
/// ```dart
/// MaterialApp(
///   builder: (_, __) => GuardedNavigator(
///     key: navigatorKey,
///     initialRoute: '/',
///     onGenerateRoute: AppNavigation.generate,
///     observers: [...],
///   ),
/// )
/// ```
class GuardedNavigator extends Navigator {
  const GuardedNavigator({
    super.key,
    super.initialRoute,
    super.onGenerateRoute,
    super.onUnknownRoute,
    super.observers,
    super.requestFocus,
  });

  static bool _locked = false;

  /// true بعد قفل التنقّل. يُصفَّر عند إعادة تشغيل التطبيق.
  static bool get locked => _locked;

  /// يقفل التنقّل نهائيًّا: بعده أيّ `push*` لا يُنفَّذ ولا يصل `onGenerateRoute`.
  static void lock() => _locked = true;

  @override
  NavigatorState createState() => GuardedNavigatorState();
}

class GuardedNavigatorState extends NavigatorState {
  static Future<T?> _noFuture<T>() => Future<T?>.value(null);

  @override
  Future<T?> push<T extends Object?>(Route<T> route) =>
      GuardedNavigator._locked ? _noFuture<T>() : super.push<T>(route);

  @override
  Future<T?> pushNamed<T extends Object?>(String routeName, {Object? arguments}) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.pushNamed<T>(routeName, arguments: arguments);

  @override
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    Route<T> newRoute, {
    TO? result,
  }) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.pushReplacement<T, TO>(newRoute, result: result);

  @override
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.pushReplacementNamed<T, TO>(
              routeName,
              result: result,
              arguments: arguments,
            );

  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    Route<T> newRoute,
    RoutePredicate predicate,
  ) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.pushAndRemoveUntil<T>(newRoute, predicate);

  @override
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.pushNamedAndRemoveUntil<T>(
              newRouteName,
              predicate,
              arguments: arguments,
            );

  @override
  Future<T?> popAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? _noFuture<T>()
          : super.popAndPushNamed<T, TO>(
              routeName,
              result: result,
              arguments: arguments,
            );

  // ── نسخ الاستعادة (تُعيد معرّف استعادة String؛ '' = لا شيء) ───────────────
  @override
  String restorablePush<T extends Object?>(
    RestorableRouteBuilder<T> routeBuilder, {
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePush<T>(routeBuilder, arguments: arguments);

  @override
  String restorablePushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePushNamed<T>(routeName, arguments: arguments);

  @override
  String restorablePushReplacement<T extends Object?, TO extends Object?>(
    RestorableRouteBuilder<T> routeBuilder, {
    TO? result,
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePushReplacement<T, TO>(
              routeBuilder,
              result: result,
              arguments: arguments,
            );

  @override
  String restorablePushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePushReplacementNamed<T, TO>(
              routeName,
              result: result,
              arguments: arguments,
            );

  @override
  String restorablePushAndRemoveUntil<T extends Object?>(
    RestorableRouteBuilder<T> newRouteBuilder,
    RoutePredicate predicate, {
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePushAndRemoveUntil<T>(
              newRouteBuilder,
              predicate,
              arguments: arguments,
            );

  @override
  String restorablePushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePushNamedAndRemoveUntil<T>(
              newRouteName,
              predicate,
              arguments: arguments,
            );

  @override
  String restorablePopAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      GuardedNavigator._locked
          ? ''
          : super.restorablePopAndPushNamed<T, TO>(
              routeName,
              result: result,
              arguments: arguments,
            );
}
