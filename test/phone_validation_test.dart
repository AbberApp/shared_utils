import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

import 'phone_examples.g.dart';

/// اختبار معماريّ شامل لتحقّق أرقام الهاتف — مصدر الحقيقة الوحيد
/// [IntlPhoneUtils]: التحقّق النمطيّ الكامل عبر Google libphonenumber
/// (`phone_numbers_parser`) + بيانات الأطوال + بوّابة الفشل-المفتوح.
///
/// يُختبر **كل دولة على انفراد تام** برقم مثال حقيقي من libphonenumber.
void main() {
  final countries = IntlPhoneUtils.countries;

  group('كل دولة تقبل رقمها الحقيقي (تحقّق نمطيّ libphonenumber)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue; // إقليم غير مأهول بلا بيانات
      test('${country.code} (+${country.dialCode}) يقبل $example', () {
        final result = IntlPhoneUtils.validatePhone(example, country: country);
        expect(
          result.isValid,
          isTrue,
          reason: '${country.code} رفض رقمه الحقيقي $example',
        );
      });
    }
  });

  group('كل دولة: رقمها الحقيقي «معقول» (بوّابة الفشل-المفتوح لا تحجبه)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue;
      test('${country.code} plausible', () {
        expect(IntlPhoneUtils.isPlausiblePhone(example, country: country), isTrue);
      });
    }
  });

  group('طول السعة صحيح لكل دولة (لا يطلب أطول من الحقيقي)', () {
    for (final country in countries) {
      final example = kExampleNumbers[country.code];
      if (example == null) continue;
      final lengths = IntlPhoneUtils.possibleLengthsFor(country);
      if (lengths == null || lengths.isEmpty) continue;
      final int nsnLen = example.substring(country.dialCode.length + 1).length;
      final int cap = lengths.reduce((a, b) => a > b ? a : b);
      test('${country.code}: السعة $cap تتّسع لطوله الحقيقي $nsnLen', () {
        expect(IntlPhoneUtils.getExactLength(example, country: country), cap);
        expect(nsnLen <= cap, isTrue);
        expect(lengths.contains(nsnLen), isTrue);
      });
    }
  });

  group('كل دولة ترفض رقماً قصيراً جدًّا (رقم واحد)', () {
    for (final country in countries) {
      if (kExampleNumbers[country.code] == null) continue;
      test('${country.code} يرفض رقماً من خانة واحدة', () {
        final bad = '+${country.dialCode}9';
        expect(IntlPhoneUtils.validatePhone(bad, country: country).isValid, isFalse);
      });
    }
  });

  group('حالات التراجع (regressions)', () {
    test('السعودية: جوّال ٩ أرقام صالح، و١٠ أرقام (ليس جوّالاً) مرفوض', () {
      final sa = IntlPhoneUtils.getCountryByCode('SA');
      expect(IntlPhoneUtils.validatePhone('+966531196112', country: sa).isValid, isTrue);
      expect(IntlPhoneUtils.getExactLength('+966531196112', country: sa), 9);
      expect(IntlPhoneUtils.validatePhone('+9665311961123', country: sa).isValid, isFalse);
      // بوّابة الفشل-المفتوح: الرقم الصحيح دائماً معقول.
      expect(IntlPhoneUtils.isPlausiblePhone('+966531196112', country: sa), isTrue);
    });

    test('بريطانيا +44 7799461648 صالح (كان يُرفض كـ«غيرنزي»)', () {
      final gb = IntlPhoneUtils.getCountryByCode('GB');
      expect(IntlPhoneUtils.validatePhone('+447799461648', country: gb).isValid, isTrue);
      expect(IntlPhoneUtils.validatePhone('+447799461648').isValid, isTrue);
    });

    test('إيطاليا رمزها 39 (كانت 41 خطأً) ورقمها الحقيقي صالح', () {
      final it = IntlPhoneUtils.getCountryByCode('IT');
      expect(it.dialCode, '39');
      expect(IntlPhoneUtils.validatePhone(kExampleNumbers['IT']!, country: it).isValid, isTrue);
    });

    test('ألمانيا (متعددة الأطوال): رقمها الحقيقي صالح والسعة تشمل >1 طول', () {
      final de = IntlPhoneUtils.getCountryByCode('DE');
      expect(IntlPhoneUtils.possibleLengthsFor(de)!.length > 1, isTrue);
      expect(IntlPhoneUtils.validatePhone(kExampleNumbers['DE']!, country: de).isValid, isTrue);
    });

    test('لا وجود لدولة مكرّرة (البحرين مرة واحدة)', () {
      expect(countries.where((c) => c.code == 'BH').length, 1);
    });
  });
}
