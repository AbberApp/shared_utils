import 'dart:developer';

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
  ///
  /// [environment] يُترك فارغاً في العادة: Sentry نفسه يستنتج البيئة من وضع
  /// البناء (`debug`/`profile`/`production`) ويحترم `SENTRY_ENVIRONMENT`.
  /// ولا يُمرَّر إلّا لتسمية بيئةٍ لا يعرفها وضع البناء — `staging` مثلاً.
  static Future<void> run({
    required String dsn,
    required String releasePrefix,
    required Future<void> Function() appRunner,
    String? environment,
    Map<String, String> tags = const <String, String>{},
  }) async {
    // أداةُ المراقبة لا يجوز أن تُسقط ما تراقبه: التطبيق يُقلع في كلّ الأحوال،
    // ولو فشلت تهيئة Sentry أو فشل جلب معلومات الجهاز.
    bool appStarted = false;
    Future<void> guardedRunner() async {
      appStarted = true;
      await appRunner();
    }

    try {
      await SentryFlutter.init(
        (SentryFlutterOptions options) async {
          // الإعدادات المضمونة أوّلاً: لو رمى ما بعدها بقي Sentry صالحاً.
          options.dsn = dsn;
          // لا تُسند البيئة إلّا حين تُمرَّر: الإسناد غير المشروط كان يمحو ما
          // استنتجه Sentry من وضع البناء، فتُنسب أعطاب التطوير إلى الإنتاج.
          if (environment != null) options.environment = environment;
          options.tracesSampleRate = tracesSampleRate;

          // مرشّح الضجيج: يُسقط ما لا نملك إصلاحه — انقطاع الشبكة، وأخطاء
          // خوادم الأطراف الثالثة، ومحتوىً ذهب ولا يعود. وكل خطأ في كودنا يمرّ.
          options.beforeSend = SentryNoiseFilter.apply;

          // نداء إضافات المنصّة: يرمي MissingPluginException على سطح المكتب
          // وPlatformException على أجهزة حقيقية. كان يمنع الإقلاع كلّياً.
          try {
            final info = await DeviceInfoManager.instance.ensureInitialized();
            options.release =
                '$releasePrefix@${info.app.version}+${info.app.buildNumber}';
          } on Object catch (e, st) {
            log(
              'تعذّر جلب معلومات الجهاز — الإصدار بلا رقم بناء',
              error: e,
              stackTrace: st,
              name: 'SentryBootstrap',
            );
            options.release = releasePrefix;
          }

          // الوسوم بمعالج أحداث لا بضبط النطاق: `Sentry.configureScope` هنا
          // تجري قبل إنشاء الـ Hub الحقيقي، فتذهب إلى NoOpHub وتُهمَل صامتةً.
          if (tags.isNotEmpty) {
            options.addEventProcessor(_StaticTagsProcessor(tags));
          }
        },
        appRunner: guardedRunner,
      );
    } on Object catch (e, st) {
      log(
        'فشلت تهيئة Sentry — يُشغَّل التطبيق بلا مراقبة',
        error: e,
        stackTrace: st,
        name: 'SentryBootstrap',
      );
      if (!appStarted) await appRunner();
    }
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

/// يختم كلّ حدث بوسوم التطبيق الثابتة الممرَّرة مرّةً عند التهيئة.
class _StaticTagsProcessor implements EventProcessor {
  const _StaticTagsProcessor(this._tags);

  final Map<String, String> _tags;

  @override
  SentryEvent apply(SentryEvent event, Hint hint) {
    // المعالجات تجري بعد تطبيق النطاق، فوسمٌ هنا يغلب وسمَ النطاق بالمفتاح
    // ذاته — وهو المقصود: هذه وسوم التطبيق الثابتة لا وسوم الجلسة.
    event.tags = <String, String>{...?event.tags, ..._tags};
    return event;
  }
}
