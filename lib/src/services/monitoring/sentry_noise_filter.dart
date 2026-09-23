import 'package:sentry_flutter/sentry_flutter.dart';

/// توقيع [SentryNoiseFilter.apply] وحقولُ الحدث الذي يفحصه كلّها أنواعٌ من
/// حزمة Sentry، ومستهلك المكتبة يستورد البرميل وحده — فلولا إعادة تصديرها
/// لتعذّر عليه تركيب مرشّحه فوق مرشّحنا في `options.beforeSend`.
export 'package:sentry_flutter/sentry_flutter.dart'
    show
        Hint,
        SentryEvent,
        SentryException,
        SentryLevel,
        SentryMessage,
        SentryRequest;

/// يمنع وصول ضجيج الشبكة والأطراف الثالثة إلى Sentry.
///
/// كان **٦٥٪ من أحداث المشروع** حدثاً واحداً: `Failed host lookup` — أي أنّ
/// جهاز المستخدم بلا إنترنت. ليس عطباً في الكود ولا شيء نُصلحه، لكنّه يُغرق
/// اللوحة فيُخفي ما تحته: أعطاب حقيقية أصابت مئات المستخدمين وعاشت شهوراً بلا
/// انتباه لأنّ الضجيج كان فوقها.
///
/// والمرشّح **يُسقط ما لا نملك إصلاحه فقط**: انقطاع الشبكة، وأخطاء خوادم
/// أطرافٍ ثالثة. وكل خطأ في كودنا يمرّ كما هو.
///
/// واضبط [ownHosts] بنطاقات خوادمك قبل التهيئة، فأعطاب النقل العامّة — رفض
/// اتصال، مهلة، اتصالٌ مقطوع — ليست حالةَ جهازٍ بل قد تكون عطبَ خادمك أنت.
///
/// ```dart
/// SentryNoiseFilter.ownHosts = <String>['api.azbah.com'];
/// ```
abstract final class SentryNoiseFilter {
  /// نطاقات خوادمنا — يشمل كلٌّ منها نطاقاته الفرعية.
  ///
  /// تُسند قبل `SentryBootstrap.run`. وما دامت فارغة فالسلوك كما كان: كلّ
  /// عبارات النقل تُسقط أيّاً كان المضيف.
  ///
  /// وحين تُضبط فالشكّ يُحسب لمصلحة الإبلاغ: عبارةُ نقلٍ لم نستطع معرفة
  /// مضيفها تُرسل ولا تُسقط، فقد تكون خادمك أنت. وثمنُ حدثٍ زائد أهونُ من
  /// خادمٍ ساقطٍ يمرّ شهوراً بلا انتباه — وهو الثمن الذي دفعناه مرّة.
  static List<String> ownHosts = <String>[];

  /// انقطاعٌ عند جهاز المستخدم: فشل استبيان DNS أو غياب مسارٍ إلى الشبكة.
  ///
  /// لا تدلّ على خادمٍ بعينه — لو كان الجهاز بلا إنترنت لفشل كلّ طلبٍ مهما
  /// كان مضيفه — فتُسقط دائماً.
  static const List<String> _offlineConditions = <String>[
    'Failed host lookup',
    'Network is unreachable',
    'No address associated with hostname',
    'nodename nor servname provided',
  ];

  /// أعطاب نقلٍ تُسقط فقط حين لا يكون المضيف مضيفَنا.
  ///
  /// خادمٌ يرفض الاتصال أو يقطعه أو يتأخّر عن المهلة عطبٌ نملك إصلاحه إن كان
  /// خادمنا: `baseUrl` يشير إلى بيئةٍ مغلقة، أو شهادةٌ انتهت، أو حاوية سقطت.
  static const List<String> _transportConditions = <String>[
    'Connection refused',
    'Connection reset by peer',
    'Connection closed before full header was received',
    'Connection terminated',
    'Software caused connection abort',
    // نصّ المهلة يختلف بالمنصّة: iOS/macOS يقول الأولى وأندرويد/لينكس الثانية.
    'Operation timed out',
    'Connection timed out',
    // ومهلات Dio لا تمرّ عبر SocketException أصلاً بل بأسماء وسائطها هذه.
    'connectionTimeout',
    'receiveTimeout',
    'sendTimeout',
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
    final List<String> hosts = _eventHosts(event, haystack);

    if (_containsAny(haystack, _offlineConditions)) return null;
    // مرفقات ما قبل ترحيل التخزين فُقدت مع خوادم البحرين — ليست عطباً.
    if (_containsAny(haystack, _goneContent)) return null;

    // ما بقي عبارات عامّة قد تكون عطبَ خادمنا نحن، فلا تُسقط على مضيفنا.
    if (hosts.any((String host) => _matchesHost(host, ownHosts))) return event;

    if (hosts.isNotEmpty) {
      // المضيف معلوم: تُطابَق نطاقات الأطراف الثالثة عليه وحده لا على نصّ
      // الحدث كلّه، كيلا يُسقط خطأُ واجهتنا لأنّ جسم الردّ ذكر رابط طرفٍ ثالث.
      //
      // و`every` لا `any`: نصٌّ واحد قد يحمل مضيفين — واجهتنا في `uri` ورابطَ
      // طرفٍ ثالث في جسم الردّ — فلا يُسقط الحدث إلّا إن كان كلّ مضيفٍ
      // عرفناه لطرفٍ ثالث.
      if (hosts.every((String host) => _matchesHost(host, _thirdPartyHosts))) {
        return null;
      }
    } else if (_containsAny(haystack, _thirdPartyHosts)) {
      return null;
    }

    if (_containsAny(haystack, _transportConditions)) {
      // مضيفٌ مجهول و[ownHosts] مضبوطة: لا سبيل إلى معرفة أهو خادمنا أم لا،
      // والإسقاط هنا يعني إخفاء انقطاع خادمنا بالضبط كما لو لم تُضبط القائمة.
      // فيُرسل الحدث: الشكّ لمصلحة الإبلاغ ما دام التطبيق طلب هذه الحماية.
      if (hosts.isEmpty && ownHosts.isNotEmpty) return event;
      return null;
    }

    return event;
  }

  /// مطابقة غير حسّاسة لحالة الأحرف: نصّ الخطأ نفسه يختلف رسمُه بالمنصّة.
  static bool _containsAny(String haystack, List<String> patterns) =>
      patterns.any((String p) => haystack.contains(p.toLowerCase()));

  /// `host == domain` أو نطاقٌ فرعيّ له.
  ///
  /// النقطة مقصودة: `endsWith` وحدها تجعل `notappsflyersdk.com` طرفاً ثالثاً.
  static bool _matchesHost(String host, List<String> domains) => domains.any(
    (String domain) =>
        host == domain.toLowerCase() ||
        host.endsWith('.${domain.toLowerCase()}'),
  );

  /// يلتقط المضيف من نصّ الخطأ: رابطاً كاملاً، أو حقلَ `address =` الذي
  /// يطبعه `SocketException.toString` ويحمل اسم المضيف لا عنوانه غالباً.
  static final RegExp _hostPattern = RegExp(
    r'''https?://([^/\s:,)'">\]]+)|address\s*=\s*([^\s,)'">\]]+)''',
  );

  /// كلّ مضيفٍ يمكن استخلاصه من الحدث: مضيف `event.request` ثمّ ما في نصّه.
  ///
  /// الاعتماد على `event.request` وحده كان يُعطّل [ownHosts] بالكامل: لا شيء
  /// في هذه المكتبة يملؤه — لا `sentry_dio` في التبعيّات ولا `SentryBootstrap`
  /// يركّبه، و`DioConsumer` يمسح المعترِضات فيمنع التطبيق من تركيبه — فكان
  /// المضيف `null` في كلّ حدثٍ على الأجهزة، وحارسُ خوادمنا لا يُنفَّذ قطّ.
  /// ونصّ الخطأ نفسه يحمل المضيف في العادة، فهو المصدر المعوَّل عليه.
  static List<String> _eventHosts(SentryEvent event, String haystack) {
    final Set<String> hosts = <String>{};
    final String? requestHost = _requestHost(event);
    if (requestHost != null) hosts.add(requestHost);

    for (final RegExpMatch match in _hostPattern.allMatches(haystack)) {
      // النقطة الأخيرة نقطةُ جملةٍ لا جزءٌ من النطاق، وتركُها يُفشل المطابقة.
      final String host = (match.group(1) ?? match.group(2) ?? '')
          .replaceFirst(RegExp(r'\.+$'), '');
      if (host.isNotEmpty) hosts.add(host);
    }

    return hosts.toList(growable: false);
  }

  /// مضيف طلب الحدث إن عُرف — `event.request` لا تُملأ إلا بتكامل Dio.
  static String? _requestHost(SentryEvent event) {
    final String? url = event.request?.url;
    if (url == null || url.isEmpty) return null;
    final String host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? null : host.toLowerCase();
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
    final SentryMessage? message = event.message;
    if (message != null) buffer.write('${message.formatted} ');
    final SentryRequest? request = event.request;
    if (request != null) buffer.write('${request.url ?? ''} ');

    return buffer.toString().toLowerCase();
  }
}
