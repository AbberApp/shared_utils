import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

import 'phone_examples.g.dart';

/// اختبار معماريّ شامل لتحقّق أرقام الهاتف — مصدر الحقيقة الوحيد
/// [IntlPhoneUtils] المدعوم ببيانات Google libphonenumber (نوع MOBILE).
///
/// يُختبر **كل دولة على انفراد تام** برقم جوّال مثال حقيقي من libphonenumber:
///   1) صحّة الرقم (الواجهة تشتقّ «الاكتمال» من هذه الصحّة).
///   2) طول الرقم ضمن الأطوال الممكنة، والسعة (getExactLength) تتّسع له.
///   3) رفض الأطوال خارج المسموح.
void main() {
  final countries = IntlPhoneUtils.countries;

  group('كل دولة تقبل رقم جوّالها الحقيقي (libphonenumber MOBILE)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue; // إقليم غير مأهول بلا بيانات
      test('${country.code} (+${country.dialCode}) يقبل $example', () {
        final result = IntlPhoneUtils.validatePhone(example, country: country);
        expect(
          result.isValid,
          isTrue,
          reason: '${country.code} رفض جوّاله الحقيقي $example — '
              'الأطوال الممكنة ${IntlPhoneUtils.possibleLengthsFor(country)}',
        );
      });
    }
  });

  group('طول الاكتمال/السعة صحيح لكل دولة (لا يطلب أطول من الحقيقي)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue;
      final lengths = IntlPhoneUtils.possibleLengthsFor(country);
      if (lengths == null || lengths.isEmpty) continue;
      final int nsnLen = example.substring(country.dialCode.length + 1).length;
      final int cap = lengths.reduce((a, b) => a > b ? a : b);
      test('${country.code}: السعة $cap تتّسع لطوله الحقيقي $nsnLen', () {
        final exact = IntlPhoneUtils.getExactLength(example, country: country);
        expect(exact, cap, reason: '${country.code} سعة غير متوقّعة');
        // الطول الحقيقي لا يتجاوز السعة (فلا يُقصّ الإدخال) وهو طولٌ صالح.
        expect(nsnLen <= cap, isTrue);
        expect(lengths.contains(nsnLen), isTrue);
      });
    }
  });

  group('كل دولة ترفض رقماً أطول من المسموح', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue;
      final lengths = IntlPhoneUtils.possibleLengthsFor(country);
      if (lengths == null || lengths.isEmpty) continue;
      final int maxLen = lengths.reduce((a, b) => a > b ? a : b);
      test('${country.code} يرفض رقماً بطول ${maxLen + 1}', () {
        final bad = '+${country.dialCode}${'9' * (maxLen + 1)}';
        expect(
          IntlPhoneUtils.validatePhone(bad, country: country).isValid,
          isFalse,
        );
      });
    }
  });

  group('حالات التراجع (regressions)', () {
    test('السعودية: جوّال ٩ أرقام صالح وسعته ٩ (لا ١٠)', () {
      final sa = IntlPhoneUtils.getCountryByCode('SA');
      expect(IntlPhoneUtils.possibleLengthsFor(sa), [9]);
      expect(IntlPhoneUtils.getExactLength('+966531196112', country: sa), 9);
      expect(IntlPhoneUtils.validatePhone('+966531196112', country: sa).isValid, isTrue);
      // رقم ١٠ أرقام سعوديّ ليس جوّالاً → مرفوض.
      expect(IntlPhoneUtils.validatePhone('+9665311961123', country: sa).isValid, isFalse);
    });

    test('بريطانيا +44 7799461648 صالح (كان يُرفض كـ«غيرنزي»)', () {
      final gb = IntlPhoneUtils.getCountryByCode('GB');
      expect(IntlPhoneUtils.validatePhone('+447799461648', country: gb).isValid, isTrue);
      expect(IntlPhoneUtils.validatePhone('+447799461648').isValid, isTrue);
    });

    test('إيطاليا رمزها 39 (كانت 41 خطأً) وتتحقق صحيحاً', () {
      final it = IntlPhoneUtils.getCountryByCode('IT');
      expect(it.dialCode, '39');
      expect(IntlPhoneUtils.validatePhone(kExampleNumbers['IT']!, country: it).isValid, isTrue);
    });

    test('دول متعددة أطوال الجوّال: كلا الطولين صالح (ألمانيا 10 و11)', () {
      final de = IntlPhoneUtils.getCountryByCode('DE');
      final lengths = IntlPhoneUtils.possibleLengthsFor(de)!;
      expect(lengths.length > 1, isTrue);
      for (final n in lengths) {
        final num = '+${de.dialCode}${'1' * n}';
        expect(
          IntlPhoneUtils.validatePhone(num, country: de).isValid,
          isTrue,
          reason: 'ألمانيا رفضت طولاً صالحاً $n',
        );
      }
    });

    test('لا وجود لدولة مكرّرة (البحرين مرة واحدة)', () {
      expect(countries.where((c) => c.code == 'BH').length, 1);
    });
  });
}
