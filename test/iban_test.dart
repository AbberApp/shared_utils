import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار [IbanUtils] و[IbanFormatter] — خوارزمية MOD-97 (ISO 7064)
/// وجدول أطوال الدول (ISO 13616).
///
/// كلّ آيبان في `kValidIbans` رُقّم بخوارزمية MOD-97 خارج المكتبة (بايثون)
/// قبل كتابة الاختبار، فباقي قسمته على ٩٧ يساوي ١ فعلاً — لا نبارك ناتج
/// المكتبة بناتجها.

/// آيبانات حقيقية صحيحة: الرمز → الآيبان (بلا مسافات) مع طوله المعياري.
const Map<String, List<String>> kValidIbans = {
  'SA': [
    'SA0380000000608010167519',
    'SA4420000001234567891234',
    'SA2945000000123456789012',
  ],
  'AE': ['AE070331234567890123456', 'AE940090000000001234567'],
  'EG': ['EG380019000500000000263180002'],
  'OM': ['OM810180000001299123456'],
  'BH': ['BH67BMAG00001299123456'],
  'KW': ['KW81CBKU0000000000001234560101'],
  'JO': ['JO94CBJO0010000000000131000302'],
  'QA': ['QA58DOHB00001234567890ABCDEFG'],
  'IQ': ['IQ98NBIQ850123456789012'],
  'PS': ['PS92PALS000000000400123456702'],
  'LB': ['LB62099900000001001901229114'],
  'GB': ['GB82WEST12345698765432'],
  'DE': ['DE89370400440532013000'],
  'FR': ['FR1420041010050500013M02606'],
  'TR': ['TR330006100519786457841326'],
  'NO': ['NO9386011117947'],
  'MT': ['MT84MALT011000012345MTLCAST001S'],
  'RU': ['RU0204452560040702810412345678901'],
};

/// عيّنة من جدول ISO 13616: الرمز → الطول المتوقّع.
const Map<String, int> kExpectedLengths = {
  'SA': 24,
  'AE': 23,
  'EG': 29,
  'OM': 23,
  'BH': 22,
  'KW': 30,
  'JO': 30,
  'QA': 29,
  'IQ': 23,
  'PS': 29,
  'LB': 28,
  'GB': 22,
  'DE': 22,
  'FR': 27,
  'TR': 26,
  'NO': 15, // الأقصر في الجدول
  'MT': 31,
  'RU': 33, // الأطول في الجدول
};

String _rawOf(TextEditingValue value) => value.text.replaceAll(' ', '');

TextEditingValue _tev(String text, [int? offset]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: offset ?? text.length),
);

TextEditingValue _format(String typed, {String previous = ''}) =>
    IbanFormatter().formatEditUpdate(_tev(previous), _tev(typed));

void main() {
  group('IbanUtils.isValid — آيبانات حقيقية صحيحة تمرّ MOD-97', () {
    kValidIbans.forEach((code, ibans) {
      for (final iban in ibans) {
        test('$code: $iban صالح', () {
          expect(IbanUtils.isValid(iban), isTrue, reason: '$iban رُفض وهو صحيح');
        });
      }
    });

    test('الآيبان الصحيح يبقى صحيحاً منسّقاً بمسافات أو بأحرف صغيرة', () {
      const iban = 'SA0380000000608010167519';
      expect(IbanUtils.isValid(IbanUtils.format(iban)), isTrue);
      expect(IbanUtils.isValid(iban.toLowerCase()), isTrue);
      expect(IbanUtils.isValid('  SA03 8000 0000 6080 1016 7519  '), isTrue);
    });
  });

  group('IbanUtils.isValid — خانة التحقّق المغلوطة مرفوضة', () {
    // لكلّ آيبان صحيح: كلّ خانة تحقّق رقميّة أخرى تُرفض. تُستثنى
    // الخانة المكافئة حسابياً (± ٩٧) لأنّ المعيار يمنعها بقاعدة المدى
    // ٠٢..٩٨ لا بحساب MOD-97 — وهي موضع العيب المعلَّم بـ skip أدناه.
    kValidIbans.forEach((code, ibans) {
      for (final iban in ibans) {
        test('$code: كل خانة تحقّق بديلة مرفوضة', () {
          final correct = int.parse(iban.substring(2, 4));
          final body = iban.substring(4);
          for (int i = 0; i < 100; i++) {
            if ((i - correct) % 97 == 0) continue; // الصحيحة أو مكافئتها
            final mutated = '$code${i.toString().padLeft(2, '0')}$body';
            expect(
              IbanUtils.isValid(mutated),
              isFalse,
              reason: '$mutated خانة تحقّقه مغلوطة ومع ذلك قُبل',
            );
          }
        });
      }
    });

    test('تبديل رقمين متجاورين في الجسم يُفسد MOD-97', () {
      // MOD-97 يلتقط التبديل (transposition) وهو أشيع خطأ نسخٍ يدويّ.
      expect(IbanUtils.isValid('SA0380000000608010165719'), isFalse);
      expect(IbanUtils.isValid('AE070331234567890123465'), isFalse);
    });

    test('تغيير رقم واحد في الجسم يُفسد MOD-97', () {
      expect(IbanUtils.isValid('SA0380000000608010167518'), isFalse);
      expect(IbanUtils.isValid('EG380019000500000000263180003'), isFalse);
    });
  });

  group('IbanUtils.isValid — الطول', () {
    test('الطول الناقص أو الزائد بمحرف واحد مرفوض', () {
      const iban = 'SA0380000000608010167519';
      expect(IbanUtils.isValid(iban.substring(0, iban.length - 1)), isFalse);
      expect(IbanUtils.isValid('${iban}0'), isFalse);
    });

    test('الفارغ والمسافات وحدها والأقصر من خمسة محارف مرفوضة', () {
      expect(IbanUtils.isValid(''), isFalse);
      expect(IbanUtils.isValid('   '), isFalse);
      expect(IbanUtils.isValid('S'), isFalse);
      expect(IbanUtils.isValid('SA'), isFalse);
      expect(IbanUtils.isValid('SA03'), isFalse);
      expect(IbanUtils.isValid('SA038'), isFalse);
    });

    test('مُدخل طويل جدّاً (٤٠٠ محرف) مرفوض بلا انفجار', () {
      expect(IbanUtils.isValid('SA03' * 100), isFalse);
      expect(IbanUtils.isValid('SA03${'0' * 5000}'), isFalse);
    });

    test('أقصر آيبان (النرويج ١٥) وأطوله (روسيا ٣٣) كلاهما مقبول', () {
      expect(IbanUtils.isValid('NO9386011117947'), isTrue);
      expect(IbanUtils.isValid('RU0204452560040702810412345678901'), isTrue);
    });
  });

  group('IbanUtils.isValid — رمز الدولة', () {
    test('رمز دولة غير مدعوم مرفوض ولو كان الطول والتحقّق سليمين', () {
      expect(IbanUtils.isValid('ZZ0380000000608010167519'), isFalse);
      expect(IbanUtils.isValid('US0380000000608010167519'), isFalse);
    });

    test('رمز دولة رقميّ أو مختلط مرفوض', () {
      expect(IbanUtils.isValid('1203800000006080101675'), isFalse);
      expect(IbanUtils.isValid('S103800000006080101675'), isFalse);
      expect(IbanUtils.isValid('12345678901234567890'), isFalse);
    });

    test('نصّ عربيّ خالص مرفوض', () {
      expect(IbanUtils.isValid('مرحبا'), isFalse);
      expect(IbanUtils.isValid('رقم الحساب المصرفي الدولي'), isFalse);
    });
  });

  group('IbanUtils.isValid — مُدخل مشوّه', () {
    test(
      'الواصلة داخل آيبان بطولٍ صحيح تُرفض لا أن تُفجّر استثناءً',
      () {
        // طوله ٢٤ (طول السعودية) لكنّ فيه محرفاً غير أبجديّ-رقميّ.
        expect(IbanUtils.isValid('SA038000000060801016751-'), isFalse);
        expect(IbanUtils.isValid('SA03800000006080101675.9'), isFalse);
        expect(IbanUtils.isValid('SA03800000006080101675/9'), isFalse);
      },
    );

    test(
      'الأرقام العربية-الهندية تُرفض لا أن تُفجّر استثناءً',
      () {
        // ٢٤ محرفاً: رمز الدولة + خانتا تحقّق بأرقام عربية + الجسم.
        expect(IbanUtils.isValid('SA٠٣80000000608010167519'), isFalse);
      },
    );

    test(
      'الرموز التعبيرية داخل آيبان بطولٍ صحيح تُرفض لا أن تُفجّر استثناءً',
      () {
        expect(IbanUtils.isValid('SA03800000006080101675\u{1F642}'), isFalse);
      },
    );

    test(
      'خانتا التحقّق يجب أن تكونا رقمين لا حرفين (ISO 13616)',
      () {
        // 'NZ' في موضع خانتَي التحقّق يمرّ حساب MOD-97 صدفةً،
        // لكنّ المعيار يحصر الموضعين ٣-٤ في الأرقام.
        expect(IbanUtils.isValid('SANZ80000000608010167519'), isFalse);
        expect(IbanUtils.isValid('SAOW80000000608010167519'), isFalse);
      },
    );

    test(
      'خانتا التحقّق ٠٠ و٠١ و٩٩ ممنوعة بالمعيار ولو مرّت حساب MOD-97',
      () {
        // ISO 7064 يولّد خانة التحقّق بـ (٩٨ − الباقي)، فمداها ٠٢..٩٨؛
        // و٠٠/٠١/٩٩ لا تنتجها الخوارزمية قطّ. لكنّ الباقي دوريّ بـ ٩٧،
        // فالخانة الصحيحة dd ومكافئتها dd±٩٧ كلتاهما تعطيان باقياً ١:
        // IQ98 ↔ IQ01، وRU02 ↔ RU99، وSA97 ↔ SA00.
        expect(IbanUtils.isValid('IQ01NBIQ850123456789012'), isFalse);
        expect(
          IbanUtils.isValid('RU9904452560040702810412345678901'),
          isFalse,
        );
        expect(IbanUtils.isValid('SA0000000000000000000083'), isFalse);
      },
    );

    test(
      'المسافة غير الفاصلة (NBSP) من اللصق لا تُبطل آيباناً صحيحاً',
      () {
        const nbsp = ' ';
        const iban =
            'SA03${nbsp}8000${nbsp}0000${nbsp}6080${nbsp}1016${nbsp}7519';
        expect(IbanUtils.isValid(iban), isTrue);
        expect(IbanUtils.isValid('SA0380000000608010167519\n'), isTrue);
        expect(IbanUtils.isValid('SA03\t8000\t0000\t6080\t1016\t7519'), isTrue);
      },
    );

    test('جنوب السودان (SS) خارج سجلّ ISO 13616 وإن صحّ رمزها في ISO 3166', () {
      // SS رمزُ دولةٍ صالح في ISO 3166-1، لكنّ سجلّ IBAN لا يحمل لها صيغةً
      // ولا طولاً — فلا آيبان لجنوب السودان أصلاً. إدراجها بطولٍ مخترَع
      // يجعل isValid يقبل آيبانات لا وجود لها، وهو أسوأ من رفضها.
      // المدرَجة هي السودان (SD) بطول ١٨، ولا تُخلط بها.
      expect(IbanUtils.isSupportedCountry('SS'), isFalse);
      expect(IbanUtils.expectedLength('SS'), isNull);
      expect(IbanUtils.isSupportedCountry('SD'), isTrue);
      expect(IbanUtils.expectedLength('SD'), 18);
    });
  });

  group('IbanUtils.strip', () {
    test('يحذف المسافات ويرفع الحروف', () {
      expect(IbanUtils.strip('SA03 8000 0000 6080 1016 7519'),
          'SA0380000000608010167519');
      expect(IbanUtils.strip('  sa03 8000  '), 'SA038000');
      expect(IbanUtils.strip('sa03'), 'SA03');
    });

    test('الفارغ يبقى فارغاً، والمسافات وحدها تصير فارغاً', () {
      expect(IbanUtils.strip(''), '');
      expect(IbanUtils.strip('     '), '');
    });

    test('يحذف كلّ الفراغات لا المسافة ASCII وحدها', () {
      // الآيبان الملصوق من صفحة بنكٍ أو PDF يحمل مسافةً غير فاصلة أو
      // ضيّقة أو جدولةً أو سطراً جديداً أو علامة اتجاه — وكلّها تُحذف.
      expect(IbanUtils.strip('SA03\u00A08000'), 'SA038000');
      expect(IbanUtils.strip('SA03\t8000'), 'SA038000');
      expect(IbanUtils.strip('SA03\u202F8000'), 'SA038000');
      expect(IbanUtils.strip('SA03\n8000'), 'SA038000');
      expect(IbanUtils.strip('SA03\u200F8000'), 'SA038000');
    });

    test('لا يحذف المحارف غير البيضاء ولا يمسّ العربية', () {
      expect(IbanUtils.strip('SA03-8000'), 'SA03-8000');
      expect(IbanUtils.strip('مرحبا'), 'مرحبا');
    });

    test('مُطبِّق على نفسه (idempotent)', () {
      const iban = 'SA03 8000 0000 6080 1016 7519';
      expect(IbanUtils.strip(IbanUtils.strip(iban)), IbanUtils.strip(iban));
    });
  });

  group('IbanUtils.format', () {
    test('مسافة كل أربعة محارف بلا مسافة في الطرفين', () {
      expect(IbanUtils.format('SA0380000000608010167519'),
          'SA03 8000 0000 6080 1016 7519');
      expect(IbanUtils.format('NO9386011117947'), 'NO93 8601 1117 947');
    });

    test('الطول من مضاعفات الأربعة لا يُذيَّل بمسافة', () {
      final formatted = IbanUtils.format('A' * 12);
      expect(formatted, 'AAAA AAAA AAAA');
      expect(formatted.endsWith(' '), isFalse);
    });

    test('يعيد تنسيق المنسَّق مسبقاً (idempotent)', () {
      const iban = 'SA03 8000 0000 6080 1016 7519';
      expect(IbanUtils.format(iban), iban);
      expect(IbanUtils.format(IbanUtils.format(iban)), iban);
    });

    test('يرفع الحروف ويوحّد المسافات العشوائية', () {
      expect(IbanUtils.format('sa038000'), 'SA03 8000');
      expect(IbanUtils.format('s a 0 3 8 0 0 0'), 'SA03 8000');
    });

    test('الفارغ والأقصر من أربعة لا يكتسبان مسافات', () {
      expect(IbanUtils.format(''), '');
      expect(IbanUtils.format('   '), '');
      expect(IbanUtils.format('S'), 'S');
      expect(IbanUtils.format('SA0'), 'SA0');
      expect(IbanUtils.format('SA03'), 'SA03');
    });

    test('لا يقصّ المُدخل مهما طال (التنسيق ليس تحقّقاً)', () {
      final long = IbanUtils.format('9' * 100);
      expect(long.replaceAll(' ', '').length, 100);
    });

    test('format ثمّ strip يعيد الأصل النقيّ', () {
      for (final ibans in kValidIbans.values) {
        for (final iban in ibans) {
          expect(IbanUtils.strip(IbanUtils.format(iban)), iban);
        }
      }
    });
  });

  group('IbanUtils.isSupportedCountry', () {
    test('يقبل الرمز بأيّ حالة أحرف', () {
      expect(IbanUtils.isSupportedCountry('SA'), isTrue);
      expect(IbanUtils.isSupportedCountry('sa'), isTrue);
      expect(IbanUtils.isSupportedCountry('sA'), isTrue);
    });

    test('كل رمز في عيّنة الجدول مدعوم', () {
      for (final code in kExpectedLengths.keys) {
        expect(IbanUtils.isSupportedCountry(code), isTrue, reason: code);
      }
    });

    test('الدول بلا نظام IBAN مرفوضة', () {
      expect(IbanUtils.isSupportedCountry('US'), isFalse);
      expect(IbanUtils.isSupportedCountry('CA'), isFalse);
      expect(IbanUtils.isSupportedCountry('ZZ'), isFalse);
    });

    test('الفارغ والمشوّه والعربيّ والطويل مرفوضة', () {
      expect(IbanUtils.isSupportedCountry(''), isFalse);
      expect(IbanUtils.isSupportedCountry('S'), isFalse);
      expect(IbanUtils.isSupportedCountry(' SA'), isFalse);
      expect(IbanUtils.isSupportedCountry('SA '), isFalse);
      expect(IbanUtils.isSupportedCountry('SAUDI'), isFalse);
      expect(IbanUtils.isSupportedCountry('السعودية'), isFalse);
      expect(IbanUtils.isSupportedCountry('12'), isFalse);
      expect(IbanUtils.isSupportedCountry('S' * 1000), isFalse);
    });
  });

  group('IbanUtils.expectedLength — عيّنة من جدول ISO 13616', () {
    kExpectedLengths.forEach((code, length) {
      test('$code طوله $length', () {
        expect(IbanUtils.expectedLength(code), length);
        expect(IbanUtils.expectedLength(code.toLowerCase()), length);
      });
    });

    test('الطول في الجدول يطابق طول الآيبان الحقيقيّ لكل دولة', () {
      kValidIbans.forEach((code, ibans) {
        for (final iban in ibans) {
          expect(
            iban.length,
            IbanUtils.expectedLength(code),
            reason: '$code: الجدول يخالف طول آيبانٍ حقيقيّ صالح',
          );
        }
      });
    });

    test('غير المدعوم والمشوّه يعيدان null', () {
      expect(IbanUtils.expectedLength('US'), isNull);
      expect(IbanUtils.expectedLength('ZZ'), isNull);
      expect(IbanUtils.expectedLength(''), isNull);
      expect(IbanUtils.expectedLength('S'), isNull);
      expect(IbanUtils.expectedLength('SAUDI'), isNull);
      expect(IbanUtils.expectedLength('السعودية'), isNull);
    });

    test('كل طولٍ في العيّنة بين ١٥ و٣٣', () {
      for (final code in kExpectedLengths.keys) {
        final length = IbanUtils.expectedLength(code)!;
        expect(length, greaterThanOrEqualTo(15));
        expect(length, lessThanOrEqualTo(33));
      }
    });
  });

  group('IbanFormatter — التنسيق أثناء الكتابة', () {
    test('هو TextInputFormatter فعلاً', () {
      expect(IbanFormatter(), isA<TextInputFormatter>());
    });

    test('يرفع الحروف ويُدرج مسافة كل أربعة محارف', () {
      expect(_format('sa0380000000608010167519').text,
          'SA03 8000 0000 6080 1016 7519');
      expect(_format('sa03').text, 'SA03');
      expect(_format('s').text, 'S');
    });

    test('يقبل اللصق المنسَّق مسبقاً بلا تكرار مسافات', () {
      expect(_format('SA03 8000 0000 6080 1016 7519').text,
          'SA03 8000 0000 6080 1016 7519');
    });

    test('المؤشّر يستقرّ في آخر النصّ المنسَّق', () {
      final result = _format('sa038000');
      expect(result.text, 'SA03 8000');
      expect(result.selection.baseOffset, result.text.length);
      expect(result.selection.isCollapsed, isTrue);
    });

    test('المؤشّر يتبع موضع التعديل لا يُقذف إلى آخر النصّ', () {
      // تصحيح رقمٍ في وسط الآيبان: المؤشّر يبقى بعد المحرف المُدرَج،
      // وإلّا كُتب ما بعده في آخر النصّ فتشوّه الآيبان صامتاً.
      final result = IbanFormatter().formatEditUpdate(
        _tev('SA03 8000', 9),
        _tev('SA039 8000', 5), // أُدرج '9' بعد المحرف الرابع
      );
      expect(result.text, 'SA03 9800 0');
      // خمسة محارف نقية قبل المؤشّر ومسافة واحدة قبلها ⇒ الإزاحة ٦
      expect(result.selection.baseOffset, 6);
      expect(result.selection.isCollapsed, isTrue);
    });

    test('المؤشّر قرب بداية النصّ لا يقفز إلى النهاية', () {
      final result = IbanFormatter().formatEditUpdate(
        _tev('A03 8000', 0),
        _tev('SA03 8000', 1),
      );
      expect(result.text, 'SA03 8000');
      expect(result.selection.baseOffset, 1);
    });

    test('الفارغ يبقى فارغاً ومؤشّره صفر', () {
      final result = _format('', previous: 'SA03');
      expect(result.text, isEmpty);
      expect(result.selection.baseOffset, 0);
    });

    test('يرفض المحارف غير الأبجدية-الرقمية فيُبقي القيمة السابقة', () {
      expect(_format('SA03-', previous: 'SA03').text, 'SA03');
      expect(_format('SA03#', previous: 'SA03').text, 'SA03');
      expect(_format('SA03م', previous: 'SA03').text, 'SA03');
      expect(_format('SA03\u{1F642}', previous: 'SA03').text, 'SA03');
    });

    test('يقصّ عند الطول المعياريّ لدولة الرمز المكتوب', () {
      for (final entry in kExpectedLengths.entries) {
        final overflow = '${entry.key}${'1' * 40}';
        expect(
          _rawOf(_format(overflow)).length,
          entry.value,
          reason: '${entry.key}: القصّ خالف طول الجدول',
        );
      }
    });

    test('رمز دولة غير مدعوم أو بداية رقمية تقصّ عند ٣٣ (الأقصى)', () {
      expect(_rawOf(_format('ZZ${'1' * 40}')).length, 33);
      expect(_rawOf(_format('1' * 40)).length, 33);
      expect(_rawOf(_format('${'9' * 2}${'1' * 100}')).length, 33);
    });

    test('لا يقصّ آيباناً حقيقياً كاملاً لأيّ دولة في العيّنة', () {
      kValidIbans.forEach((code, ibans) {
        for (final iban in ibans) {
          expect(_rawOf(_format(iban)), iban, reason: '$code قُصّ خطأً');
        }
      });
    });

    test('المخرَج يبقى صالحاً للتحقّق بعد التنسيق', () {
      const iban = 'SA0380000000608010167519';
      expect(IbanUtils.isValid(_format(iban).text), isTrue);
    });

    test('المسافات في المُدخَل تُلغى ثمّ يُعاد التجميع من الصفر', () {
      expect(_format('S A 0 3 8 0 0 0').text, 'SA03 8000');
      expect(_format('   ', previous: 'SA03').text, isEmpty);
    });

    test(
      'يحوّل الأرقام العربية-الهندية إلى إنجليزية كبقيّة منسّقات المكتبة',
      () {
        // convertArabicToEnglishNumbers تستعمله phone/card/number formatters؛
        // IbanFormatter وحده يهملها فيُسقط إدخال لوحة المفاتيح العربية صامتاً.
        expect(_format('SA٠٣', previous: 'SA').text, 'SA03');
      },
    );
  });
}
