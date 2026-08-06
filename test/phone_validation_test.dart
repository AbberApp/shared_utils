import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

import 'phone_examples.g.dart';

/// اختبار شامل لتحقّق أرقام الهاتف: كل دولة برقم مثال حقيقي من Google
/// libphonenumber (نفس مرجع واتساب) وبمعايير طول الرقم الخاصة بها.
void main() {
  final countries = IntlPhoneUtils.countries;

  group('كل دولة تقبل رقمها الحقيقي (libphonenumber example)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue; // إقليم غير مأهول بلا بيانات libphonenumber
      test('${country.code} (+${country.dialCode}) يقبل $example', () {
        final result = IntlPhoneUtils.validatePhone(example, country: country);
        expect(
          result.isValid,
          isTrue,
          reason:
              '${country.code} رفض رقمه الحقيقي $example — الأطوال الممكنة: '
              '${IntlPhoneUtils.possibleLengthsFor(country)}',
        );
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
        final result = IntlPhoneUtils.validatePhone(bad, country: country);
        expect(
          result.isValid,
          isFalse,
          reason: '${country.code} قَبِل خطأً رقماً أطول: $bad',
        );
      });
    }
  });

  group('حالات التراجع (regressions)', () {
    test('بريطانيا +44 7799461648 صالح (كان يُرفض كـ«غيرنزي»)', () {
      final gb = IntlPhoneUtils.getCountryByCode('GB');
      expect(
        IntlPhoneUtils.validatePhone('+447799461648', country: gb).isValid,
        isTrue,
      );
      // حتى بدون تمرير الدولة: يُحسم لبريطانيا (الدولة الرئيسية لـ44) لا غيرنزي.
      expect(IntlPhoneUtils.validatePhone('+447799461648').isValid, isTrue);
    });

    test('إيطاليا رمزها 39 (كانت 41 خطأً) وتتحقق صحيحاً', () {
      final it = IntlPhoneUtils.getCountryByCode('IT');
      expect(it.dialCode, '39');
      expect(
        IntlPhoneUtils.validatePhone(kExampleNumbers['IT']!, country: it).isValid,
        isTrue,
      );
    });

    test('السعودية +9665XXXXXXXX (٩ أرقام) صالح', () {
      final sa = IntlPhoneUtils.getCountryByCode('SA');
      expect(IntlPhoneUtils.validatePhone('+966512345678', country: sa).isValid, isTrue);
      expect(IntlPhoneUtils.validatePhone('+96651234567', country: sa).isValid, isFalse);
    });

    test('لا وجود لدولة مكرّرة (البحرين مرة واحدة)', () {
      final bh = countries.where((c) => c.code == 'BH');
      expect(bh.length, 1);
    });
  });
}
