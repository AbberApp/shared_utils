// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك فعلاً، وهو يُثبت أنّ
// `CurrencyExtension` و`IntCurrencyExtension` و`ArabicDigits*` مُصدَّرة.
// و`intl` تُستورد مباشرةً لضبط `Intl.defaultLocale` في اختبار استقلال اللغة.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار تنسيق العملة (`toCurrency` / `toCurrencyNoDecimals`) وتحويل الأرقام
/// العربية-الهندية (`toArabicDigits` / `toLatinDigits`).
///
/// الهدفان:
/// - lib/src/utils/extensions/currency_extension.dart
/// - lib/src/utils/extensions/arabic_digits_extension.dart
void main() {
  group('toCurrency على double — الأساس', () {
    test('الصفر يُعرض بخانتين عشريّتين لا مجرّد «0»', () {
      expect(0.0.toCurrency, '0.00');
    });

    test('العدد الصحيح يُكمَّل بصفرين', () {
      expect(1000.0.toCurrency, '1,000.00');
      expect(7.0.toCurrency, '7.00');
    });

    test('فاصلة الآلاف تتكرّر عند كل ثلاث خانات', () {
      expect(1234567.89.toCurrency, '1,234,567.89');
      expect(1000000000.0.toCurrency, '1,000,000,000.00');
    });

    test('ما دون الألف بلا فاصلة', () {
      expect(999.5.toCurrency, '999.50');
      expect(0.5.toCurrency, '0.50');
    });

    test('السالب يحتفظ بإشارته وبفواصله', () {
      expect((-1234.56).toCurrency, '-1,234.56');
      expect((-1.0).toCurrency, '-1.00');
    });

    test('الكسر الزائد يُقرَّب إلى خانتين', () {
      expect(1234.567.toCurrency, '1,234.57');
      expect(1234.564.toCurrency, '1,234.56');
      expect((-1234.567).toCurrency, '-1,234.57');
    });

    test('النصف المُمثَّل تمثيلاً ثنائياً دقيقاً يُقرَّب بعيداً عن الصفر', () {
      // 0.125 و0.375 يُمثَّلان في الثنائي تمثيلاً تامّاً، فالنصف هنا نصفٌ حقيقي.
      expect(0.125.toCurrency, '0.13');
      expect(0.375.toCurrency, '0.38');
      expect((-0.125).toCurrency, '-0.13');
    });

    test('خطأ العوم الثنائي لا يتسرّب إلى الناتج', () {
      // 0.1 + 0.2 = 0.30000000000000004 في الثنائي.
      expect((0.1 + 0.2).toCurrency, '0.30');
      // 1.005 هو فعلاً 1.00499999… فينزل لا يعلو — سلوكُ العوم لا عيبُ المكتبة.
      expect(1.005.toCurrency, '1.00');
    });

    test('أصغر كسرٍ موجب يؤول إلى صفرٍ موجب', () {
      expect(double.minPositive.toCurrency, '0.00');
      expect(0.004.toCurrency, '0.00');
    });
  });

  group('toCurrency على double — الصفر السالب', () {
    // مبلغٌ يؤول تقريبُه إلى صفر لا يجوز أن يظهر بإشارة سالب في واجهة:
    // «-0.00 ر.س» رصيدٌ لا معنى له ويُقلق المستخدم.
    test('الرصيد الضئيل السالب الذي يؤول إلى صفر يُعرض «0.00» لا «-0.00»', () {
      expect((-0.004).toCurrency, '0.00');
    });

    test('الصفر السالب (-0.0) يُعرض «0.00»', () {
      expect((-0.0).toCurrency, '0.00');
    });

    test('الصفر السالب بلا كسور يُعرض «0»', () {
      expect((-0.4).toCurrencyNoDecimals, '0');
    });
  });

  group('toCurrencyNoDecimals على double', () {
    test('الصفر «0» بلا كسور', () {
      expect(0.0.toCurrencyNoDecimals, '0');
    });

    test('الكسر يُقرَّب لا يُبتر', () {
      expect(1234.5.toCurrencyNoDecimals, '1,235');
      expect(1234.4.toCurrencyNoDecimals, '1,234');
      expect(0.5.toCurrencyNoDecimals, '1');
      expect(0.4.toCurrencyNoDecimals, '0');
    });

    test('السالب يُقرَّب بعيداً عن الصفر ويحتفظ بإشارته', () {
      expect((-1234.5).toCurrencyNoDecimals, '-1,235');
      expect((-1234.4).toCurrencyNoDecimals, '-1,234');
      expect((-0.5).toCurrencyNoDecimals, '-1');
    });

    test('التقريب قد يعبر حدّ الآلاف فتُعاد الفواصل', () {
      expect(999999.995.toCurrencyNoDecimals, '1,000,000');
      expect(999.6.toCurrencyNoDecimals, '1,000');
    });

    test('الفواصل نفسها في النسختين', () {
      expect(1234567.0.toCurrency, '1,234,567.00');
      expect(1234567.0.toCurrencyNoDecimals, '1,234,567');
    });
  });

  group('القيم غير المنتهية (اللانهاية و NaN)', () {
    // مدعومة: `NumberFormat` يردّ رموز اللغة بدل أن يرمي استثناءً. النتيجة ليست
    // صالحةً للعرض كسعر، فعلى المستدعي أن يحرس قبل النداء — وهذا ما توثّقه.
    test('اللانهاية تُعاد رمزاً ولا ترمي استثناءً', () {
      expect(double.infinity.toCurrency, '∞');
      expect(double.infinity.toCurrencyNoDecimals, '∞');
    });

    test('اللانهاية السالبة برمزها وإشارتها', () {
      expect(double.negativeInfinity.toCurrency, '-∞');
      expect(double.negativeInfinity.toCurrencyNoDecimals, '-∞');
    });

    test('NaN يُعاد «NaN» ولا يرمي استثناءً', () {
      expect(double.nan.toCurrency, 'NaN');
      expect(double.nan.toCurrencyNoDecimals, 'NaN');
    });
  });

  group('الأعداد الضخمة', () {
    test('حتّى 10^18 يُنسَخ العدد بدقّة', () {
      expect(1000000000000000.0.toCurrency, '1,000,000,000,000,000.00');
      expect(1000000000000000000.0.toCurrency, '1,000,000,000,000,000,000.00');
      expect(
        1000000000000000000.0.toCurrencyNoDecimals,
        '1,000,000,000,000,000,000',
      );
    });

    // ما تجاوز 2^63 لا يجوز أن يُقصّ إلى 9,223,372,036,854,775,807 (حدّ int64)
    // فيخرج مبلغٌ مختلفٌ تماماً عن المُدخل بلا استثناء ولا تحذير.
    test('10^19 يُنسَخ كما هو لا مقصوصاً عند حدّ int64', () {
      expect(1e19.toCurrency, '10,000,000,000,000,000,000.00');
    });

    test('10^21 يُنسَخ كما هو لا مقصوصاً عند حدّ int64', () {
      expect(1e21.toCurrencyNoDecimals, '1,000,000,000,000,000,000,000');
    });
  });

  group('toCurrency على int', () {
    test('الصفر والأعداد الصغيرة بلا فواصل', () {
      expect(0.toCurrency, '0');
      expect(1.toCurrency, '1');
      expect(999.toCurrency, '999');
    });

    test('الألف فما فوق بفواصل', () {
      expect(1000.toCurrency, '1,000');
      expect(123456789.toCurrency, '123,456,789');
    });

    test('السالب يحتفظ بإشارته', () {
      expect((-1).toCurrency, '-1');
      expect((-1000).toCurrency, '-1,000');
      expect((-123456789).toCurrency, '-123,456,789');
    });

    test('لا خانات عشريّة أبداً — العدد الصحيح صحيح', () {
      expect(7.toCurrency, isNot(contains('.')));
      expect(1000.toCurrency, isNot(contains('.')));
    });

    test('حدّا int64 يُنسخان بلا فقدان دقّة (لا يمرّان عبر double)', () {
      expect(9223372036854775807.toCurrency, '9,223,372,036,854,775,807');
      expect(
        (-9223372036854775807 - 1).toCurrency,
        '-9,223,372,036,854,775,808',
      );
      // 2^53+1 لا يُمثَّل في double؛ لو مرّ عبره لعاد ‎…992.
      expect(9007199254740993.toCurrency, '9,007,199,254,740,993');
    });

    test('العدد الصحيح نفسه يُنسَّق واحداً في النوعين', () {
      expect(1234567.toCurrency, 1234567.0.toCurrencyNoDecimals);
    });
  });

  group('اتّساق واجهة int مع double', () {
    // `toCurrencyNoDecimals` قائمةٌ على النوعين، فالنداء العام على عددٍ قد يكون
    // int أو double يُترجم بلا `.toDouble()` — وهي تفقد الدقّة فوق 2^53.
    test('int يقبل toCurrencyNoDecimals كما يقبلها double', () {
      // بنوعٍ ساكن: امتدادات Dart لا تُحَلّ على مستقبِلٍ dynamic، فالنوع الساكن
      // وحده يُثبت وجود العضو على int فعلاً.
      const int value = 12345;
      expect(value.toCurrencyNoDecimals, '12,345');
      expect(value.toCurrencyNoDecimals, value.toCurrency);
    });
  });

  group('التنسيق مستقلٌّ عن لغة التطبيق', () {
    // `Intl.defaultLocale` حالةٌ ساكنة عامّة، فتُصفَّر كيلا تتسرّب بين الاختبارات.
    final String? original = Intl.defaultLocale;
    tearDown(() => Intl.defaultLocale = original);

    test('اللغة العربية لا تُبدّل الأرقام ولا الفواصل', () {
      Intl.defaultLocale = 'ar';
      expect(1234.5.toCurrency, '1,234.50');
      expect(1234.5.toCurrencyNoDecimals, '1,235');
      expect(1234567.toCurrency, '1,234,567');
    });

    test('الألمانية لا تقلب الفاصلة والنقطة', () {
      Intl.defaultLocale = 'de_DE';
      expect(1234.5.toCurrency, '1,234.50');
      expect(1234567.toCurrency, '1,234,567');
    });

    test('Intl.withLocale لا يغيّر الناتج', () {
      expect(Intl.withLocale('ar', () => 1234.5.toCurrency), '1,234.50');
    });
  });

  group('toArabicDigits على String', () {
    test('النصّ الفارغ يبقى فارغاً', () {
      expect(''.toArabicDigits, '');
    });

    test('الأرقام العشرة كلّها تُستبدل بالترتيب', () {
      expect('0123456789'.toArabicDigits, '٠١٢٣٤٥٦٧٨٩');
    });

    test('ما ليس رقماً يبقى كما هو', () {
      expect('abc'.toArabicDigits, 'abc');
      expect('لا أرقام هنا'.toArabicDigits, 'لا أرقام هنا');
      expect(r'!@#$%^&*()'.toArabicDigits, r'!@#$%^&*()');
    });

    test('النصّ المختلط: الأرقام وحدها تتبدّل', () {
      expect('طلب رقم 12 من 30'.toArabicDigits, 'طلب رقم ١٢ من ٣٠');
      expect('A٣4'.toArabicDigits, 'A٣٤');
    });

    test('الإشارة والفاصلة والنقطة تبقى لاتينية', () {
      expect('-3.5'.toArabicDigits, '-٣.٥');
      expect('1,234.56'.toArabicDigits, '١,٢٣٤.٥٦');
    });

    test('التحويل مُتماثل (idempotent): تطبيقٌ ثانٍ لا يغيّر شيئاً', () {
      const String source = 'الصفحة 3 من 10';
      final String once = source.toArabicDigits;
      expect(once.toArabicDigits, once);
      expect('٥٦'.toArabicDigits, '٥٦');
    });

    test('الأرقام الفارسية (U+06F0..) تبقى كما هي — النطاق اللاتيني وحده', () {
      expect('۵۶'.toArabicDigits, '۵۶');
    });

    test('الأزواج البديلة (surrogate pairs) تنجو سليمة', () {
      final String result = '\u{1F44D}42'.toArabicDigits;
      expect(result, '\u{1F44D}٤٢');
      expect(result.length, 4); // زوجٌ بديل (2) + رقمان
      expect(result.runes.length, 3);
      expect(
        '\u{1F1F8}\u{1F1E6} السعر 99'.toArabicDigits,
        '\u{1F1F8}\u{1F1E6} السعر ٩٩',
      );
    });

    test('المحارف الصفريّة العرض وعلامات الاتجاه تمرّ بلا مساس', () {
      expect('‏12‎'.toArabicDigits, '‏١٢‎');
      expect(' '.toArabicDigits, ' ');
    });

    test('نصٌّ طويل جداً يُحوَّل كلّه ولا يُبتر', () {
      final String long = '1' * 10000;
      final String result = long.toArabicDigits;
      expect(result.length, 10000);
      expect(result, '١' * 10000);
    });
  });

  group('toArabicDigits على int', () {
    test('الصفر يصبح ٠', () {
      expect(0.toArabicDigits, '٠');
    });

    test('رقمٌ واحد وعدّة أرقام', () {
      expect(5.toArabicDigits, '٥');
      expect(12.toArabicDigits, '١٢');
      expect(1234567890.toArabicDigits, '١٢٣٤٥٦٧٨٩٠');
    });

    test('السالب: الأرقام تتحوّل والإشارة تبقى لاتينية', () {
      expect((-7).toArabicDigits, '-٧');
    });

    test('لا فواصل آلاف — التمثيل نصُّ toString لا العملة', () {
      expect(1000.toArabicDigits, '١٠٠٠');
      expect(1000.toArabicDigits, isNot(contains(',')));
    });

    test('حدّا int64 يتحوّلان كاملين', () {
      expect(9223372036854775807.toArabicDigits, '٩٢٢٣٣٧٢٠٣٦٨٥٤٧٧٥٨٠٧');
      expect((-9223372036854775807 - 1).toArabicDigits, '-٩٢٢٣٣٧٢٠٣٦٨٥٤٧٧٥٨٠٨');
    });

    test('يطابق تحويل نصِّ العدد نفسه', () {
      expect(4096.toArabicDigits, 4096.toString().toArabicDigits);
    });
  });

  group('الاتجاه العكسي: من العربية-الهندية إلى اللاتينية', () {
    // ما يكتبه المستخدم بلوحةٍ عربية («٥٠٠») لا يمرّ على `int.parse` ولا على
    // تحقّق الهاتف ولا على تنسيق المبلغ؛ فبلا الاتجاه العكسي يبقى الإدخال
    // العربي مرفوضاً. الاتجاه الطالع وحده موجود في المكتبة.
    test('نصٌّ بأرقام عربية-هندية يعود لاتينياً', () {
      // بنوعٍ ساكن: امتدادات Dart لا تُحَلّ على مستقبِلٍ dynamic.
      const String text = '٠١٢٣٤٥٦٧٨٩';
      expect(text.toLatinDigits, '0123456789');
    });

    test('الرحلة الكاملة ذهاباً وإياباً تُعيد الأصل', () {
      final String converted = 'المبلغ 500'.toArabicDigits;
      expect(converted.toLatinDigits, 'المبلغ 500');
    });
  });
}
