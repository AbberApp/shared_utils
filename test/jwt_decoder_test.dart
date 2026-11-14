import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `JwtDecoder` — البديل المحلّيّ لحزمة `jwt_decoder`.
///
/// يحرس أمرين: **تطابقَ التواقيع** مع الحزمة كي لا يُمسّ سطرٌ في التطبيقات،
/// و**ألّا ترمي `isExpired` أبداً** — فهي تُستدعى على كلّ طلبٍ في المعترِض وفي
/// إقلاع التطبيق، وكانت ترمي على رمزٍ تالف فتُسقط الطلب أو تُعلّق الإقلاع.
void main() {
  /// رمزٌ بحمولة [payload]، مرمَّزٌ base64url بلا حشو كما في JWT الحقيقيّ.
  String token(Map<String, Object?> payload) {
    String seg(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    return '${seg(<String, String>{'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.sig';
  }

  int epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  final DateTime now = DateTime.now();
  final String expired = token(<String, Object?>{
    'exp': epoch(now.subtract(const Duration(hours: 1))),
  });
  final String valid = token(<String, Object?>{
    'exp': epoch(now.add(const Duration(days: 7))),
    'iat': epoch(now.subtract(const Duration(minutes: 5))),
  });

  group('تواقيع الحزمة — لا يجوز أن تنحرف', () {
    test('الدوالّ الستّ ساكنةٌ بأنواعها', () {
      // إسنادٌ إلى نوعٍ صريح: لو تغيّر توقيعٌ لما صُرّف هذا الملفّ.
      final Map<String, dynamic> Function(String) decode = JwtDecoder.decode;
      final Map<String, dynamic>? Function(String) tryDecode =
          JwtDecoder.tryDecode;
      final bool Function(String) isExpired = JwtDecoder.isExpired;
      final DateTime Function(String) expiration = JwtDecoder.getExpirationDate;
      final Duration Function(String) remaining = JwtDecoder.getRemainingTime;
      final Duration Function(String) tokenTime = JwtDecoder.getTokenTime;
      expect(
        <Function>[decode, tryDecode, isExpired, expiration, remaining, tokenTime],
        hasLength(6),
      );
    });
  });

  group('decode', () {
    test('يُرجع الحمولة', () {
      expect(JwtDecoder.decode(token(<String, Object?>{'sub': '42', 'n': 1})),
          <String, Object?>{'sub': '42', 'n': 1});
    });

    test('أبجدية base64url بلا حشو — «??>» تُرمَّز بـ«_» وتنقصها «==»', () {
      final String t = token(<String, Object?>{'sub': '??>'});
      expect(t.split('.')[1], contains('_'));
      expect(JwtDecoder.decode(t)['sub'], '??>');
    });

    test('نصٌّ عربيّ في الحمولة يُفكّ بـUTF-8', () {
      expect(JwtDecoder.decode(token(<String, Object?>{'name': 'عبر'}))['name'],
          'عبر');
    });

    test('يرمي FormatException — لا سواها — على كلّ شكلٍ معطوب', () {
      for (final String bad in <String>[
        '',
        'abc',
        'a.b',
        'a.b.c.d',
        'a.!!!.c', // ليست base64
        'a.${base64Url.encode(utf8.encode('not json'))}.c',
        'a.${base64Url.encode(utf8.encode('[1,2]'))}.c', // مصفوفةٌ لا كائن
        'a.${base64Url.encode(utf8.encode('"text"'))}.c',
      ]) {
        expect(() => JwtDecoder.decode(bad), throwsFormatException,
            reason: 'الرمز: «$bad»');
        expect(JwtDecoder.tryDecode(bad), isNull, reason: 'الرمز: «$bad»');
      }
    });
  });

  group('isExpired — لا ترمي أبداً', () {
    test('انتهى ← true، ولم ينتهِ ← false', () {
      expect(JwtDecoder.isExpired(expired), isTrue);
      expect(JwtDecoder.isExpired(valid), isFalse);
    });

    test('رمزٌ معطوب ← true: يُسجَّل الخروج بدل أن يسقط الطلب', () {
      expect(JwtDecoder.isExpired(''), isTrue);
      expect(JwtDecoder.isExpired('not-a-jwt'), isTrue);
      expect(JwtDecoder.isExpired('a.!!!.c'), isTrue);
    });

    test('بلا exp ← false: الحقل اختياريّ في RFC 7519', () {
      // كانت الحزمة ترمي هنا NoSuchMethodError — Error لا يلتقطه on Exception.
      expect(JwtDecoder.isExpired(token(<String, Object?>{'sub': '1'})), isFalse);
      expect(JwtDecoder.isExpired(token(<String, Object?>{'exp': null})), isFalse);
    });

    test('exp ليس عدداً أو خارج مدى DateTime ← true بلا رمي', () {
      expect(JwtDecoder.isExpired(token(<String, Object?>{'exp': '1700000000'})),
          isTrue);
      expect(JwtDecoder.isExpired(token(<String, Object?>{'exp': 1e20})), isTrue);
    });

    test('exp كسريّ مقبول — NumericDate في المعيار قد يكون كسراً', () {
      final double future = epoch(now.add(const Duration(days: 1))) + 0.5;
      expect(JwtDecoder.isExpired(token(<String, Object?>{'exp': future})),
          isFalse);
    });
  });

  group('التواريخ', () {
    test('getExpirationDate: اللحظة نفسها، بالتوقيت المحلّيّ كما في الحزمة', () {
      final DateTime date = JwtDecoder.getExpirationDate(
        token(<String, Object?>{'exp': 1700000000}),
      );
      expect(date.millisecondsSinceEpoch, 1700000000 * 1000);
      expect(date.isUtc, isFalse);
    });

    test('getRemainingTime موجبةٌ قبل الانتهاء وسالبةٌ بعده', () {
      expect(JwtDecoder.getRemainingTime(valid).inDays, greaterThanOrEqualTo(6));
      expect(JwtDecoder.getRemainingTime(expired).isNegative, isTrue);
    });

    test('getTokenTime: المنقضي منذ iat', () {
      expect(JwtDecoder.getTokenTime(valid).inMinutes, inInclusiveRange(4, 6));
    });

    test('غيابُ الحقل يرمي FormatException — لا NoSuchMethodError ولا TypeError', () {
      final String bare = token(<String, Object?>{'sub': '1'});
      expect(() => JwtDecoder.getExpirationDate(bare), throwsFormatException);
      expect(() => JwtDecoder.getRemainingTime(bare), throwsFormatException);
      expect(() => JwtDecoder.getTokenTime(bare), throwsFormatException);
    });
  });
}
