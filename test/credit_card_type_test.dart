// التطبيقات تكتب `CreditCardType.visa()` بلا const، وعلى ذلك يُختبر هنا. ولا
// يُكتب `const CreditCardType.visa()` أصلاً: المُنشئان factory لا const، كي لا
// تُطلق عليهما `prefer_const_constructors` المفعّلة في التطبيقات.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `detectCCType` و`CreditCardType` — البديل المحلّيّ لحزمة
/// `credit_card_type_detector`.
///
/// يحرس ثلاثة أمور: **تطابقَ التواقيع** مع الحزمة كي لا يُمسّ سطرٌ في
/// `payment_helper.dart`، و**صحّةَ `contains`** بمساواة القيمة، و**المديين
/// بأطرافهما** — فخطأٌ بخانةٍ يوجّه بطاقةً إلى بوّابةٍ لا تقبلها فتُرفض.
void main() {
  final CreditCardType visa = CreditCardType.visa();
  final CreditCardType mastercard = CreditCardType.mastercard();

  /// ما تفعله التطبيقات بعد فحص مدى، حرفياً من `payment_helper.dart`.
  String brandOf(String cardNumber) {
    final String sanitizedNumber = cardNumber.replaceAll(RegExp(r'\s+|-'), '');
    final List<CreditCardType> types = detectCCType(sanitizedNumber);
    if (types.contains(CreditCardType.visa())) return 'VISA';
    if (types.contains(CreditCardType.mastercard())) return 'MASTER';
    return '';
  }

  group('تواقيع الحزمة — لا يجوز أن تنحرف', () {
    test('detectCCType دالّةٌ عليا تأخذ String وتُرجع List<CreditCardType>', () {
      // إسنادٌ إلى نوعٍ صريح: لو تغيّر التوقيع لما صُرّف هذا الملفّ.
      final List<CreditCardType> Function(String) detect = detectCCType;
      expect(detect('4111111111111111'), <CreditCardType>[visa]);
    });

    test('كلُّ مُنشئٍ يعيد نسخةً واحدة، و type بقيمة الحزمة نفسها', () {
      expect(identical(CreditCardType.visa(), visa), isTrue);
      expect(identical(CreditCardType.mastercard(), mastercard), isTrue);
      expect(visa.type, 'visa');
      expect(mastercard.type, 'mastercard');
      expect(visa.toString(), 'CreditCardType.visa()');
      expect(mastercard.toString(), 'CreditCardType.mastercard()');
    });
  });

  group('المساواة بالقيمة — عليها يقوم contains', () {
    test('استدعاءان مستقلّان متساويان، وفي Set عنصرٌ واحد', () {
      final CreditCardType a = CreditCardType.visa();
      final CreditCardType b = CreditCardType.visa();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(<CreditCardType>{a, b, visa}, hasLength(1));
    });

    test('فيزا لا تساوي ماستركارد', () {
      expect(visa == mastercard, isFalse);
      expect(mastercard == visa, isFalse);
    });

    test('types.contains(CreditCardType.visa()) كما تكتبه التطبيقات', () {
      final List<CreditCardType> types = detectCCType('4242424242424242');
      expect(types.contains(CreditCardType.visa()), isTrue);
      expect(types.contains(CreditCardType.mastercard()), isFalse);
    });
  });

  group('أرقام الاختبار المنشورة', () {
    test('فيزا', () {
      for (final String n in <String>[
        '4242424242424242',
        '4111111111111111',
        '4012888888881881',
        '4000056655665556',
        '4222222222222', // ثلاث عشرة خانة
      ]) {
        expect(detectCCType(n), <CreditCardType>[visa], reason: n);
      }
    });

    test('ماستركارد — السلسلة 5 والسلسلة 2', () {
      for (final String n in <String>[
        '5555555555554444',
        '5200828282828210',
        '5105105105105100',
        '5454545454545454',
        '2223003122003222',
      ]) {
        expect(detectCCType(n), <CreditCardType>[mastercard], reason: n);
      }
    });

    test('العلامات الأخرى ← قائمةٌ فارغة، فتُرجع التطبيقات «»', () {
      for (final String n in <String>[
        '378282246310005', // American Express
        '6011111111111117', // Discover
        '3530111333300000', // JCB
        '3056930009020004', // Diners Club
        '6200000000000005', // UnionPay
      ]) {
        expect(detectCCType(n), isEmpty, reason: n);
        expect(brandOf(n), '', reason: n);
      }
    });
  });

  group('أطراف مدى ماستركارد: 51–55 و2221–2720', () {
    test('السلسلة 2: 2220 لا، 2221 نعم، 2720 نعم، 2721 لا', () {
      expect(detectCCType('2220999999999999'), isEmpty);
      expect(detectCCType('2221000000000000'), <CreditCardType>[mastercard]);
      expect(detectCCType('2720999999999999'), <CreditCardType>[mastercard]);
      expect(detectCCType('2721000000000000'), isEmpty);
    });

    test('السلسلة 5: 50 لا، 51 نعم، 55 نعم، 56 لا', () {
      expect(detectCCType('5099999999999999'), isEmpty);
      expect(detectCCType('5100000000000000'), <CreditCardType>[mastercard]);
      expect(detectCCType('5599999999999999'), <CreditCardType>[mastercard]);
      expect(detectCCType('5600000000000000'), isEmpty);
    });

    test('كلُّ بادئةٍ رباعيّة: فيزا تبدأ بـ4، وماستركارد في مدييه، ولا علامتان', () {
      for (int i = 0; i < 10000; i++) {
        final String prefix = i.toString().padLeft(4, '0');
        final int two = i ~/ 100;
        final bool isVisa = prefix.startsWith('4');
        final bool isMastercard =
            (two >= 51 && two <= 55) || (i >= 2221 && i <= 2720);
        expect(
          detectCCType(prefix),
          <CreditCardType>[if (isVisa) visa, if (isMastercard) mastercard],
          reason: prefix,
        );
      }
    });

    test('البادئة القصيرة تُطابق إن حسمت العلامة أيّاً كان ما يليها — كالحزمة', () {
      expect(detectCCType('4'), <CreditCardType>[visa]);
      expect(detectCCType('23'), <CreditCardType>[mastercard]); // 2300–2399
      expect(detectCCType('223'), <CreditCardType>[mastercard]);
      expect(detectCCType('271'), <CreditCardType>[mastercard]);
      expect(detectCCType('5'), isEmpty); // 50 و56 خارجه
      expect(detectCCType('22'), isEmpty); // 2220 خارجه
      expect(detectCCType('222'), isEmpty);
      expect(detectCCType('27'), isEmpty); // 2721 خارجه
      expect(detectCCType('272'), isEmpty);
    });
  });

  group('تطبيع الرقم', () {
    test('المسافات والشرطات تُحذف أينما وقعت', () {
      for (final String n in <String>[
        '4111 1111 1111 1111',
        '4111-1111-1111-1111',
        '4111 - 1111 - 1111 - 1111',
        '  4111111111111111  ', // مسافتان في الآخر: كانت الحزمة تُفلت الثانية
        '4111\t1111\n1111 1111', // جدولة وسطرٌ ومسافةٌ غير فاصلة
      ]) {
        expect(detectCCType(n), <CreditCardType>[visa], reason: '«$n»');
      }
      expect(detectCCType('5555 5555-5555 4444'), <CreditCardType>[mastercard]);
    });

    test('النصّ الفارغ — أو ما ليس فيه إلّا فواصل — قائمةٌ فارغة بلا رمي', () {
      // كانت الحزمة تُرجع العلامات كلّها هنا، فيُصنَّف الحقل الفارغ فيزا.
      for (final String n in <String>['', ' ', '   ', '-', '- -']) {
        expect(detectCCType(n), isEmpty, reason: '«$n»');
        expect(brandOf(n), '', reason: '«$n»');
      }
    });

    test('غير الرقميّ قائمةٌ فارغة بلا رمي', () {
      for (final String n in <String>[
        'abcd',
        '4111a111',
        'a4111111',
        '+4111111111111111',
        '4111.1111',
        '4111_1111',
        '٤١١١١١١١١١١١١١١١', // خاناتٌ عربيّة — كالحزمة
        '411111١١',
      ]) {
        expect(detectCCType(n), isEmpty, reason: '«$n»');
      }
    });

    test('رقمٌ طويلٌ جدّاً لا يرمي: المقارنة نصّيّة لا int.parse', () {
      expect(detectCCType('4${'0' * 500}'), <CreditCardType>[visa]);
      expect(detectCCType('2720${'9' * 500}'), <CreditCardType>[mastercard]);
    });
  });

  group('مسار التطبيقات كما هو', () {
    test('ستّ إلى ثماني خانات من حقلٍ منسَّق بالمسافات', () {
      // الحقل لا يستدعي الكشف قبل ستّ خانات، ويقصّ ما بعد الثامنة.
      expect(brandOf('424242'), 'VISA');
      expect(brandOf('4242 4242'), 'VISA');
      expect(brandOf('555555'), 'MASTER');
      expect(brandOf('2223 0031'), 'MASTER');
      expect(brandOf('222099'), '');
      expect(brandOf('272100'), '');
      expect(brandOf('378282'), '');
    });
  });
}
