import 'package:firebase_messaging/firebase_messaging.dart';

/// واجهة التفويض للإشعارات
/// كل مشروع يُنفّذ هذه الواجهة ويضع فيها المنطق الخاص به
abstract class NotificationDelegate {
  /// أنواع الإشعارات التي يجب تجاهلها (مثل 'calling' في الخلفية)
  List<String> get ignoredTypes;

  /// هل يدعم VoIP (FlutterCallkitIncoming)
  bool get supportsVoIP;

  /// هل يدعم CallKit
  bool get supportsCallKit;

  /// معالجة إشعار الخلفية (background/terminated)
  Future<void> handleBackgroundMessage(Map<String, dynamic> data);

  /// معالجة إشعار المقدمة (foreground)
  Future<void> handleForegroundMessage(Map<String, dynamic> data);

  /// معالجة فتح التطبيق من إشعار (onMessageOpenedApp)
  Future<void> handleMessageOpenedApp(Map<String, dynamic> data);

  /// التوجيه بناءً على بيانات الإشعار (payload)
  Future<void> handleRoute(Map<String, dynamic> data);

  /// معالجة الإشعار الأول عند بدء التطبيق (initial message)
  Future<void> handleInitialMessage(RemoteMessage message);
}
