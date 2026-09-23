// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك، وهو يُثبت أنّ
// `SentryEvent` و`Hint` مُعادا التصدير — لولاهما لما جاز نداء `apply` أصلاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

SentryEvent _event({
  String? value,
  String? type,
  String? url,
  String? message,
}) => SentryEvent(
  exceptions: value == null && type == null
      ? null
      : <SentryException>[
          SentryException(type: type ?? 'SocketException', value: value),
        ],
  message: message == null ? null : SentryMessage(message),
  request: url == null ? null : SentryRequest(url: url),
);

SentryEvent? _apply(SentryEvent event) =>
    SentryNoiseFilter.apply(event, Hint());

void main() {
  // `ownHosts` حالةٌ ساكنة عامّة، فتُصفَّر بين الاختبارات كيلا يتسرّب ضبطُ
  // اختبارٍ إلى ما بعده.
  setUp(() => SentryNoiseFilter.ownHosts = <String>[]);
  tearDown(() => SentryNoiseFilter.ownHosts = <String>[]);

  group('انقطاع الشبكة — يُسقط دائماً', () {
    test('Failed host lookup', () {
      expect(
        _apply(_event(value: 'Failed host lookup: api.azbah.com')),
        isNull,
      );
    });

    test('يُسقط ولو كان المضيف مضيفنا: الجهاز بلا إنترنت لا الخادم معطوب', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        value: 'Failed host lookup',
        url: 'https://api.azbah.com/v1/orders',
      );
      expect(_apply(event), isNull);
    });

    test('اختلاف حالة الأحرف لا يُفلت الضجيج', () {
      expect(_apply(_event(value: 'FAILED HOST LOOKUP')), isNull);
    });
  });

  group('مهلات المنصّات و Dio', () {
    test('Connection timed out — نصّ أندرويد/لينكس', () {
      expect(_apply(_event(value: 'Connection timed out')), isNull);
    });

    test('Operation timed out — نصّ iOS/macOS', () {
      expect(_apply(_event(value: 'Operation timed out')), isNull);
    });

    test('مهلة Dio بنصّها لا بـ SocketException', () {
      final SentryEvent event = _event(
        type: 'DioException',
        value: 'The request connectionTimeout limit of 0:00:30 was exceeded',
      );
      expect(_apply(event), isNull);
    });
  });

  group('عبارات النقل العامّة على مضيفنا — تمرّ', () {
    test('Connection refused على خادمنا عطبٌ نملكه', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        value: 'Connection refused',
        url: 'https://api.azbah.com/v1/orders',
      );
      expect(_apply(event), same(event));
    });

    test('وتُسقط حين لا يُضبط ownHosts — السلوك السابق محفوظ', () {
      final SentryEvent event = _event(
        value: 'Connection refused',
        url: 'https://api.azbah.com/v1/orders',
      );
      expect(_apply(event), isNull);
    });
  });

  group('نطاقات الأطراف الثالثة', () {
    test('طلبٌ إلى طرفٍ ثالث يُسقط', () {
      expect(
        _apply(
          _event(value: 'Bad gateway', url: 'https://graph.facebook.com/me'),
        ),
        isNull,
      );
    });

    test('نطاقٌ فرعيّ لطرفٍ ثالث يُسقط', () {
      expect(
        _apply(
          _event(value: 'Bad gateway', url: 'https://t.appsflyersdk.com/x'),
        ),
        isNull,
      );
    });

    test('نطاقٌ يُشبه اسمَ طرفٍ ثالث دون أن يكونه يمرّ', () {
      final SentryEvent event = _event(
        value: 'Bad gateway',
        url: 'https://notappsflyersdk.com/x',
      );
      expect(_apply(event), same(event));
    });

    test('خطأُ واجهتنا لا يُسقط لأنّ جسم الردّ ذكر رابط طرفٍ ثالث', () {
      final SentryEvent event = _event(
        type: 'TypeError',
        value:
            "null is not a subtype of String in 'https://graph.facebook.com/p.jpg'",
        url: 'https://api.azbah.com/v1/profile',
      );
      expect(_apply(event), same(event));
    });
  });

  test('محتوىً ذهب ولا يعود يُسقط', () {
    expect(_apply(_event(type: 'FileNoLongerAvailableException')), isNull);
  });

  group('ما يجب أن يمرّ', () {
    test('خطأٌ في كودنا يمرّ كما هو', () {
      final SentryEvent event = _event(
        type: 'RangeError',
        value: 'Index out of range: 5',
        url: 'https://api.azbah.com/v1/orders',
      );
      expect(_apply(event), same(event));
    });

    test('حدثٌ بلا استثناءات ولا رسالة ولا طلب لا يرمي ويمرّ', () {
      final SentryEvent event = SentryEvent();
      expect(_apply(event), same(event));
    });

    test('رسالةٌ نصّية بلا استثناء تُفحص أيضاً', () {
      expect(_apply(_event(message: 'Failed host lookup')), isNull);
    });
  });

  // `event.request` لا يملؤه شيء في هذه المكتبة — لا `sentry_dio` في
  // التبعيّات ولا `SentryBootstrap` يركّبه — فكان حارس [ownHosts] لا يُنفَّذ
  // على الأجهزة أصلاً. فالمضيف يُستخلص من نصّ الخطأ نفسه.
  group('استخلاص المضيف من نصّ الخطأ', () {
    test('حقل address في SocketException يكفي لحماية خادمنا', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        value:
            'SocketException: Connection refused (OS Error: Connection '
            'refused, errno = 61), address = api.azbah.com, port = 443',
      );
      expect(_apply(event), same(event));
    });

    test('رابطٌ في نصّ استثناء Dio يكفي كذلك', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        type: 'DioException',
        value:
            'DioException [connection timeout]: The request connectionTimeout '
            'limit of 0:00:30 was exceeded\nuri: https://api.azbah.com/v1/x',
      );
      expect(_apply(event), same(event));
    });

    test('نقطة الجملة بعد النطاق لا تُفسد المطابقة', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        value: 'Connection terminated while talking to https://api.azbah.com.',
      );
      expect(_apply(event), same(event));
    });

    test('مضيفٌ ليس مضيفنا يُسقط ولو ضُبطت ownHosts', () {
      final SentryEvent event = _event(
        value: 'Connection refused talking to https://api.example.com/v1',
      );
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      expect(_apply(event), isNull);
    });

    test('طرفٌ ثالث معروفٌ من النصّ وحده يُسقط', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(
        value: 'Connection reset by peer: https://app.adjust.com/session',
      );
      expect(_apply(event), isNull);
    });

    test('مضيفان في نصٍّ واحد: لا يُسقط ما لم يكن كلاهما طرفاً ثالثاً', () {
      final SentryEvent event = _event(
        type: 'TypeError',
        value:
            "null is not a subtype of String: 'https://graph.facebook.com/p.jpg' "
            'uri: https://api.azbah.com/v1/profile',
      );
      expect(_apply(event), same(event));
    });
  });

  group('مضيفٌ مجهول — الشكّ لمصلحة الإبلاغ حين تُضبط ownHosts', () {
    test('عبارةُ نقلٍ بلا مضيف تُرسل بدل أن تُسقط', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      final SentryEvent event = _event(value: 'Connection reset by peer');
      expect(_apply(event), same(event));
    });

    test('وتُسقط كما كانت حين تبقى ownHosts فارغة', () {
      expect(_apply(_event(value: 'Connection reset by peer')), isNull);
    });

    test('وانقطاع الشبكة يبقى ساقطاً — لا يُفلته هذا التساهل', () {
      SentryNoiseFilter.ownHosts = <String>['azbah.com'];
      expect(_apply(_event(value: 'Failed host lookup')), isNull);
      expect(_apply(_event(value: 'Network is unreachable')), isNull);
    });
  });
}
