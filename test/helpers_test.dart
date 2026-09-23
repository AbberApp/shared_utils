import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار دوالّ `lib/src/utils/helpers.dart`:
/// [getFirstName] و[dismissKeyboard] و[convertArabicNumbers] و[launchWhatsApp].
///
/// `launchWhatsApp` تُختبر بمحاكاة قناة `url_launcher` والتقاط الرابط الذي
/// كانت ستفتحه، فنقرأ نصّ الرسالة المرسَلة إلى الدعم حرفاً بحرف.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getFirstName — الحالات السعيدة', () {
    test('اسم كامل من كلمتين يعيد الكلمة الأولى', () {
      expect(getFirstName('محمد أحمد'), 'محمد');
    });

    test('اسم ثلاثي يعيد الأولى فقط', () {
      expect(getFirstName('محمد أحمد علي'), 'محمد');
    });

    test('اسم مفرد يعيد نفسه بلا تغيير', () {
      expect(getFirstName('محمد'), 'محمد');
    });

    test('اسم لاتيني يعيد الكلمة الأولى', () {
      expect(getFirstName('John Smith'), 'John');
    });
  });

  group('getFirstName — المسافات', () {
    test('المسافات البادئة تُقصّ ولا تُعيد نصّاً فارغاً', () {
      // تراجع: الشطر على مسافة واحدة كان يعيد أوّل عنصرٍ فارغاً هنا.
      expect(getFirstName('   محمد أحمد'), 'محمد');
    });

    test('المسافات البادئة مع اسمٍ مفرد', () {
      expect(getFirstName('   محمد'), 'محمد');
    });

    test('المسافات اللاحقة لا تُلحق بالاسم', () {
      expect(getFirstName('محمد   '), 'محمد');
    });

    test('مسافات متعدّدة بين الاسمين لا تُنتج عنصراً فارغاً', () {
      expect(getFirstName('محمد     أحمد'), 'محمد');
    });

    test('التاب والسطر الجديد يُعاملان كفاصلٍ ويُقصّان', () {
      expect(getFirstName('\t\n محمد \t أحمد'), 'محمد');
    });

    test('المسافة غير الفاصلة (U+00A0) فاصلٌ أيضاً', () {
      expect(getFirstName('محمد أحمد'), 'محمد');
    });

    test('علامة ترتيب البايتات (U+FEFF) البادئة لا تلتصق بالاسم', () {
      expect(getFirstName('﻿محمد أحمد'), 'محمد');
    });
  });

  group('getFirstName — الحالات الحدّية', () {
    test('نصّ فارغ يعيد نصّاً فارغاً لا استثناءً', () {
      expect(getFirstName(''), '');
    });

    test('نصّ من مسافاتٍ فقط يعيد نصّاً فارغاً', () {
      // لا اسم في المُدخل، فالمخرج نصٌّ فارغ — لا المسافات نفسها غير مقصوصة.
      expect(getFirstName('     '), '');
      expect(getFirstName('\t'), '');
      expect(getFirstName('\n\n'), '');
    });

    test('اسمٌ بلا أيّ مسافة يُعاد بتمامه ولو حوى رابطاً صفريّ العرض', () {
      // ZWJ (U+200D) ليس فراغاً، فلا يُشطر عنده الاسم.
      expect(getFirstName('محمد‍أحمد'), 'محمد‍أحمد');
    });

    test('علامات الترقيم جزءٌ من الكلمة الأولى', () {
      expect(getFirstName('د. محمد'), 'د.');
    });

    test('اسم طويل جدًّا يُعاد كاملاً بلا اقتطاع', () {
      final longName = 'م' * 5000;
      expect(getFirstName('$longName أحمد'), longName);
      expect(getFirstName('$longName أحمد').length, 5000);
    });

    test('الاسم المركّب يُعيد الشطر الأوّل فقط («عبد» لا «عبد الله»)', () {
      // سلوكٌ مقصود: الشطر على الفراغ لا يعرف الأسماء المركّبة.
      expect(getFirstName('عبد الله بن محمد'), 'عبد');
      expect(getFirstName('عبد الرحمن السالم'), 'عبد');
    });

    test('الاسم المركّب بلا لاحقةٍ يبقى كما هو حين يكون كلمةً واحدة', () {
      expect(getFirstName('عبدالله'), 'عبدالله');
    });

    test('الأرقام والرموز في الاسم لا تُصفّى', () {
      expect(getFirstName('user_1 test'), 'user_1');
    });
  });

  group('convertArabicNumbers — إعادة التصدير للتوافقية', () {
    test('يحوّل الأرقام العربية-الهندية إلى لاتينية', () {
      expect(convertArabicNumbers('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('نصّ فارغ يبقى فارغاً', () {
      expect(convertArabicNumbers(''), '');
    });

    test('نصّ بلا أرقام يبقى كما هو', () {
      expect(convertArabicNumbers('محمد'), 'محمد');
    });

    test('يطابق convertArabicToEnglishNumbers حرفاً بحرف', () {
      const samples = <String>['٥٣١١٩٦١١٢', 'رقم ٩٦٦', '', '12.5'];
      for (final s in samples) {
        expect(convertArabicNumbers(s), convertArabicToEnglishNumbers(s));
      }
    });
  });

  group('dismissKeyboard', () {
    testWidgets('يُزيل التركيز عن الحقل المركَّز', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return TextField(focusNode: focusNode);
              },
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      dismissKeyboard(capturedContext);
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('آمنٌ حين لا يوجد تركيزٌ أصلاً', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(() => dismissKeyboard(capturedContext), returnsNormally);
      await tester.pump();
    });
  });

  group('launchWhatsApp — نصّ رسالة الدعم', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];

    /// نصّ الرسالة كما يصل إلى واتساب داخل الرابط
    String messageOf(String url) => Uri.parse(url).queryParameters['text'] ?? '';

    setUp(() {
      launchedUrls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'canLaunch':
                return true;
              case 'launch':
                launchedUrls.add(
                  (call.arguments as Map<Object?, Object?>)['url'] as String,
                );
                return true;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      DeviceInfoManager.instance.reset();
    });

    test('لا يتسرّب «null» إلى الرسالة حين لم يُهيَّأ المدير قبل الضغط', () async {
      // تراجع: الدالّة كانت تقرأ infoOrNull بلا انتظار التهيئة، والتوثيق يوصي
      // بنداء initialize() بلا await، فكان الدعم يتلقّى «النظام: null, null».
      DeviceInfoManager.instance.reset();

      await launchWhatsApp(
        phoneNumber: '+966 53 119 6112',
        deviceInfo: DeviceInfoManager.instance,
        userId: '42',
      );

      expect(launchedUrls, hasLength(1));
      final message = messageOf(launchedUrls.single);
      expect(message, isNot(contains('null')));
      expect(message, contains('رقم المستخدم: 42'));
      expect(message, matches(RegExp(r'نسخة التطبيق: \S+')));
      // وليست قيمة البديل «غير معروف» وحدها: الدالّة انتظرت التهيئة فعلاً
      // فوصلت القيم الحقيقية، لا مجرّد نصٍّ بديل يُخفي الفقد.
      expect(DeviceInfoManager.instance.isInitialized, isTrue);
      expect(
        message,
        contains('النظام: ${DeviceInfoManager.instance.info.system.osName}'),
      );
    });

    test('يحمل قيم النظام ونسخة التطبيق الفعلية بعد التهيئة', () async {
      final info = await DeviceInfoManager.instance.ensureInitialized();

      await launchWhatsApp(
        phoneNumber: '966531196112',
        deviceInfo: DeviceInfoManager.instance,
      );

      final message = messageOf(launchedUrls.single);
      expect(message, contains('النظام: ${info.system.osName}'));
      expect(message, contains('نسخة التطبيق: ${info.app.fullVersion}'));
      // بلا userId تُكتب العبارة البديلة لا «null»
      expect(message, contains('رقم المستخدم: مستخدم غير مسجل'));
    });

    test('الرسالة المخصّصة تتصدّر النصّ', () async {
      await launchWhatsApp(
        phoneNumber: '966531196112',
        deviceInfo: DeviceInfoManager.instance,
        message: 'مشكلة في الدفع',
      );

      expect(messageOf(launchedUrls.single), startsWith('مشكلة في الدفع'));
    });

    test('الأرقام العربية-الهندية تُوحَّد في رقم الوجهة', () async {
      await launchWhatsApp(
        phoneNumber: '+٩٦٦ ٥٣ ١١٩ ٦١١٢',
        deviceInfo: DeviceInfoManager.instance,
      );

      expect(launchedUrls, isNotEmpty);
      expect(
        Uri.parse(launchedUrls.first).queryParameters['phone'],
        '966531196112',
      );
    });
  });
}
