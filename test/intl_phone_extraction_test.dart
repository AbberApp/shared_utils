import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار دوالّ **الاستخراج** في [IntlPhoneUtils] — لا التحقّق (ذاك مغطّى
/// كاملاً في `phone_validation_test.dart` بمثالٍ حقيقيّ لكل دولة).
///
/// المقصود هنا: استخراج رمز ISO والعلم واسم الدولة من رقمٍ دوليّ، وحسم أقاليم
/// NANP (‎+1)، والبحث في قائمة الدول برمز الاتصال، وتطبيع المُدخل (بادئة 00،
/// مسافات، شرطات، أرقام عربية-هندية)، والتشذيب إلى أقصى طولٍ وطنيّ.
///
/// كانت عشرةٌ منها موقوفةً بـ`skip` توثّق عيوباً حقيقية؛ أُصلحت في المصدر ورُفع
/// إيقافها — فلا موقوف هنا الآن.
void main() {
  // أرقام حقيقية من مرجع libphonenumber (انظر `phone_examples.g.dart`).
  const String saNumber = '+966512345678'; // السعودية: NSN من ٩ أرقام
  const String jmNumber = '+18762101234'; // جامايكا: 1876 + ٧ أرقام
  const String caNumber = '+15062345678'; // كندا: نيو برونزويك (506)
  const String usNumber = '+12015550123'; // الولايات المتحدة: نيوجيرسي (201)
  const String prNumber = '+17875550123'; // بورتوريكو (787)
  const String doNumber = '+18092345678'; // الدومينيكان (809)
  const String gbNumber = '+447400123456'; // بريطانيا
  const String asNumber = '+16847331234'; // ساموا الأمريكية: 1684 + ٧ أرقام

  group('استخراج رمز الدولة ISO من رقم دوليّ', () {
    test('رقم سعوديّ يعطي SA وعلمها واسمها العربيّ', () {
      expect(IntlPhoneUtils.getCountryCode(saNumber), 'SA');
      expect(IntlPhoneUtils.getCountryFlag(saNumber), '🇸🇦');
      expect(IntlPhoneUtils.getCountryDialCode(saNumber), '966');
      expect(IntlPhoneUtils.getCountryByCompletePhoneNumber(saNumber).code, 'SA');
    });

    test('رقم بريطانيّ يعطي GB لا غيرنزي (الدولة الرئيسية لرمز 44)', () {
      expect(IntlPhoneUtils.getCountryCode(gbNumber), 'GB');
      expect(IntlPhoneUtils.getCountryFlag(gbNumber), '🇬🇧');
      // رقمٌ على النطاق الذي تتشارك فيه الأقاليم يبقى على الدولة الرئيسية.
      expect(IntlPhoneUtils.getCountryCode('+447781123456'), 'GB');
    });

    test('النصّ الفارغ لا يعطي رمزاً ولا علماً', () {
      expect(IntlPhoneUtils.getCountryCode(''), '');
      expect(IntlPhoneUtils.getCountryFlag(''), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(''), '');
    });

    test('علامة «+» وحدها لا تعطي رمزاً', () {
      expect(IntlPhoneUtils.getCountryCode('+'), '');
      expect(IntlPhoneUtils.getCountryFlag('+'), '');
    });

    test('رمز اتصال غير موجود لا يعطي رمزاً (لا يقع على دولةٍ عشوائية)', () {
      expect(IntlPhoneUtils.getCountryCode('+999999999'), '');
      expect(IntlPhoneUtils.getCountryFlag('+999999999'), '');
    });

    test('«+0» لا يطابق شيئاً — لا رمز اتصال يبدأ بصفر', () {
      expect(IntlPhoneUtils.getCountryCode('+0'), '');
      expect(IntlPhoneUtils.getCountryCode('+00'), '');
    });

    test('الرقم الكامل يشترط «+» — الصيغة المجرّدة لا تُستخرَج منها الدولة', () {
      // عقدٌ مقصود: «966…» و«0512…» لا يُميَّز أدوليٌّ هو أم محلّيّ.
      expect(IntlPhoneUtils.getCountryCode('966512345678'), '');
      expect(IntlPhoneUtils.getCountryCode('0512345678'), '');
    });

    test('مسافة لاحقة لا تكسر الاستخراج', () {
      expect(IntlPhoneUtils.getCountryCode('$saNumber '), 'SA');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('$saNumber '), '512345678');
    });

    test('رقم طويل جدّاً (٢٠٠ خانة) يبقى رمز دولته صحيحاً', () {
      final String long = '+966${'5' * 200}';
      expect(IntlPhoneUtils.getCountryCode(long), 'SA');
      expect(IntlPhoneUtils.getCountryDialCode(long), '966');
    });

    test('رمز الاتصال يسقط إلى السعودية عند الفشل، بخلاف رمز ISO والعلم', () {
      // سلوكٌ مقصود: `getCountryDialCode` و`getCountryByCompletePhoneNumber`
      // لهما افتراضيٌّ (السعودية)، أمّا الرمز والعلم فيعودان فارغين.
      expect(IntlPhoneUtils.getCountryDialCode(''), '966');
      expect(IntlPhoneUtils.getCountryDialCode('+999999999'), '966');
      expect(IntlPhoneUtils.getCountryByCompletePhoneNumber('نصّ فاسد').code, 'SA');
      expect(IntlPhoneUtils.defaultCountryCode, 'SA');
    });

    test('اسم الدولة العربيّ من رمز ISO، وفارغٌ للمجهول', () {
      expect(IntlPhoneUtils.getCountryNameByCountryCode('SA'), 'السعودية');
      expect(IntlPhoneUtils.getCountryNameByCountryCode('JM'), 'جامايكا');
      expect(IntlPhoneUtils.getCountryNameByCountryCode('CA'), 'كندا');
      expect(IntlPhoneUtils.getCountryNameByCountryCode('XX'), '');
      expect(IntlPhoneUtils.getCountryNameByCountryCode(''), '');
    });

    test('مسافة بادئة (لصقٌ من جهات الاتصال) لا تمنع استخراج الدولة', () {
      // `getExactLength` يقبل الرقم نفسه لأنّه يطبّع؛ فاستخراج الدولة ينبغي
      // ألّا يناقضه.
      expect(IntlPhoneUtils.getExactLength('  $saNumber  '), 9);
      expect(IntlPhoneUtils.getCountryCode('  $saNumber  '), 'SA');
      expect(IntlPhoneUtils.getCountryCode('\n$saNumber'), 'SA');
    });

    test('الأرقام العربية-الهندية في الرقم الدوليّ تُستخرَج منها الدولة', () {
      expect(IntlPhoneUtils.getExactLength('+٩٦٦٥١٢٣٤٥٦٧٨'), 9);
      expect(IntlPhoneUtils.getCountryCode('+٩٦٦٥١٢٣٤٥٦٧٨'), 'SA');
      expect(IntlPhoneUtils.getCountryFlag('+٩٦٦٥١٢٣٤٥٦٧٨'), '🇸🇦');
    });

    test('بادئة الخروج الدوليّ 00 تعادل «+» في استخراج الدولة', () {
      expect(IntlPhoneUtils.getExactLength('00966512345678'), 9);
      expect(IntlPhoneUtils.getCountryCode('00966512345678'), 'SA');
      expect(IntlPhoneUtils.getCountryFlag('00966512345678'), '🇸🇦');
    });
  });

  group('أقاليم NANP (رمز الاتصال +1)', () {
    test('جامايكا: أطول تطابق (1876) يغلب رمز «1» المجرّد', () {
      expect(IntlPhoneUtils.getCountryCode(jmNumber), 'JM');
      expect(IntlPhoneUtils.getCountryFlag(jmNumber), '🇯🇲');
      expect(IntlPhoneUtils.getCountryDialCode(jmNumber), '1876');
      expect(
        IntlPhoneUtils.getCountryByCompletePhoneNumber(jmNumber).localizedName('ar'),
        'جامايكا',
      );
    });

    test('جامايكا: الرقم الوطنيّ ٧ خانات بلا رمز المنطقة 876', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(jmNumber), '2101234');
      expect(IntlPhoneUtils.getExactLength(jmNumber), 7);
    });

    test('رمز الاتصال وحده «+1876» يطابق جامايكا برقمٍ وطنيّ فارغ', () {
      expect(IntlPhoneUtils.getCountryCode('+1876'), 'JM');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+1876'), '');
    });

    test('ساموا الأمريكية: رمزها 1684 يُستخرَج كاملاً', () {
      expect(IntlPhoneUtils.getCountryCode(asNumber), 'AS');
      expect(IntlPhoneUtils.getCountryDialCode(asNumber), '1684');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(asNumber), '7331234');
    });

    test('رقم أمريكيّ على «1» المجرّد يعطي US ورقماً وطنيّاً من ١٠ خانات', () {
      expect(IntlPhoneUtils.getCountryCode(usNumber), 'US');
      expect(IntlPhoneUtils.getCountryFlag(usNumber), '🇺🇸');
      expect(IntlPhoneUtils.getCountryDialCode(usNumber), '1');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(usNumber), '2015550123');
    });

    test('«+1» وحده: رقمٌ وطنيّ فارغ بلا انفجار مدى', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+1'), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+18'), '8');
    });

    test('كل أقاليم NANP في القائمة رمز اتصالها يبدأ بـ«1»', () {
      for (final String iso in ['JM', 'AS', 'CA', 'US', 'PR', 'DO', 'BB', 'BM']) {
        final CountryModel c = IntlPhoneUtils.getCountryByCode(iso);
        expect(c.code, iso, reason: '$iso غير موجود في القائمة');
        expect(c.dialCode.startsWith('1'), isTrue, reason: '$iso ليس من NANP');
      }
    });

    test('كندا: رقم نيو برونزويك (506) يعطي CA وعلمها لا US', () {
      expect(IntlPhoneUtils.getCountryCode(caNumber), 'CA');
      expect(IntlPhoneUtils.getCountryFlag(caNumber), '🇨🇦');
      expect(
        IntlPhoneUtils.getCountryNameByCountryCode(IntlPhoneUtils.getCountryCode(caNumber)),
        'كندا',
      );
    });

    test('بورتوريكو والدومينيكان لا تُنسبان إلى الولايات المتحدة', () {
      expect(IntlPhoneUtils.getCountryCode(prNumber), 'PR');
      expect(IntlPhoneUtils.getCountryCode(doNumber), 'DO');
    });
  });

  group('البحث في قائمة الدول برمز الاتصال «+966» ونظائره', () {
    final List<CountryModel> countries = IntlPhoneUtils.countries;

    test('«+966» يعطي السعودية (كانت العلامة تُقارَن فتُفرغ النتيجة)', () {
      expect(countries.stringSearch('+966').map((c) => c.code).toList(), ['SA']);
    });

    test('«966» بلا علامة يعطي السعودية كذلك', () {
      expect(countries.stringSearch('966').map((c) => c.code).toList(), ['SA']);
    });

    test('المسافات الزائدة في نصّ البحث تُهمَل', () {
      expect(countries.stringSearch('+966 ').map((c) => c.code).toList(), ['SA']);
      expect(countries.stringSearch('966 ').map((c) => c.code).toList(), ['SA']);
    });

    test('«1876» يعطي جامايكا وحدها', () {
      expect(countries.stringSearch('1876').map((c) => c.code).toList(), ['JM']);
    });

    test('«+1» يعطي كل أقاليم NANP ولا شيء سواها', () {
      final List<CountryModel> result = countries.stringSearch('+1');
      expect(result.map((c) => c.code), containsAll(['US', 'CA', 'JM', 'PR', 'DO']));
      expect(result.every((c) => c.dialCode.startsWith('1')), isTrue);
    });

    test('المطابقة ببادئة رمز الاتصال لا باحتوائه', () {
      // «9665» ليس بادئةً لأيّ رمز اتصال (966 أقصر منه) فلا نتيجة — عقدٌ مقصود.
      expect(countries.stringSearch('9665'), isEmpty);
      // و«66» لا يعطي السعودية لأنّ «966» لا يبدأ به.
      expect(countries.stringSearch('66').map((c) => c.code), isNot(contains('SA')));
    });

    test('نصّ بحثٍ فارغ أو «+» وحدها لا يُرشّح شيئاً', () {
      expect(countries.stringSearch('').length, countries.length);
      expect(countries.stringSearch('+').length, countries.length);
    });

    test('نصٌّ لا يطابق شيئاً يعطي قائمة فارغة لا استثناءً', () {
      expect(countries.stringSearch('zzz'), isEmpty);
      expect(countries.stringSearch('!!!'), isEmpty);
    });

    test('البحث بالاسم العربيّ وبالاسم اللاتينيّ بلا تشكيل', () {
      expect(countries.stringSearch('السعودية').map((c) => c.code).toList(), ['SA']);
      expect(countries.stringSearch('jamaica').map((c) => c.code).toList(), ['JM']);
      // «Jamaïque» الفرنسية تُطابَق بكتابةٍ بلا تشكيل.
      expect(countries.stringSearch('jamaique').map((c) => c.code).toList(), ['JM']);
    });

    test('isNumeric يميّز نصّ رمز الاتصال (وهو ما يشغّل مسار البحث الرقميّ)', () {
      expect(IntlPhoneUtils.isNumeric('966'), isTrue);
      expect(IntlPhoneUtils.isNumeric('+966'), isTrue);
      expect(IntlPhoneUtils.isNumeric(''), isFalse);
      expect(IntlPhoneUtils.isNumeric('+'), isFalse);
      expect(IntlPhoneUtils.isNumeric('12.5'), isFalse);
      expect(IntlPhoneUtils.isNumeric('السعودية'), isFalse);
    });

    test('isNumeric تحكم على الحروف لا على قواعد تحليل الأعداد', () {
      // كانت تفوّض إلى `int.tryParse` فترث قواعده: إشارةٌ وفراغٌ محيطٌ مقبولان،
      // وسلسلةٌ رقمية خالصة تتجاوز سعة int64 مرفوضة — والاسم يَعِد بغير ذلك.
      expect(IntlPhoneUtils.isNumeric('-5'), isFalse);
      expect(IntlPhoneUtils.isNumeric(' 966 '), isFalse);
      expect(IntlPhoneUtils.isNumeric('9 66'), isFalse);
      expect(IntlPhoneUtils.isNumeric('12345678901234567890'), isTrue);
      // الأرقام العربية-الهندية ليست أرقاماً لاتينية.
      expect(IntlPhoneUtils.isNumeric('٩٦٦'), isFalse);
    });

    test('البحث بأرقامٍ عربية-هندية «٩٦٦» يعطي السعودية', () {
      expect(countries.stringSearch('٩٦٦').map((c) => c.code).toList(), ['SA']);
    });

    test('البحث بـ«+٩٦٦» يعطي السعودية لا كل الدول', () {
      expect(countries.stringSearch('+٩٦٦').map((c) => c.code).toList(), ['SA']);
    });
  });

  group('«هل الرقم سعوديّ؟» — فحص البادئة +966', () {
    test('رقم سعوديّ كامل: نعم', () {
      expect(IntlPhoneUtils.isSA(saNumber), isTrue);
      expect(IntlPhoneUtils.isSA('+966'), isTrue);
    });

    test('رقم غير سعوديّ: لا', () {
      expect(IntlPhoneUtils.isSA(gbNumber), isFalse);
      expect(IntlPhoneUtils.isSA('+971512345678'), isFalse);
      expect(IntlPhoneUtils.isSA('+96'), isFalse);
    });

    test('فحصٌ حرفيٌّ للبادئة: الفارغ وما لا يبدأ بـ«+966» كلّه لا', () {
      // عقدٌ مقصود: مقارنة بادئةٍ خام لا تطبيع — فالمُدخل هنا رقمٌ سبق تطبيعه.
      expect(IntlPhoneUtils.isSA(''), isFalse);
      expect(IntlPhoneUtils.isSA('966512345678'), isFalse);
      expect(IntlPhoneUtils.isSA('00966512345678'), isFalse);
      expect(IntlPhoneUtils.isSA('+ 966512345678'), isFalse);
      expect(IntlPhoneUtils.isSA(' +966512345678'), isFalse);
    });
  });

  group('تطبيع المُدخل: بادئة 00 والمسافات والشرطات', () {
    test('الصيغة الدولية الصريحة تعطي سعة ٩ للسعودية', () {
      expect(IntlPhoneUtils.getExactLength(saNumber), 9);
    });

    test('بادئة الخروج الدوليّ «00» تعادل «+»', () {
      expect(IntlPhoneUtils.getExactLength('00966512345678'), 9);
      expect(IntlPhoneUtils.isPlausiblePhone('00966512345678'), isTrue);
      expect(IntlPhoneUtils.getExactLength('0018762101234'), 7);
    });

    test('الصيغة المجرّدة بلا «+» ولا «00» تُقبل في حساب الطول', () {
      expect(IntlPhoneUtils.getExactLength('966512345678'), 9);
      expect(IntlPhoneUtils.isPlausiblePhone('966512345678'), isTrue);
    });

    test('المسافات والشرطات والأقواس تُسقَط قبل الحساب', () {
      expect(IntlPhoneUtils.getExactLength('+966 51 234 5678'), 9);
      expect(IntlPhoneUtils.getExactLength('+966-51-234-5678'), 9);
      expect(IntlPhoneUtils.getExactLength('(+966) 51-234 5678'), 9);
      expect(IntlPhoneUtils.getExactLength('+1-876-210-1234'), 7);
      // ولا تحجب البوّابة مستخدماً صحيحاً لصق رقمه منسّقاً.
      expect(IntlPhoneUtils.isPlausiblePhone('+966 51 234 5678'), isTrue);
      expect(IntlPhoneUtils.isPlausiblePhone('+966-51-234-5678'), isTrue);
    });

    test('الأرقام العربية-الهندية والفارسية تُردّ إلى اللاتينية', () {
      expect(IntlPhoneUtils.getExactLength('+٩٦٦٥١٢٣٤٥٦٧٨'), 9);
      expect(IntlPhoneUtils.getExactLength('٠٠٩٦٦٥١٢٣٤٥٦٧٨'), 9);
      expect(IntlPhoneUtils.getExactLength('۰۰۹۶۶۵۱۲۳۴۵۶۷۸'), 9);
      expect(IntlPhoneUtils.isPlausiblePhone('+٩٦٦٥١٢٣٤٥٦٧٨'), isTrue);
      expect(IntlPhoneUtils.isPlausiblePhone('۰۰۹۶۶۵۱۲۳۴۵۶۷۸'), isTrue);
    });

    test('علاماتٌ زائدة «+++» لا تكسر التطبيع', () {
      expect(IntlPhoneUtils.getExactLength('+++966512345678'), 9);
    });

    test('الفارغ والنصّ بلا أرقام لا يعطيان سعة', () {
      expect(IntlPhoneUtils.getExactLength(''), isNull);
      expect(IntlPhoneUtils.getExactLength('   '), isNull);
      expect(IntlPhoneUtils.getExactLength('abc'), isNull);
      expect(IntlPhoneUtils.getExactLength('رقم هاتف'), isNull);
      expect(IntlPhoneUtils.isPlausiblePhone(''), isFalse);
      expect(IntlPhoneUtils.isPlausiblePhone('abc'), isFalse);
    });

    test('«00» وحدها أو أصفارٌ خالصة: لا رمز اتصال يبدأ بصفر', () {
      expect(IntlPhoneUtils.getExactLength('00'), isNull);
      expect(IntlPhoneUtils.getExactLength('00000'), isNull);
      expect(IntlPhoneUtils.getExactLength('0'), isNull);
      expect(IntlPhoneUtils.isPlausiblePhone('00000'), isFalse);
    });

    test('رقمٌ سالب أو مشوّه لا يُقبل رقماً معقولاً', () {
      // الإشارة والحروف تُسقَط كأيّ فاصل، فيبقى «966» بلا رقمٍ وطنيّ.
      expect(IntlPhoneUtils.getExactLength('-966'), 9);
      expect(IntlPhoneUtils.isPlausiblePhone('-966'), isFalse);
      expect(IntlPhoneUtils.getExactLength('+966abc'), 9);
      expect(IntlPhoneUtils.isPlausiblePhone('+966abc'), isFalse);
    });

    test('رقمٌ طويل جدّاً: السعة تبقى صحيحة والمعقولية ترفضه', () {
      final String long = '+966${'5' * 200}';
      expect(IntlPhoneUtils.getExactLength(long), 9);
      expect(IntlPhoneUtils.isPlausiblePhone(long), isFalse);
    });

    test('الدولة المُمرَّرة تحسم السعة عند تشارك رمز الاتصال', () {
      final CountryModel jm = IntlPhoneUtils.getCountryByCode('JM');
      final CountryModel us = IntlPhoneUtils.getCountryByCode('US');
      expect(IntlPhoneUtils.getExactLength(jmNumber, country: jm), 7);
      expect(IntlPhoneUtils.getExactLength(usNumber, country: us), 10);
    });
  });

  group('التشذيب إلى أقصى طولٍ وطنيّ (maxLength)', () {
    test('الرقم الصحيح لا يُقتطَع منه شيء', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(saNumber), '512345678');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(gbNumber), '7400123456');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(usNumber), '2015550123');
    });

    test('الزائد على السعة يُقتطَع (السعودية ٩ خانات)', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+9665123456789999'), '512345678');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966${'5' * 100}').length, 9);
    });

    test('السقف من مرجع libphonenumber لا من maxLength وحده', () {
      // جامايكا: رمز المنطقة داخل dialCode فالرقم الوطنيّ ٧ خانات.
      final String nsn = IntlPhoneUtils.getPhoneNumberByCountryDialCode('+1876210123456789');
      expect(nsn, '2101234');
      expect(nsn.length, 7);
    });

    test('الصفر في أوّل الرقم الوطنيّ لا يُحذف', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+9660'), '0');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966051234567'), '051234567');
    });

    test('المسافة الفاصلة بعد رمز الاتصال تُشذَّب', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966 512345678'), '512345678');
    });

    test('المُدخل الفاسد يعطي نصّاً فارغاً لا استثناءً', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode(''), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+'), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+999999999'), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('966512345678'), '');
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('نصّ'), '');
    });

    test('الرقم الوطنيّ المستخرَج لا يزيد أبداً على سعة الدولة', () {
      for (final String number in [saNumber, jmNumber, usNumber, gbNumber, asNumber]) {
        final String nsn = IntlPhoneUtils.getPhoneNumberByCountryDialCode(number);
        final int? cap = IntlPhoneUtils.getExactLength(number);
        expect(cap, isNotNull, reason: 'لا سعة لـ$number');
        expect(nsn.length <= cap!, isTrue, reason: '$number: $nsn أطول من السعة $cap');
      }
    });

    test('الرقم المنسّق بمسافات يُستخرَج منه الرقم الوطنيّ بأرقامه وحدها', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966 51 234 5678'), '512345678');
    });

    test('الشرطة التالية لرمز الاتصال لا تتصدّر الرقم الوطنيّ', () {
      // السلوك القائم يعيد «-51-234-5678» بشرطةٍ بادئة (trim يمسّ المسافات وحدها).
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966-51-234-5678'), '512345678');
    });

    test('الأرقام العربية-الهندية تُردّ إلى اللاتينية في الرقم المستخرَج', () {
      expect(IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966٥١٢٣٤٥٦٧٨'), '512345678');
    });
  });

  group('خريطة الدول والبحث برمز ISO', () {
    test('الخريطة تغطّي كل الدول وتُبنى مرّة واحدة', () {
      expect(IntlPhoneUtils.countriesMap.length, IntlPhoneUtils.countries.length);
      expect(IntlPhoneUtils.countriesMap['SA']?.code, 'SA');
      expect(IntlPhoneUtils.countriesMap['JM']?.dialCode, '1876');
      expect(IntlPhoneUtils.countriesMap['XX'], isNull);
      expect(identical(IntlPhoneUtils.countriesMap, IntlPhoneUtils.countriesMap), isTrue);
    });

    test('getCountryByCode يعطي الدولة، ويسقط إلى السعودية عند المجهول وnull', () {
      expect(IntlPhoneUtils.getCountryByCode('JM').dialCode, '1876');
      expect(IntlPhoneUtils.getCountryByCode('CA').code, 'CA');
      expect(IntlPhoneUtils.getCountryByCode(null).code, 'SA');
      expect(IntlPhoneUtils.getCountryByCode('').code, 'SA');
      expect(IntlPhoneUtils.getCountryByCode('ZZ').code, 'SA');
      // المطابقة حسّاسة لحالة الأحرف: «ca» مجهولٌ فيسقط إلى الافتراضيّ.
      expect(IntlPhoneUtils.getCountryByCode('ca').code, 'SA');
    });

    test('لا رمز ISO مكرّر في القائمة', () {
      final Set<String> seen = <String>{};
      final List<String> duplicates = [];
      for (final CountryModel c in IntlPhoneUtils.countries) {
        if (!seen.add(c.code)) duplicates.add(c.code);
      }
      expect(duplicates, isEmpty, reason: 'رموز مكرّرة: $duplicates');
    });
  });
}
