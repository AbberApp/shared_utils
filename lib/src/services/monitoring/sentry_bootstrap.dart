import 'package:sentry_flutter/sentry_flutter.dart';

import '../../device/device_info_manager.dart';
import 'sentry_noise_filter.dart';

/// تهيئة Sentry موحّدة لكل تطبيقات المجموعة.
///
/// كان كل تطبيق يكتب إعداده بنفسه، فتتفرّق القرارات: أحدهم بلا مرشّح ضجيج،
/// وآخر بعيّنة تتبّع ١٠٠٪، وثالث بلا إصدار مضبوط. والتجربة علّمتنا الثمن:
/// لوحة «عبر» غرقت بـ٦٥٪ ضجيجَ شبكة أخفى أعطاباً حقيقية شهوراً.
///
/// فالمعيار هنا، والتطبيق يمرّر ما يخصّه وحده: المفتاح واسم الإصدار.
///
/// ```dart
/// await SentryBootstrap.run(
///   dsn: '…',
///   releasePrefix: 'flutter-abber',
///   appRunner: () => runApp(const MyApp()),
/// );
/// ```
abstract final class SentryBootstrap {
  /// نسبة تتبّع الأداء.
  ///
  /// ٢٠٪ لا ١٠٠٪: التتبّع يُرسل أثراً لكل عملية، وهو كلفةٌ وحصّة كبيرتان،
  /// والعيّنة تكفي لرصد الأنماط.
  static const double tracesSampleRate = 0.2;

  /// يُهيّئ Sentry ثمّ يُشغّل التطبيق.
  ///
  /// [releasePrefix] اسم المشروع في Sentry (`flutter-abber`، `azbah`…)؛
  /// تُلحق به النسخة ورقم البناء تلقائياً فتُطابق الإصدارات ما في المتجر.
  static Future<void> run({
    required String dsn,
    required String releasePrefix,
    required Future<void> Function() appRunner,
    String environment = 'production',
    Map<String, String> tags = const <String, String>{},
  }) async {
    await SentryFlutter.init(
      (SentryFlutterOptions options) async {
        final info = await DeviceInfoManager.instance.ensureInitialized();

        options.dsn = dsn;
        options.release =
            '$releasePrefix@${info.app.version}+${info.app.buildNumber}';
        options.environment = environment;
        options.tracesSampleRate = tracesSampleRate;

        // مرشّح الضجيج: يُسقط ما لا نملك إصلاحه — انقطاع الشبكة، وأخطاء
        // خوادم الأطراف الثالثة، ومحتوىً ذهب ولا يعود. وكل خطأ في كودنا يمرّ.
        options.beforeSend = SentryNoiseFilter.apply;

        if (tags.isNotEmpty) {
          Sentry.configureScope((Scope scope) {
            tags.forEach(scope.setTag);
          });
        }
      },
      appRunner: appRunner,
    );
  }

  /// يربط الأحداث اللاحقة بمستخدمٍ بعينه.
  ///
  /// [data] خريطة حرّة عمداً: لكل تطبيق حقوله (مشترٍ/معبّر، تاجر، مسؤول…)،
  /// والمكتبة لا تعرف نماذجه ولا ينبغي. فتمرّر ما يهمّك وحده.
  ///
  /// ```dart
  /// SentryBootstrap.identify(
  ///   id: user.id.toString(),
  ///   username: user.username,
  ///   email: user.email,
  ///   data: {'is_buyer': user.isBuyer, 'is_seller': user.isSeller},
  ///   tags: {'user_type': user.userType.ar},
  /// );
  /// ```
  ///
  /// ميزة تكميلية: تفشل صامتةً ولا تُعطّل مسار تسجيل الدخول.
  static void identify({
    required String id,
    String? username,
    String? email,
    Map<String, dynamic> data = const <String, dynamic>{},
    Map<String, String> tags = const <String, String>{},
  }) {
    try {
      Sentry.configureScope((Scope scope) {
        scope.setUser(
          SentryUser(
            id: id,
            username: username,
            email: email,
            data: data.isEmpty ? null : data,
          ),
        );
        tags.forEach(scope.setTag);
      });
    } on Object catch (_) {
      // لا شيء: هويّة المستخدم في التتبّع لا تستحقّ إسقاط تسجيل الدخول.
    }
  }

  /// يمسح هويّة المستخدم — عند تسجيل الخروج.
  static void forget() {
    try {
      Sentry.configureScope((Scope scope) => scope.setUser(null));
    } on Object catch (_) {}
  }
}
