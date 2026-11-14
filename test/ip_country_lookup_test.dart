import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `IpCountryLookup` — البديل المحلّيّ لحزمة `ip_country_lookup`.
///
/// يحرس ثلاثة أمور: **تطابقَ الأسماء** التي تقرؤها التطبيقات، و**ألّا يرمي** —
/// فهو يُستدعى عند فتح حقل الهاتف — و**ألّا يكون الفشل رمزاً**: كانت الحزمة تُرجع
/// `'N/A'` فيُستبدل بدولة المستخدم السعوديةُ وتُحفظ.
///
/// لا شبكة هنا: المُرسِل البديل يُجيب بما في [responses] ويسجّل ما طُلب.
void main() {
  late List<String> requested;

  IpCountryLookup lookup(Map<String, Object?> responses) {
    requested = <String>[];
    return IpCountryLookup.withRequest((Uri uri) async {
      requested.add(uri.host);
      final Object? response = responses[uri.host];
      if (response is Exception) throw response;
      return response;
    });
  }

  DioException networkFailure() =>
      DioException(requestOptions: RequestOptions(path: '/'));

  const String cloudflare = '<!DOCTYPE html><title>Just a moment...</title>';

  group('أسماء الحزمة — لا يجوز أن تنحرف', () {
    test('المُنشئ والدالّة والحقلان بأنواعها', () {
      final Future<IpCountryData> Function() call =
          IpCountryLookup().getIpLocationData;
      const IpCountryData data = IpCountryData(countryCode: 'SA');
      final String? code = data.countryCode;
      // ignore: deprecated_member_use_from_same_package
      final String? legacy = data.country_code;
      expect(<Object?>[call, code, legacy], <Object?>[isA<Function>(), 'SA', 'SA']);
    });

    test('IpCountryLookup() نسخةٌ مشتركة كما في الحزمة', () {
      expect(identical(IpCountryLookup(), IpCountryLookup()), isTrue);
    });
  });

  group('ترتيب الخدمات', () {
    test('ipwho.is تكفي وحدها: طلبٌ واحد', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': '{"success": true, "country_code": "SA"}',
      }).getIpLocationData();
      expect(data.countryCode, 'SA');
      expect(requested, <String>['ipwho.is']);
    });

    test('ipwho.is تردّ success: false ← ipapi.co', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': '{"success": false, "message": "Reserved range"}',
        'ipapi.co': '{"country_code": "AE"}',
      }).getIpLocationData();
      expect(data.countryCode, 'AE');
      expect(requested, <String>['ipwho.is', 'ipapi.co']);
    });

    test('شبكةٌ معطوبة ثمّ صفحة Cloudflare ← ipify ثمّ iplocation.net', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': networkFailure(),
        'ipapi.co': cloudflare,
        'api64.ipify.org': '{"ip": "203.0.113.7"}',
        'api.iplocation.net': '{"country_code2": "KW", "response_code": "200"}',
      }).getIpLocationData();
      expect(data.countryCode, 'KW');
      expect(requested, <String>['ipwho.is', 'ipapi.co', 'api64.ipify.org', 'api.iplocation.net']);
    });

    test('ipify بلا عنوان ← لا يُسأل iplocation.net', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': networkFailure(),
        'ipapi.co': networkFailure(),
        'api64.ipify.org': '{"ip": ""}',
      }).getIpLocationData();
      expect(data.countryCode, isNull);
      expect(requested, isNot(contains('api.iplocation.net')));
    });
  });

  group('الفشل null — لا N/A ولا رمي', () {
    test('كلّ الخدمات معطوبة ← null', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': networkFailure(),
        'ipapi.co': networkFailure(),
        'api64.ipify.org': networkFailure(),
      }).getIpLocationData();
      expect(data.countryCode, isNull);
      // ignore: deprecated_member_use_from_same_package
      expect(data.country_code, isNull);
    });

    test('رمزٌ غير صالح يُتخطّى إلى الخدمة التالية', () async {
      for (final Object? bad in <Object?>['N/A', 'SAU', '', 'S1', 12, null]) {
        final IpCountryData data = await lookup(<String, Object?>{
          'ipwho.is': <String, Object?>{'success': true, 'country_code': bad},
          'ipapi.co': '{"country_code": "BH"}',
        }).getIpLocationData();
        expect(data.countryCode, 'BH', reason: 'الرمز: $bad');
      }
    });

    test('ردٌّ ليس JSON، أو JSON ليس كائناً، يُتخطّى', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': 'not json',
        'ipapi.co': '["SA"]',
        'api64.ipify.org': '{"ip": "198.51.100.1"}',
        'api.iplocation.net': '{"country_code2": "OM"}',
      }).getIpLocationData();
      expect(data.countryCode, 'OM');
    });

    test('الرمز بحروفٍ كبيرة', () async {
      final IpCountryData data = await lookup(<String, Object?>{
        'ipwho.is': '{"success": true, "country_code": "qa"}',
      }).getIpLocationData();
      expect(data.countryCode, 'QA');
    });
  });
}
