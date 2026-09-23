import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `StringExtension` — امتدادات النصّ في
/// `lib/src/utils/extensions/string_extension.dart`.
///
/// دوالّ نقيّة بلا حالة ولا اعتماديات، فالاختبار مباشر بلا محاكاة.
/// التركيز على الحدود لا على الحالة السعيدة: الفارغ، والمشوّه، والعربي،
/// والطويل جدًّا، ومواضع الإتلاف الصامت للبيانات.
void main() {
  // ═════════════════════════════════════════════════════════════════════
  // isValidEmail
  // ═════════════════════════════════════════════════════════════════════
  group('isValidEmail — البريد الإلكتروني', () {
    test('يقبل الصيغ الصحيحة الشائعة', () {
      expect('user@email.com'.isValidEmail, isTrue);
      expect('a@b.co'.isValidEmail, isTrue);
      expect('user+tag@gmail.com'.isValidEmail, isTrue);
      expect('first.last@sub.domain.co.uk'.isValidEmail, isTrue);
      expect('user_name@email.com'.isValidEmail, isTrue);
      expect("o'brien@email.com".isValidEmail, isTrue);
    });

    test('لا يميّز بين الأحرف الكبيرة والصغيرة', () {
      expect('USER@EMAIL.COM'.isValidEmail, isTrue);
      expect('User@Email.Com'.isValidEmail, isTrue);
    });

    test('يرفض النصّ الفارغ والمسافات وحدها', () {
      expect(''.isValidEmail, isFalse);
      expect(' '.isValidEmail, isFalse);
      expect('   '.isValidEmail, isFalse);
    });

    test('يرفض البنية الناقصة (بلا @ أو بلا طرف)', () {
      expect('useremail.com'.isValidEmail, isFalse);
      expect('user@'.isValidEmail, isFalse);
      expect('@email.com'.isValidEmail, isFalse);
      expect('@'.isValidEmail, isFalse);
      expect('user@@email.com'.isValidEmail, isFalse);
      expect('user@a@b.com'.isValidEmail, isFalse);
    });

    test('يرفض نطاقاً بلا لاحقة أو بلاحقة من حرف واحد', () {
      expect('user@email'.isValidEmail, isFalse);
      expect('user@email.c'.isValidEmail, isFalse);
      expect('user@.com'.isValidEmail, isFalse);
      expect('user@email.'.isValidEmail, isFalse);
    });

    test('يرفض النقاط المتتالية في الاسم أو النطاق', () {
      expect('user..name@email.com'.isValidEmail, isFalse);
      expect('.user@email.com'.isValidEmail, isFalse);
      expect('user.@email.com'.isValidEmail, isFalse);
      expect('user@email..com'.isValidEmail, isFalse);
    });

    test('يرفض المحارف المحظورة والمسافات داخل العنوان', () {
      expect('user name@email.com'.isValidEmail, isFalse);
      expect('us;er@email.com'.isValidEmail, isFalse);
      expect('us,er@email.com'.isValidEmail, isFalse);
      expect('<user>@email.com'.isValidEmail, isFalse);
      expect('user@exam_ple.com'.isValidEmail, isFalse); // الشرطة السفلية ممنوعة في المضيف
      expect('user@email.com,other@email.com'.isValidEmail, isFalse);
    });

    test('يرفض المسافات المحيطة ولا يقتطعها ضمناً', () {
      // الاقتطاع الضمني يخفي خطأ المستخدم ثمّ يرسل الخادمُ بريداً بمسافة.
      expect(' user@email.com'.isValidEmail, isFalse);
      expect('user@email.com '.isValidEmail, isFalse);
      expect('\tuser@email.com'.isValidEmail, isFalse);
    });

    test('المرساة محكمة: سطر جديد لا يمرّر بريداً مشوّهاً', () {
      // `$` في Dart لا يتساهل مع سطرٍ أخير — تراجع مهمّ لو غُيّر النمط يوماً.
      expect('user@email.com\n'.isValidEmail, isFalse);
      expect('user@email.com\nمرفوض'.isValidEmail, isFalse);
      expect('سطر\nuser@email.com'.isValidEmail, isFalse);
    });

    test('يقبل عنوان IP بين قوسين معقوفين ويرفضه عارياً', () {
      expect('user@[192.168.1.1]'.isValidEmail, isTrue);
      expect('user@192.168.1.1'.isValidEmail, isFalse);
      expect('user@[999999.1.1.1]'.isValidEmail, isFalse);
    });

    test('يقبل اسماً عربياً قبل @ (بريد مُدوَّل)', () {
      expect('مستخدم@example.com'.isValidEmail, isTrue);
      expect('محمد.أحمد@example.com'.isValidEmail, isTrue);
    });

    test('يرفض نطاقاً عربياً غير مُرمَّز (يلزم punycode)', () {
      // العقد بأن يكون النطاق ASCII؛ على المستدعي ترميز النطاقات المدوَّلة.
      expect('user@مثال.com'.isValidEmail, isFalse);
      expect('user@example.شبكة'.isValidEmail, isFalse);
    });

    test('يرفض نطاقاً يبدأ أو ينتهي بشرطة', () {
      // مقاطع المضيف لا تبدأ ولا تنتهي بشرطة (RFC 1123).
      expect('user@-email.com'.isValidEmail, isFalse);
      expect('user@email-.com'.isValidEmail, isFalse);
    });

    test('مُدخل طويل جدًّا يُرفض بلا تعليق (لا تراجع كارثي)', () {
      final String long = 'a' * 20000;
      expect(long.isValidEmail, isFalse);
      expect('$long@$long'.isValidEmail, isFalse);
      // الطويل الصحيح يبقى صحيحاً (لا حدّ طولٍ مصطنع في هذه الدالّة).
      expect('$long@example.com'.isValidEmail, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // isAllDigits
  // ═════════════════════════════════════════════════════════════════════
  group('isAllDigits — أرقام فقط', () {
    test('يقبل الأرقام اللاتينية وحدها مع الأصفار البادئة', () {
      expect('12345'.isAllDigits, isTrue);
      expect('0'.isAllDigits, isTrue);
      expect('007'.isAllDigits, isTrue);
      expect('0000'.isAllDigits, isTrue);
    });

    test('يرفض النصّ الفارغ', () {
      expect(''.isAllDigits, isFalse);
    });

    test('يرفض الخليط والمسافات والإشارات', () {
      expect('12a'.isAllDigits, isFalse);
      expect('a12'.isAllDigits, isFalse);
      expect('1 2'.isAllDigits, isFalse);
      expect(' 12'.isAllDigits, isFalse);
      expect('12 '.isAllDigits, isFalse);
      expect('-1'.isAllDigits, isFalse);
      expect('+1'.isAllDigits, isFalse);
      expect('1.5'.isAllDigits, isFalse);
      expect('1,000'.isAllDigits, isFalse);
    });

    test('يرفض الأرقام العربية-الهندية (العقد: ASCII فقط)', () {
      // مهمّ: `int.parse('٣')` يفشل، فقبولها هنا يعني انفجاراً عند المستدعي.
      expect('٠١٢٣'.isAllDigits, isFalse);
      expect('١٢٣'.isAllDigits, isFalse);
      expect('12٣'.isAllDigits, isFalse);
      // وللتحويل توجد `toArabicDigits` في الاتجاه المعاكس فقط.
      expect(123.toArabicDigits, '١٢٣');
    });

    test('يرفض النصّ العربي والرموز', () {
      expect('مرحبا'.isAllDigits, isFalse);
      expect('١٢٣ ريال'.isAllDigits, isFalse);
      expect('#123'.isAllDigits, isFalse);
      expect('😀'.isAllDigits, isFalse);
    });

    test('المرساة محكمة: سطر جديد لا يمرّ', () {
      expect('123\n'.isAllDigits, isFalse);
      expect('\n123'.isAllDigits, isFalse);
      expect('12\n34'.isAllDigits, isFalse);
    });

    test('سلسلة أرقام طويلة جدًّا تُقبل بلا تعليق', () {
      expect(('9' * 20000).isAllDigits, isTrue);
      expect('${'9' * 20000}x'.isAllDigits, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // isValidDecimal
  // ═════════════════════════════════════════════════════════════════════
  group('isValidDecimal — رقم عشري', () {
    test('يقبل الصحيح والعشري بصوره المعتادة', () {
      expect('1'.isValidDecimal, isTrue);
      expect('0'.isValidDecimal, isTrue);
      expect('1.5'.isValidDecimal, isTrue);
      expect('0.0'.isValidDecimal, isTrue);
      expect('12345.6789'.isValidDecimal, isTrue);
      expect('000'.isValidDecimal, isTrue);
    });

    test('يرفض النصّ الفارغ', () {
      expect(''.isValidDecimal, isFalse);
    });

    test('يرفض النقطة المنفردة `.` (كانت تُقبل فينفجر double.parse)', () {
      expect('.'.isValidDecimal, isFalse);
      expect('..'.isValidDecimal, isFalse);
      expect('...'.isValidDecimal, isFalse);
      // البرهان على أنّ الرفض هو الصواب:
      expect(() => double.parse('.'), throwsFormatException);
    });

    test('يقبل `1.` و`.5` لأنّ double.parse يقبلهما فعلاً', () {
      expect('1.'.isValidDecimal, isTrue);
      expect('.5'.isValidDecimal, isTrue);
      expect(double.parse('1.'), 1.0);
      expect(double.parse('.5'), 0.5);
    });

    test('كلّ ما يقبله isValidDecimal يجتازه double.parse فعلاً', () {
      // العقد الجوهري للدالّة: لا تُمرّر ما ينفجر عند المستدعي.
      final List<String> accepted = <String>[
        '0', '1', '007', '1.', '.5', '1.5', '0.0', '12345.6789', '9' * 40,
      ];
      for (final String s in accepted) {
        expect(s.isValidDecimal, isTrue, reason: 'رُفض المقبول: $s');
        expect(() => double.parse(s), returnsNormally, reason: 'انفجر: $s');
      }
    });

    test('يرفض أكثر من نقطة واحدة', () {
      expect('1.2.3'.isValidDecimal, isFalse);
      expect('1..2'.isValidDecimal, isFalse);
      expect('.1.'.isValidDecimal, isFalse);
      expect('1.2.3.4'.isValidDecimal, isFalse);
    });

    test('يرفض الإشارة (العقد: أرقام ونقطة فقط)', () {
      // على المستدعي معالجة السالب صراحةً — لا قبول ضمنيّ هنا.
      expect('-1'.isValidDecimal, isFalse);
      expect('-1.5'.isValidDecimal, isFalse);
      expect('+1.5'.isValidDecimal, isFalse);
      expect('1-'.isValidDecimal, isFalse);
    });

    test('يرفض الصيغة العلمية والفاصلة والمسافات والحروف', () {
      expect('1e3'.isValidDecimal, isFalse);
      expect('1E3'.isValidDecimal, isFalse);
      expect('1,5'.isValidDecimal, isFalse);
      expect('12,345.67'.isValidDecimal, isFalse);
      expect(' 1.5'.isValidDecimal, isFalse);
      expect('1.5 '.isValidDecimal, isFalse);
      expect('1.5a'.isValidDecimal, isFalse);
      expect('abc'.isValidDecimal, isFalse);
      expect('Infinity'.isValidDecimal, isFalse);
      expect('NaN'.isValidDecimal, isFalse);
    });

    test('يرفض الأرقام العربية-الهندية والعربي عموماً', () {
      expect('١.٥'.isValidDecimal, isFalse);
      expect('٣'.isValidDecimal, isFalse);
      expect('واحد فاصلة خمسة'.isValidDecimal, isFalse);
    });

    test('المرساة محكمة: سطر جديد لا يمرّ', () {
      expect('1.5\n'.isValidDecimal, isFalse);
      expect('\n1.5'.isValidDecimal, isFalse);
    });

    test('مُدخل طويل جدًّا يُحسم بلا تعليق', () {
      expect(('9' * 20000).isValidDecimal, isTrue);
      final String half = '9' * 10000;
      expect('$half.$half'.isValidDecimal, isTrue);
      expect('$half.$half.$half'.isValidDecimal, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // capitalized
  // ═════════════════════════════════════════════════════════════════════
  group('capitalized — تكبير الحرف الأوّل', () {
    test('يكبّر الحرف الأوّل ويترك الباقي كما هو', () {
      expect('hello'.capitalized, 'Hello');
      expect('hello world'.capitalized, 'Hello world');
      expect('hELLO'.capitalized, 'HELLO');
      expect('HELLO'.capitalized, 'HELLO');
    });

    test('نصّ فارغ يرجع فارغاً بلا انفجار', () {
      expect(''.capitalized, '');
    });

    test('حرف واحد', () {
      expect('a'.capitalized, 'A');
      expect('A'.capitalized, 'A');
      expect('z'.capitalized, 'Z');
    });

    test('العربي لا يتغيّر ولا يُتلَف (لا حالة أحرف في العربية)', () {
      expect('محمد'.capitalized, 'محمد');
      expect('أحمد بن علي'.capitalized, 'أحمد بن علي');
      expect('م'.capitalized, 'م');
      // الطول يبقى كما هو — لا اقتطاع ولا تكرار.
      expect('مرحبا بالعالم'.capitalized.length, 'مرحبا بالعالم'.length);
    });

    test('ما ليس حرفاً يبقى كما هو ولا يُقتطع', () {
      expect('1abc'.capitalized, '1abc');
      expect('_abc'.capitalized, '_abc');
      expect(' hello'.capitalized, ' hello'); // لا اقتطاع للمسافة البادئة
      expect('-'.capitalized, '-');
    });

    test('الأزواج البديلة (إيموجي) لا تُشوَّه', () {
      // this[0] يأخذ وحدة UTF-16 واحدة؛ المطلوب ألّا يُكسر الزوج البديل.
      expect('😀abc'.capitalized, '😀abc');
      expect('😀'.capitalized, '😀');
      expect('😀abc'.capitalized.runes.first, '😀'.runes.first);
    });

    test('نصّ طويل جدًّا: حرف أوّل فقط ولا مساس بالباقي', () {
      final String long = 'a' * 20000;
      final String result = long.capitalized;
      expect(result.length, long.length);
      expect(result[0], 'A');
      expect(result.substring(1), long.substring(1));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // withoutBrackets
  // ═════════════════════════════════════════════════════════════════════
  group('withoutBrackets — إزالة الأقواس', () {
    test('يزيل القوسين المعقوفين والهلاليين المتطابقين', () {
      expect('[a,b]'.withoutBrackets, 'a,b');
      expect('(a,b)'.withoutBrackets, 'a,b');
      expect('[1, 2, 3]'.withoutBrackets, '1, 2, 3');
      expect('[مرحبا]'.withoutBrackets, 'مرحبا');
    });

    test('نصّ بلا أقواس يبقى كما هو (كان يقصّ محرفين من أيّ نصّ)', () {
      // التراجع الأهمّ: الاقتطاع الأعمى كان يُتلف البيانات صامتاً.
      expect('a,b'.withoutBrackets, 'a,b');
      expect('hello'.withoutBrackets, 'hello');
      expect('1, 2, 3'.withoutBrackets, '1, 2, 3');
      expect('مرحبا بالعالم'.withoutBrackets, 'مرحبا بالعالم');
      expect('SA4420000001234567891234'.withoutBrackets, 'SA4420000001234567891234');
    });

    test('نصّ فارغ أو محرف واحد يرجع كما هو', () {
      expect(''.withoutBrackets, '');
      expect('a'.withoutBrackets, 'a');
      expect('['.withoutBrackets, '[');
      expect(']'.withoutBrackets, ']');
      expect('('.withoutBrackets, '(');
    });

    test('القوسان الفارغان يُنتجان نصّاً فارغاً', () {
      expect('[]'.withoutBrackets, '');
      expect('()'.withoutBrackets, '');
    });

    test('لا يقتطع إلا إذا تطابق النوعان في الطرفين', () {
      expect('[a)'.withoutBrackets, '[a)');
      expect('(a]'.withoutBrackets, '(a]');
      expect('[a'.withoutBrackets, '[a');
      expect('a]'.withoutBrackets, 'a]');
      expect('a[b]c'.withoutBrackets, 'a[b]c'); // الأقواس في الوسط لا تُمسّ
    });

    test('يزيل طبقة واحدة فقط من التداخل', () {
      expect('[[a]]'.withoutBrackets, '[a]');
      expect('[(a)]'.withoutBrackets, '(a)');
    });

    test('نصّ طويل بين قوسين', () {
      final String long = 'x' * 20000;
      expect('[$long]'.withoutBrackets, long);
      expect(long.withoutBrackets, long);
    });

    test('قائمتان متجاورتان لا تُقتطعان (الطرفان ليسا قوسين متقابلين)', () {
      // '[a],[b]' يبدأ بـ '[' وينتهي بـ ']' لكنّهما ليسا زوجاً واحداً،
      // فالاقتطاع يُنتج 'a],[b' — إتلاف صامت، وهو ذات العيب الذي عولج للنصّ
      // بلا أقواس. الصواب: عدم المساس ما لم يكن القوسان متقابلين فعلاً.
      expect('[a],[b]'.withoutBrackets, '[a],[b]');
      expect('(a)+(b)'.withoutBrackets, '(a)+(b)');
    });
  });
}
