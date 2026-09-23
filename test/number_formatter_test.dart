import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `lib/src/ui/formatters/number_formatter.dart`:
/// الدالّة `convertArabicToEnglishNumbers` ومنسّقا الإدخال المبنيّان عليها.
///
/// محوره الفاصلتان العربيّتان المتشابهتان بصرياً المختلفتان معنى:
/// `٫` (U+066B) فاصلة **عشرية**، و`٬` (U+066C) فاصلة **آلاف**؛ ومعهما
/// الفاصلة اللاتينية `,` التي تُخرجها `toCurrency` نفسها كفاصلة آلاف.
/// ثمّ سلوك المنسّقات عند اللصق، والحذف من المنتصف، وإدخال غير الرقميّ.
void main() {
  /// قيمةُ حقلٍ نصّية والمؤشّر عند `offset` (أو في آخر النصّ إن أُهمل).
  TextEditingValue v(String text, [int? offset]) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset ?? text.length),
      );

  group('convertArabicToEnglishNumbers — الأرقام', () {
    test('الأرقام العربية العشرة تتحوّل إلى نظيرها اللاتيني', () {
      expect(convertArabicToEnglishNumbers('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('النصّ الفارغ يبقى فارغاً', () {
      expect(convertArabicToEnglishNumbers(''), '');
    });

    test('الصفر وحده: ٠ تصير 0 لا نصّاً فارغاً', () {
      expect(convertArabicToEnglishNumbers('٠'), '0');
      expect(convertArabicToEnglishNumbers('٠٠٠'), '000');
    });

    test('الأرقام اللاتينية تمرّ كما هي (الدالّة idempotent)', () {
      const String latin = '1234567890';
      expect(convertArabicToEnglishNumbers(latin), latin);
      expect(
        convertArabicToEnglishNumbers(convertArabicToEnglishNumbers('٤٢')),
        '42',
      );
    });

    test('السالب: الإشارة تبقى والرقم يتحوّل', () {
      expect(convertArabicToEnglishNumbers('-٥'), '-5');
      expect(convertArabicToEnglishNumbers('−٥'), '−5'); // U+2212 يبقى كما هو
    });

    test('نصّ مختلط: الأرقام وحدها تتحوّل والحروف العربية تسلم', () {
      expect(
        convertArabicToEnglishNumbers('الطلب رقم ١٢٣ جاهز'),
        'الطلب رقم 123 جاهز',
      );
    });

    test('الفاصلة العربية `،` (U+060C) ليست فاصلة عدد فلا تُمَسّ', () {
      expect(convertArabicToEnglishNumbers('نعم، تمّ'), 'نعم، تمّ');
    });

    test('الفاصلة العشرية العربية `٫` تصير نقطة', () {
      expect(convertArabicToEnglishNumbers('١٢٫٥'), '12.5');
      expect(convertArabicToEnglishNumbers('٠٫٠٥'), '0.05');
    });

    test('نصّ بلا أرقام يعود كما هو', () {
      expect(convertArabicToEnglishNumbers('abc'), 'abc');
      expect(convertArabicToEnglishNumbers('لا أرقام هنا'), 'لا أرقام هنا');
    });

    test('مُدخل مشوّه: رموز ومسافات تبقى حول الأرقام المحوَّلة', () {
      expect(convertArabicToEnglishNumbers('  ١٢ ر.س  '), '  12 ر.س  ');
      expect(convertArabicToEnglishNumbers('##٧##'), '##7##');
    });

    test('مُدخل طويل جداً (٥٠٠٠ خانة) يتحوّل كاملاً بلا اقتطاع', () {
      final String long = '٩' * 5000;
      final String out = convertArabicToEnglishNumbers(long);
      expect(out.length, 5000);
      expect(out, '9' * 5000);
    });
  });

  group('convertArabicToEnglishNumbers — الفواصل', () {
    // ‏`٬` (U+066C) فاصلة آلاف: كانت تنجو من التحويل فتصل إلى المنسّق محرفاً
    // غير رقميّ فيُسقط اللصقة كلّها. صارت تُحذف كسائر فواصل الآلاف.
    test(
      'فاصلة الآلاف العربية `٬` تُزال: ١٬٢٣٤٬٥٦٧ ⇒ 1234567',
      () {
        expect(convertArabicToEnglishNumbers('١٬٢٣٤٬٥٦٧'), '1234567');
      },
    );

    test(
      'الفاصلتان معاً: ١٬٢٣٤٫٥٦ ⇒ 1234.56 (آلاف تُزال، عشرية تصير نقطة)',
      () {
        expect(convertArabicToEnglishNumbers('١٬٢٣٤٫٥٦'), '1234.56');
      },
    );

    // ‏الفاصلة اللاتينية `,` في هذه المكتبة فاصلةُ آلافٍ لا غير: `toCurrency`
    // تُخرج NumberFormat('#,##0.00','en_US'). فردّها نقطةً عشرية كان يجعل
    // «١٢٣٤ ريالاً» المعروضة «1,234» تعود 1.234 — خطأ ×١٠٠٠. صارت تُحذف.
    test(
      'الفاصلة اللاتينية فاصلةُ آلاف: 1,234 ⇒ 1234 لا 1.234',
      () {
        expect(convertArabicToEnglishNumbers('1,234'), '1234');
      },
    );

    test(
      'رحلة ذهاب وإياب مع toCurrency: 12,345.67 ⇒ 12345.67',
      () {
        expect(12345.67.toCurrency, '12,345.67'); // مخرجات المكتبة نفسها
        expect(convertArabicToEnglishNumbers('12,345.67'), '12345.67');
      },
    );

    test(
      'الأرقام الفارسية/الأردية (U+06F0..U+06F9) تتحوّل أيضاً',
      () {
        expect(convertArabicToEnglishNumbers('۱۲۳۴'), '1234');
      },
    );
  });

  group('ConvertArabicToEnglishNumbersFormatter', () {
    const ConvertArabicToEnglishNumbersFormatter formatter =
        ConvertArabicToEnglishNumbersFormatter();

    test('الكتابة بالعربية تُحوَّل والمؤشّر يبقى في موضعه', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v('١٢٣٤'), v('١٢٣٤٥', 5));
      expect(out.text, '12345');
      expect(out.selection.baseOffset, 5);
      expect(out.selection.isCollapsed, isTrue);
    });

    test('الإدخال في المنتصف: المؤشّر عند نهاية المُدخَل لا آخر النصّ', () {
      // «١٢٣» ثمّ إقحام ٩ بعد الأولى ⇒ «١٩٢٣» والمؤشّر عند 2
      final TextEditingValue out =
          formatter.formatEditUpdate(v('١٢٣'), v('١٩٢٣', 2));
      expect(out.text, '1923');
      expect(out.selection.baseOffset, 2);
    });

    test('الحذف من المنتصف: النصّ ينكمش والمؤشّر عند موضع الحذف', () {
      // «١٢٣٤٥» بعد حذف ٣ ⇒ «١٢٤٥» والمؤشّر عند 2
      final TextEditingValue out =
          formatter.formatEditUpdate(v('١٢٣٤٥'), v('١٢٤٥', 2));
      expect(out.text, '1245');
      expect(out.selection.baseOffset, 2);
    });

    test('المحو الكامل مسموح: الفارغ يبقى فارغاً', () {
      final TextEditingValue out = formatter.formatEditUpdate(v('١٢٣'), v(''));
      expect(out.text, '');
      expect(out.selection.baseOffset, 0);
    });

    test('نصّ لا شيء فيه للتحويل يُعاد كما هو بتحديده غير المطويّ', () {
      const TextEditingValue ranged = TextEditingValue(
        text: '123',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      final TextEditingValue out = formatter.formatEditUpdate(v(''), ranged);
      expect(out, ranged); // العودة بعين القيمة لا نسخةً منها
      expect(out.selection.isCollapsed, isFalse);
    });

    test('المحارف غير الرقمية لا تُرفض هنا — هذا منسّق تحويلٍ لا تصفية', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v(''), v('ريال ١٢ فقط'));
      expect(out.text, 'ريال 12 فقط');
    });

    test('لصق نصّ عربي طويل (٢٠٠٠ خانة) يُحوَّل كاملاً', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v(''), v('٣' * 2000));
      expect(out.text, '3' * 2000);
      expect(out.selection.baseOffset, 2000);
    });

    test('المؤشّر المعطَّل (-1) لا يتحوّل إلى موضعٍ خاطئ', () {
      const TextEditingValue noSelection = TextEditingValue(text: '٥');
      final TextEditingValue out =
          formatter.formatEditUpdate(v(''), noSelection);
      expect(out.text, '5');
      expect(out.selection.baseOffset, -1); // «لا تحديد» في Flutter
    });
  });

  group('NumbersOnlyFormatter — أرقام صحيحة فقط', () {
    const NumbersOnlyFormatter formatter = NumbersOnlyFormatter();

    test('الأرقام اللاتينية تُقبل', () {
      final TextEditingValue out = formatter.formatEditUpdate(v('12'), v('123'));
      expect(out.text, '123');
      expect(out.selection.baseOffset, 3);
    });

    test('الأرقام العربية تُقبل بعد تحويلها', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v(''), v('٩٨٧٦٥'));
      expect(out.text, '98765');
    });

    test('الصفر مقبول ولا يُعامَل معاملة الفارغ', () {
      expect(formatter.formatEditUpdate(v(''), v('0')).text, '0');
      expect(formatter.formatEditUpdate(v(''), v('٠')).text, '0');
    });

    test('المحو الكامل مسموح (وإلّا تعذّر إفراغ الحقل)', () {
      expect(formatter.formatEditUpdate(v('123'), v('')).text, '');
    });

    test('الحروف تُرفض: تُعاد القيمة القديمة نصّاً وتحديداً', () {
      const TextEditingValue old = TextEditingValue(
        text: '12',
        selection: TextSelection.collapsed(offset: 1),
      );
      final TextEditingValue out = formatter.formatEditUpdate(old, v('12a'));
      expect(out, old);
    });

    test('المسافة والرموز والنقطة تُرفض في الوضع الصحيح', () {
      for (final String bad in <String>['1 2', '1.5', '1-2', '١٢٫٥', '+5']) {
        expect(
          formatter.formatEditUpdate(v('7'), v(bad)).text,
          '7',
          reason: 'كان يجب رفض «$bad»',
        );
      }
    });

    test('السالب مرفوض: الحقل للأرقام الموجبة', () {
      expect(formatter.formatEditUpdate(v('5'), v('-5')).text, '5');
    });

    test('الحذف من المنتصف يُقبل والمؤشّر يستقرّ عند موضع الحذف', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v('12345'), v('1245', 2));
      expect(out.text, '1245');
      expect(out.selection.baseOffset, 2);
    });

    test('لصق ٣٠٠٠ رقمٍ عربي يُقبل كاملاً', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v(''), v('٧' * 3000));
      expect(out.text.length, 3000);
      expect(out.text, '7' * 3000);
    });

    test('لصق نصّ فيه رقمٌ واحدٌ خاطئ يُسقط اللصقة كلّها (رفضٌ لا تصفية)', () {
      // السلوك المقصود: المنسّق بوّابةُ قبول/رفض، لا مصفاةُ محارف.
      expect(formatter.formatEditUpdate(v(''), v('١٢٣x')).text, '');
    });
  });

  group('NumbersOnlyFormatter(allowDecimal: true) — أرقام عشرية', () {
    const NumbersOnlyFormatter formatter = NumbersOnlyFormatter(allowDecimal: true);

    test('العدد العشري اللاتيني يُقبل', () {
      expect(formatter.formatEditUpdate(v('12'), v('12.5')).text, '12.5');
    });

    test('الفاصلة العشرية العربية `٫` تُقبل وتصير نقطة', () {
      final TextEditingValue out = formatter.formatEditUpdate(v(''), v('١٢٫٥'));
      expect(out.text, '12.5');
      expect(out.selection.baseOffset, 4);
    });

    test('نقطتان تُرفضان', () {
      expect(formatter.formatEditUpdate(v('1.2'), v('1.2.3')).text, '1.2');
    });

    test('نقطة في آخر النصّ مقبولة (حالةٌ عابرة أثناء الكتابة)', () {
      expect(formatter.formatEditUpdate(v('5'), v('5.')).text, '5.');
    });

    test('النقطة وحدها تُكمَل إلى «0.» والمؤشّر بعدها', () {
      // ‏«.» وحدها ليست عدداً يقبله double.parse، فتُكمَل بدل أن تُرفض:
      // يبقى بدءُ الكسر بنقطةٍ ممكناً ويبقى نصّ الحقل قابلاً للتحليل.
      final TextEditingValue out = formatter.formatEditUpdate(v(''), v('.'));
      expect(out.text, '0.');
      expect(out.selection.baseOffset, 2);
      expect(out.selection.isCollapsed, isTrue);
      // ثمّ يُكمل المستخدم كسره طبيعياً
      expect(formatter.formatEditUpdate(out, v('0.5')).text, '0.5');
      // حذف الصفر وحده يُعيد «0.»؛ وإفراغ الحقل كلّه يبقى مسموحاً
      expect(formatter.formatEditUpdate(v('0.'), v('.', 0)).text, '0.');
      expect(formatter.formatEditUpdate(v('0.'), v('')).text, '');
    });

    test('النقطة البادئة مع رقمٍ تمرّ كما هي: «.5» يقبلها double.parse', () {
      expect(formatter.formatEditUpdate(v('.'), v('.5')).text, '.5');
      expect(double.parse('.5'), 0.5);
    });

    test('كلّ ناتجٍ غير فارغٍ من المنسّق يقبله double.parse', () {
      // ‏ضمان الصنف الموثّق: بعد هذا المنسّق لا ينهار المستدعي إلّا على
      // الحقل الفارغ، ولذلك يوصي تعليق الصنف بـ double.tryParse.
      const List<String> inputs = <String>[
        '.',
        '5.',
        '.5',
        '0',
        '0.00',
        '12.5',
        '١٢٫٥',
        '٠٫٠٥',
      ];
      for (final String input in inputs) {
        final String out = formatter.formatEditUpdate(v(''), v(input)).text;
        expect(
          double.tryParse(out),
          isNotNull,
          reason: 'ناتج «$input» كان «$out» ولا يقبله double.parse',
        );
      }
      // الفارغ وحده يبقى خارج الضمان — وهو حالةٌ مشروعة لا يملك المنسّق منعها
      expect(formatter.formatEditUpdate(v('9.9'), v('')).text, '');
      expect(double.tryParse(''), isNull);
    });

    test('الأصفار: 0 و0.00 و٠٫٠٠ كلّها مقبولة', () {
      expect(formatter.formatEditUpdate(v(''), v('0')).text, '0');
      expect(formatter.formatEditUpdate(v('0'), v('0.00')).text, '0.00');
      expect(formatter.formatEditUpdate(v(''), v('٠٫٠٠')).text, '0.00');
    });

    test('المحو الكامل مسموح', () {
      expect(formatter.formatEditUpdate(v('9.9'), v('')).text, '');
    });

    test('الحروف والسالب مرفوضة', () {
      expect(formatter.formatEditUpdate(v('1.5'), v('1.5a')).text, '1.5');
      expect(formatter.formatEditUpdate(v('1.5'), v('-1.5')).text, '1.5');
    });

    test('الحذف من المنتصف: حذف النقطة يُقبل', () {
      final TextEditingValue out =
          formatter.formatEditUpdate(v('12.5'), v('125', 2));
      expect(out.text, '125');
      expect(out.selection.baseOffset, 2);
    });

    test('عدد عشري طويل جداً يُقبل (لا حدّ طولٍ في المنسّق)', () {
      final String long = '${'٨' * 1000}٫${'٣' * 1000}';
      final TextEditingValue out = formatter.formatEditUpdate(v(''), v(long));
      expect(out.text, '${'8' * 1000}.${'3' * 1000}');
    });
  });

  group('المنسّقات والفواصل', () {
    const NumbersOnlyFormatter intOnly = NumbersOnlyFormatter();
    const NumbersOnlyFormatter decimal = NumbersOnlyFormatter(allowDecimal: true);

    test(
      'لصق مبلغٍ منسّق «1,234» في حقل أرقامٍ صحيحة يُعطي 1234',
      () {
        expect(intOnly.formatEditUpdate(v(''), v('1,234')).text, '1234');
      },
    );

    test(
      'لصق مبلغٍ منسّق «1,234» في حقلٍ عشري يُعطي 1234 لا 1.234',
      () {
        expect(decimal.formatEditUpdate(v(''), v('1,234')).text, '1234');
      },
    );

    test(
      'لصق «١٬٢٣٤» (فاصلة آلافٍ عربية) يُقبل ويُعطي 1234',
      () {
        expect(intOnly.formatEditUpdate(v(''), v('١٬٢٣٤')).text, '1234');
      },
    );
  });
}
