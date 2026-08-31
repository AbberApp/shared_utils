import 'package:sentry_flutter/sentry_flutter.dart';

/// يمنع وصول ضجيج الشبكة والأطراف الثالثة إلى Sentry.
///
/// كان **٦٥٪ من أحداث المشروع** حدثاً واحداً: `Failed host lookup` — أي أنّ
/// جهاز المستخدم بلا إنترنت. ليس عطباً في الكود ولا شيء نُصلحه، لكنّه يُغرق
/// اللوحة فيُخفي ما تحته: أعطاب حقيقية أصابت مئات المستخدمين وعاشت شهوراً بلا
/// انتباه لأنّ الضجيج كان فوقها.
///
/// والمرشّح **يُسقط ما لا نملك إصلاحه فقط**: انقطاع الشبكة، وأخطاء خوادم
/// أطرافٍ ثالثة. وكل خطأ في كودنا يمرّ كما هو.
abstract final class SentryNoiseFilter {
  /// رسائل انقطاع الشبكة — حالة جهازٍ لا عطبَ برمجيّ.
  static const List<String> _networkConditions = <String>[
    'Failed host lookup',
    'Network is unreachable',
    'No address associated with hostname',
    'Connection refused',
    'Connection reset by peer',
    'Connection closed before full header was received',
    'Software caused connection abort',
    'Operation timed out',
    'nodename nor servname provided',
  ];

  /// نطاقات لا نملك خوادمها، فأخطاؤها ليست أخطاءنا.
  static const List<String> _thirdPartyHosts = <String>[
    'appsflyersdk.com',
    'app.adjust.com',
    'graph.facebook.com',
  ];

  /// أخطاء لا نملك إصلاحها: محتوىً ذهب ولا يعود.
  static const List<String> _goneContent = <String>[
    'FileNoLongerAvailableException',
  ];

  /// يُعيد `null` لإسقاط الحدث، أو الحدث نفسه لإرساله.
  static SentryEvent? apply(SentryEvent event, Hint hint) {
    final String haystack = _haystack(event);

    for (final String pattern in _networkConditions) {
      if (haystack.contains(pattern)) return null;
    }
    for (final String host in _thirdPartyHosts) {
      if (haystack.contains(host)) return null;
    }
    // مرفقات ما قبل ترحيل التخزين فُقدت مع خوادم البحرين — ليست عطباً.
    for (final String marker in _goneContent) {
      if (haystack.contains(marker)) return null;
    }
    return event;
  }

  /// يجمع نصّ الحدث من مواضعه المحتملة: قيمة الاستثناء، ونوعه، ورابط الطلب.
  static String _haystack(SentryEvent event) {
    final StringBuffer buffer = StringBuffer();

    for (final SentryException exception in event.exceptions ?? const []) {
      buffer
        ..write(exception.value ?? '')
        ..write(' ')
        ..write(exception.type ?? '')
        ..write(' ');
    }
    for (final SentryMessage? message in <SentryMessage?>[event.message]) {
      if (message != null) buffer.write('${message.formatted} ');
    }
    final SentryRequest? request = event.request;
    if (request != null) buffer.write('${request.url ?? ''} ');

    return buffer.toString();
  }
}
