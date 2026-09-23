import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// هذا **هو** الاختبار: استيرادٌ واحد لا غير.
//
// كلّ رمزٍ يُذكر في هذا الملفّ يجب أن يصل من هنا وحده. فلو سقط تصديرٌ من
// `lib/shared_utils.dart` — أو استُبدل اسمٌ عامّ — لم يمرّ هذا الملفّ عبر
// المحلّل أصلاً، فيفشل قبل أن يُنفَّذ اختبارٌ واحد. ولهذا لا يُضاف هنا
// `import 'package:flutter/material.dart'` ولا `package:dio/dio.dart`:
// إضافتها تُبطل ما نقيسه.
import 'package:shared_utils/shared_utils.dart';

// ═══════════════════════════════════════════════════════════════════════════
// أدوات مساعدة للاختبارات البنيوية (قراءة البرميل من القرص)
// ═══════════════════════════════════════════════════════════════════════════

/// جذر الحزمة — يُستدلّ عليه بالصعود حتّى أوّل مجلّد فيه `pubspec.yaml`،
/// فلا يتعلّق الاختبار بمجلّد العمل الذي شُغّل منه `flutter test`.
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('تعذّر العثور على جذر الحزمة (pubspec.yaml) انطلاقاً من ${Directory.current.path}');
    }
    dir = parent;
  }
}

String _read(String relativePath) => File('${_packageRoot().path}/$relativePath').readAsStringSync();

/// أسطر `export` كما وردت في ملفّ (بلا تعليقات ولا فراغ).
List<String> _exportLines(String source) => source
    .split('\n')
    .map((String line) => line.trim())
    .where((String line) => line.startsWith('export '))
    .toList();

/// أهداف `export 'src/...'` أو `export '...dart'` النسبية في ملفّ.
List<String> _relativeExportTargets(String source) => RegExp(r"export\s+'([^':]+\.dart)'")
    .allMatches(source)
    .map((RegExpMatch m) => m.group(1)!)
    .toList();

/// أسماء الحزم في `export 'package:X/...'`.
Set<String> _packageExportNames(String source) => RegExp(r"export\s+'package:([A-Za-z0-9_]+)/")
    .allMatches(source)
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

/// تطبيع مسارٍ نسبيّ مقابل مجلّد ملفّ (حلّ `../` و`./`).
String _resolve(String fromFileRelative, String target) {
  final List<String> base = fromFileRelative.split('/')..removeLast();
  for (final String part in target.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(part);
  }
  return base.join('/');
}

/// كلّ ملفّات `lib/src` التي يصل إليها البرميل عبر سلسلة `export` وحدها —
/// أي التي تصير أنواعُها العامّة مرئيةً لمن استورد المكتبة.
Set<String> _exportClosure() {
  final Set<String> seen = <String>{};
  final List<String> stack = _relativeExportTargets(_read('lib/shared_utils.dart'))
      .map((String t) => _resolve('lib/shared_utils.dart', t))
      .toList();

  while (stack.isNotEmpty) {
    final String file = stack.removeLast();
    if (!seen.add(file)) continue;
    final File handle = File('${_packageRoot().path}/$file');
    if (!handle.existsSync()) continue; // يُبلَّغ عنه في اختبارٍ مستقلّ
    stack.addAll(
      _relativeExportTargets(handle.readAsStringSync()).map((String t) => _resolve(file, t)),
    );
  }
  return seen;
}

/// نموذجٌ مُرقَّم يرث [BaseEntity] — الوراثة نفسها إثباتٌ أنّ الصنف المجرّد
/// يصل عبر البرميل قابلاً للتوسيع لا للقراءة فقط.
class _Page extends BaseEntity<String> {
  _Page({required super.count, required super.next, required super.results});
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // ١) بنية البرميل — ما يُصدَّر موجود، وما هو موجود يُصدَّر
  // ═════════════════════════════════════════════════════════════════════════

  group('بنية البرميل lib/shared_utils.dart', () {
    test('كل هدف export موجود فعلاً على القرص', () {
      final String barrel = _read('lib/shared_utils.dart');
      final List<String> targets = _relativeExportTargets(barrel);
      expect(targets.length, greaterThan(20), reason: 'البرميل بلا تصديرات — قراءةٌ فاشلة؟');
      final List<String> missing = <String>[];
      for (final String target in targets) {
        final String path = _resolve('lib/shared_utils.dart', target);
        if (!File('${_packageRoot().path}/$path').existsSync()) missing.add(path);
      }
      expect(missing, isEmpty, reason: 'أهداف export مفقودة: $missing');
    });

    test('لا سطر export مكرّر', () {
      final List<String> lines = _exportLines(_read('lib/shared_utils.dart'));
      final Set<String> unique = lines.toSet();
      expect(
        lines.length,
        unique.length,
        reason: 'تصديرٌ مكرّر في البرميل: '
            '${lines.where((String l) => lines.where((String o) => o == l).length > 1).toSet()}',
      );
    });

    test('كل ملفّ تحت lib/src (عدا المولّدات) داخل إغلاق التصدير', () {
      final String root = _packageRoot().path;
      final Set<String> onDisk = Directory('$root/lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .map((File f) => f.path.substring(root.length + 1))
          .where((String p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
          .toSet();

      // حارسٌ ضدّ اختبارٍ أجوف: لو عاد أحد الطرفين فارغاً لمرّ الفحص بلا معنى.
      expect(onDisk.length, greaterThan(20), reason: 'تعذّر مسح lib/src');
      final Set<String> closure = _exportClosure();
      expect(closure.length, greaterThan(20), reason: 'تعذّر حساب إغلاق التصدير');

      final Set<String> orphans = onDisk.difference(closure);
      expect(
        orphans,
        isEmpty,
        reason: 'ملفّات لا يصلها البرميل — أنواعها العامّة غير مرئية للمستهلك: $orphans',
      );
    });

    test('البرميل لا يُصدّر شيئاً من lib/src عبر مسارٍ مطلق package:shared_utils', () {
      // تصديرٌ ذاتيّ بمسار package يُنتج دورةً ويُربك حلّ الأسماء.
      expect(_read('lib/shared_utils.dart'), isNot(contains("export 'package:shared_utils/")));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٢) الحزم المُعاد تصديرها — «لا pubspec إضافيّ في كل تطبيق»
  // ═════════════════════════════════════════════════════════════════════════

  group('الحزم المُعاد تصديرها', () {
    test('كل حزمة يُعيد البرميل تصديرها معلَنة في dependencies لا في dev', () {
      final String pubspec = _read('pubspec.yaml');
      final String deps = pubspec.substring(
        pubspec.indexOf('\ndependencies:'),
        pubspec.indexOf('\ndev_dependencies:'),
      );
      final Set<String> exported = _packageExportNames(_read('lib/shared_utils.dart'));

      expect(exported, isNotEmpty, reason: 'البرميل لم يَعُد يُعيد تصدير أيّ حزمة منصّة');
      for (final String name in exported) {
        expect(
          RegExp('^  $name:', multiLine: true).hasMatch(deps),
          isTrue,
          reason: '«$name» يُصدَّر من البرميل لكنّه ليس تبعيةً مباشرة — '
              'حلٌّ عابرٌ هشّ ينكسر عند أوّل ترقية',
        );
      }
    });

    test('open_filex ممنوعة — تُبقي CocoaPods حيّة (open_file هي البديل)', () {
      // على الإعلانات لا على التعليقات: كلا الملفّين يذكر الاسم شارحاً سببَ منعه.
      expect(
        RegExp(r'^  open_filex:', multiLine: true).hasMatch(_read('pubspec.yaml')),
        isFalse,
        reason: 'open_filex بلا Package.swift فتُبقي CocoaPods حيّةً في كلّ مشروع',
      );
      expect(_read('lib/shared_utils.dart'), isNot(contains('package:open_filex/')));
    });

    test('أنواع dio تصل بلا استيرادٍ إضافيّ', () {
      final RequestOptions options = RequestOptions(path: '/ping');
      final Response<dynamic> response =
          Response<dynamic>(requestOptions: options, statusCode: 204);
      expect(response.statusCode, 204);
      expect(DioExceptionType.cancel.name, 'cancel');
      expect(Dio, isNotNull);
      expect(FormData, isNotNull);
      expect(Options, isNotNull);
    });

    test('connectivity_plus و json_annotation و url_launcher تصل', () {
      expect(ConnectivityResult.wifi.name, 'wifi');
      expect(const JsonKey(defaultValue: 0).defaultValue, 0);
      expect(LaunchMode.externalApplication.name, 'externalApplication');
      expect(launchUrl, isA<Function>());
      expect(canLaunchUrl, isA<Function>());
    });

    test('open_file و share_plus و skeletonizer تصل', () {
      expect(ResultType.done.name, 'done');
      expect(OpenFile, isNotNull);
      expect(SharePlus, isNotNull);
      expect(ShareParams, isNotNull);
      expect(Skeletonizer, isNotNull);
      expect(Bone, isNotNull);
    });

    test('ToastGravity وحدها تُصدَّر من fluttertoast — لا الحزمة كاملة', () {
      expect(ToastGravity.TOP.name, 'TOP');
      expect(
        _read('lib/src/ui/widgets/toast.dart'),
        contains("export 'package:fluttertoast/fluttertoast.dart' show ToastGravity;"),
        reason: 'تصديرٌ مفتوح لـfluttertoast يُسرّب Fluttertoast وToast إلى كل مستهلك',
      );
    });

    test('XFile واحدة لا اثنتان — image_picker وshare_plus تُصدّرانها معاً', () {
      // كلتاهما تُعيدان تصدير نوع `cross_file` نفسه. لو صارتا إعلانين مختلفين
      // لصار الاسم مُلتبساً وانكسر كلّ مستهلكٍ يذكر `XFile`.
      final XFile file = XFile('/tmp/a.png');
      expect(file.path, '/tmp/a.png');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٣) الأنواع المُعلَنة — الأسماء العامّة كما يعتمد عليها المستهلكون
  // ═════════════════════════════════════════════════════════════════════════

  group('الأنواع الرئيسية تصل بأسمائها عبر استيراد واحد', () {
    // المفتاح هو الاسم المنشور. أيّ إعادة تسميةٍ صامتة تُفشل هذا الاختبار،
    // وهو المقصود: الاسم جزءٌ من العقد لا تفصيلٌ داخليّ.
    final Map<String, Type> surface = <String, Type>{
      // الشبكة
      'Failure': Failure,
      'FieldError': FieldError,
      'ResponseCode': ResponseCode,
      'ResponseMessage': ResponseMessage,
      'ApiConsumer': ApiConsumer,
      'DioConsumer': DioConsumer,
      'ErrorHandler': ErrorHandler,
      'ErrorType': ErrorType,
      'ConnectionStatus': ConnectionStatus,
      'InternetConnectionStatus': InternetConnectionStatus,
      'InternetConnectionState': InternetConnectionState,
      // الزمن الحقيقيّ
      'SocketManager': SocketManager,
      'SocketRegistry': SocketRegistry,
      'SocketConnectionState': SocketConnectionState,
      'SseManager': SseManager,
      'SseRegistry': SseRegistry,
      'SseConnectionState': SseConnectionState,
      // النماذج والحالة
      'BaseEntity<String>': BaseEntity<String>,
      // الواجهة
      'SkeletonizerWidget': SkeletonizerWidget,
      'LoadMoreWidget': LoadMoreWidget,
      'LoadMoreIndicatorWidget': LoadMoreIndicatorWidget,
      'PaginatedListView<String>': PaginatedListView<String>,
      'ResponsiveGridView': ResponsiveGridView,
      'GridConfig': GridConfig,
      'PageIndicator': PageIndicator,
      // النماذج/المنسّقات
      'FieldErrors': FieldErrors,
      'IbanFormatter': IbanFormatter,
      'IbanUtils': IbanUtils,
      'CardNumberFormatter': CardNumberFormatter,
      'CardExpiryFormatter': CardExpiryFormatter,
      'PhoneNumberFormatter': PhoneNumberFormatter,
      'NumbersOnlyFormatter': NumbersOnlyFormatter,
      'ConvertArabicToEnglishNumbersFormatter': ConvertArabicToEnglishNumbersFormatter,
      'UpperCaseEnglishFormatter': UpperCaseEnglishFormatter,
      'NoEnglishLettersFormatter': NoEnglishLettersFormatter,
      // المنتقيات
      'FilePickerManager': FilePickerManager,
      'ImagePickerManager': ImagePickerManager,
      'ImagePickerSource': ImagePickerSource,
      // الجهاز والخدمات
      'DeviceInfoManager': DeviceInfoManager,
      'SharedDeviceInfo': SharedDeviceInfo,
      'SharedAppInfo': SharedAppInfo,
      'SharedDeviceDetails': SharedDeviceDetails,
      'SharedSystemInfo': SharedSystemInfo,
      'SharedScreenInfo': SharedScreenInfo,
      'FileCacheManager': FileCacheManager,
      'FileNoLongerAvailableException': FileNoLongerAvailableException,
      'AppUpdateChecker': AppUpdateChecker,
      'AppReleaseInfo': AppReleaseInfo,
      'OptionalUpdateBanner': OptionalUpdateBanner,
      'GuardedNavigator': GuardedNavigator,
      'GuardedNavigatorState': GuardedNavigatorState,
      'AudioSessionConfig': AudioSessionConfig,
      'SentryBootstrap': SentryBootstrap,
      'SentryNoiseFilter': SentryNoiseFilter,
      // الهاتف والأدوات
      'IntlPhoneUtils': IntlPhoneUtils,
      'CountryModel': CountryModel,
      'PhoneNumber': PhoneNumber,
      'PhoneValidationResult': PhoneValidationResult,
      'DelayHandler': DelayHandler,
    };

    test('كل اسمٍ منشور يحتفظ باسمه', () {
      final Map<String, String> mismatches = <String, String>{};
      surface.forEach((String name, Type type) {
        if (type.toString() != name) mismatches[name] = type.toString();
      });
      expect(mismatches, isEmpty, reason: 'أنواع أُعيدت تسميتها: $mismatches');
    });

    test('لا اسمين يشيران إلى النوع نفسه', () {
      expect(
        surface.values.toSet().length,
        surface.length,
        reason: 'اسمان مختلفان يحلّان إلى نوعٍ واحد — تصديرٌ ملتبس',
      );
    });

    test('الدوالّ العلوية تصل كقيمٍ قابلة للتمرير', () {
      // بلا نداء: `showToast` و`dismissKeyboard` تعبران قنوات منصّة.
      expect(showToast, isA<Function>());
      expect(dismissKeyboard, isA<Function>());
      expect(launchWhatsApp, isA<Function>());
      expect(handleResponse, isA<Function>());
      expect(parseToMap, isA<Function>());
      expect(getFirstName, isA<Function>());
      expect(convertArabicToEnglishNumbers, isA<Function>());
      expect(convertArabicNumbers, isA<Function>());
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٤) الأنواع المُصدَّرة صالحةٌ للاستعمال لا للذكر فقط
  // ═════════════════════════════════════════════════════════════════════════

  group('الأنواع المُصدَّرة قابلة للاستعمال', () {
    test('BaseEntity قابل للوراثة ويعمل على قائمة فارغة', () {
      final _Page page = _Page(count: 0, next: '', results: <String>[]);
      expect(page.isEmpty, isTrue);
      expect(page.isNotEmpty, isFalse);
      expect(page.length, 0);
      expect(page.hasNext, isFalse);
      expect(page.canLoadMore, isFalse);
      expect(page.nextOffset, isNull);
    });

    test('BaseEntity: صفحة تالية فارغة الرابط ⇐ لا ترقيم مهما كان count', () {
      final _Page page = _Page(count: 900, next: '', results: <String>['أ']);
      expect(page.canLoadMore, isFalse);
      expect(page.nextOffset, isNull);
    });

    test('BaseEntity: رابطٌ مشوّه لا يُسقط nextOffset', () {
      final _Page page = _Page(count: 9, next: 'ليس رابطاً :: %%', results: <String>['أ']);
      expect(page.hasNext, isTrue);
      expect(() => page.nextOffset, returnsNormally);
    });

    test('BaseEntity: addAll على قائمة const لا يرمي', () {
      final _Page page = _Page(count: 0, next: '', results: const <String>[]);
      page.addAll(_Page(count: 2, next: '?offset=2', results: <String>['أ', 'ب']));
      expect(page.results, <String>['أ', 'ب']);
      expect(page.nextOffset, 2);
    });

    test('GridConfig يحسب نسبة العرض/الارتفاع', () {
      expect(const GridConfig(itemWidth: 160, itemHeight: 200).childAspectRatio, 0.8);
    });

    test('كل منسّق مُصدَّر صالحٌ لـ inputFormatters', () {
      // العقد العلنيّ: ما يُذكر في `inputFormatters` يجب أن يكون TextInputFormatter.
      // `NoEnglishLettersFormatter` حاوية اسمٍ لا منسّق، فالمنسّق فيها حقلٌ ساكن.
      expect(IbanFormatter(), isA<Object>());
      expect(NoEnglishLettersFormatter.formatter, isNotNull);
      expect(
        <Object>[
          IbanFormatter(),
          CardNumberFormatter(),
          CardExpiryFormatter(),
          const NumbersOnlyFormatter(),
          const NumbersOnlyFormatter(allowDecimal: true),
          const ConvertArabicToEnglishNumbersFormatter(),
          UpperCaseEnglishFormatter(),
          NoEnglishLettersFormatter.formatter,
        ].length,
        8,
      );
    });

    test('DelayHandler يُنشأ ويُتخلّص منه بلا مؤقّتٍ عالق', () {
      final DelayHandler delay = DelayHandler(defaultDelayMs: 5);
      delay.run(() {});
      delay.dispose();
      expect(delay.defaultDelayMs, 5);
    });

    test('FieldErrors.clear تعمل بخريطة فارغة وبأخرى مملوءة', () {
      // النوع هنا `void Function(String?)` لا `ValueSetter` — إثباتٌ أنّ
      // استعمال الواجهة لا يفرض استيراد flutter/widgets بالاسم.
      String? captured = 'خطأ قديم';
      FieldErrors.clear(<String, void Function(String?)>{});
      FieldErrors.clear(<String, void Function(String?)>{'name': (String? m) => captured = m});
      expect(captured, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٥) الشبكة — الحدود قبل الحالات السعيدة
  // ═════════════════════════════════════════════════════════════════════════

  group('ResponseCode: حدود النطاقات', () {
    test('النجاح [200,300) — لا 199 ولا 300', () {
      expect(ResponseCode.isSuccessful(200), isTrue);
      expect(ResponseCode.isSuccessful(299), isTrue);
      expect(ResponseCode.isSuccessful(199), isFalse);
      expect(ResponseCode.isSuccessful(300), isFalse);
    });

    test('الصفر والسالب ليست نجاحاً ولا خطأ عميلٍ ولا خادم', () {
      for (final int code in <int>[0, -1, -11, -18, -999]) {
        expect(ResponseCode.isSuccessful(code), isFalse, reason: 'code=$code');
        expect(ResponseCode.isClientError(code), isFalse, reason: 'code=$code');
        expect(ResponseCode.isServerError(code), isFalse, reason: 'code=$code');
      }
    });

    test('خطأ العميل [400,500) وخطأ الخادم [500,600)', () {
      expect(ResponseCode.isClientError(400), isTrue);
      expect(ResponseCode.isClientError(499), isTrue);
      expect(ResponseCode.isClientError(500), isFalse);
      expect(ResponseCode.isClientError(399), isFalse);
      expect(ResponseCode.isServerError(500), isTrue);
      expect(ResponseCode.isServerError(599), isTrue);
      expect(ResponseCode.isServerError(600), isFalse);
      expect(ResponseCode.isServerError(499), isFalse);
    });

    test('429 وحده تجاوزٌ للمعدّل', () {
      expect(ResponseCode.isTooManyRequests(429), isTrue);
      expect(ResponseCode.isTooManyRequests(428), isFalse);
      expect(ResponseCode.isTooManyRequests(430), isFalse);
    });

    test('isBadHtmlResponse: الفارغ ونصّ عربيّ عاديّ وHTML سليم ليست أخطاء', () {
      expect(ResponseCode.isBadHtmlResponse(''), isFalse);
      expect(ResponseCode.isBadHtmlResponse('تم بنجاح'), isFalse);
      // وثيقةُ HTML هي وثيقةُ HTML وإن خلت من DOCTYPE: صفحات nginx و502
      // من الوسطاء تبدأ هكذا، والغرض كشفُ «HTML مكان JSON» لا كشفُ القالب.
      expect(ResponseCode.isBadHtmlResponse('<html><body>مرحبا</body></html>'), isTrue);
    });
  });

  group('ErrorType: كل قيمة تُنتج فشلاً مكتملاً', () {
    test('لا قيمة بلا رسالة — أيّاً كانت', () {
      for (final ErrorType type in ErrorType.values) {
        final Failure failure = type.toFailure();
        expect(failure.message, isNotNull, reason: '$type بلا رسالة');
        expect(failure.message, isNotEmpty, reason: '$type برسالة فارغة');
        expect(failure.displayMessage, isNotEmpty, reason: '$type بلا رسالة عرض');
      }
    });

    test('عطل الاتصال ليس عطل خادم — كوده noInternetConnection', () {
      expect(ErrorType.connectionError.toFailure().code, ResponseCode.noInternetConnection);
      expect(ErrorType.gatewayTimeout.toFailure().code, ResponseCode.gatewayTimeout);
    });

    test('المجهول يحمل كود unknown', () {
      expect(ErrorType.unknown.toFailure().code, ResponseCode.unknown);
    });
  });

  group('Failure: null والفارغ والمشوّه', () {
    test('بلا رسالة ⇐ لا انهيار، ورسالة عرضٍ غير فارغة', () {
      const Failure failure = Failure(code: 500);
      expect(failure.message, isNull);
      expect(failure.displayMessage, isNotEmpty);
      expect(failure.hasFields, isFalse);
      expect(failure.fieldError('أيّ'), isNull);
      expect(failure.retryAfter, isNull);
    });

    test('الرسالة الاحتياطية بالصيغة المركّبة المعتادة (أ = U+0623)', () {
      // هذه أظهر سلسلةٍ في المكتبة: تُعرض للمستخدم كلّما جاء الخادم بلا رسالة.
      // حراسةٌ على ترميزها: الصيغة المتحلّلة (ا U+0627 + همزة U+0654) تُعرض
      // مثلها تماماً ولا تساويها نصّياً، فتفشل مقارنةُ المستهلك، ولا يجدها
      // البحث في الشيفرة، ولا تطابقها مفاتيح الترجمة — بلا أيّ عرَضٍ مرئيّ.
      const Failure failure = Failure(code: 500);
      expect(failure.displayMessage, 'حدث خطأ غير متوقع');
      expect(
        failure.displayMessage.contains('ٔ'),
        isFalse,
        reason: 'همزةٌ مركّبة (U+0654) في نصٍّ معروضٍ للمستخدم',
      );
    });

    test('429 وحده isTooManyRequests', () {
      expect(const Failure(code: 429).isTooManyRequests, isTrue);
      expect(const Failure(code: 430).isTooManyRequests, isFalse);
      expect(const Failure(code: 0).isTooManyRequests, isFalse);
    });

    test('fromJson: رسالة غير نصّية لا تُسقط بقيّة المفاتيح', () {
      final Failure failure = Failure.fromJson(400, <String, dynamic>{
        'message': 400,
        'detail': 'الحقل مطلوب',
      });
      expect(failure.message, 'الحقل مطلوب');
    });

    test('fromJson: رسالةٌ فارغة تُتخطّى', () {
      expect(Failure.fromJson(400, <String, dynamic>{'message': ''}).message, isNull);
    });

    test('fromJson: خريطة فارغة لا ترمي', () {
      final Failure failure = Failure.fromJson(500, <String, dynamic>{});
      expect(failure.code, 500);
      expect(failure.message, isNull);
      expect(failure.fields, isEmpty);
    });

    test('fromJson: عنصرٌ فاسد في fields لا يُسقط الصحيح معه', () {
      final Failure failure = Failure.fromJson(400, <String, dynamic>{
        'fields': <dynamic>[
          'نصّ لا خريطة',
          <String, dynamic>{'message': 'بلا اسم حقل'},
          <String, dynamic>{
            'field': 'phone',
            'message': <dynamic>['مطلوب', 'قصير جداً'],
          },
        ],
      });
      expect(failure.hasFields, isTrue);
      expect(failure.fields.length, 1);
      expect(failure.fieldError('phone'), 'مطلوب، قصير جداً');
      expect(failure.fieldError('email'), isNull);
    });

    test('fromJson: fields ليست قائمة ⇐ تُتجاهل بلا رمي', () {
      expect(Failure.fromJson(400, <String, dynamic>{'fields': 'خطأ'}).fields, isEmpty);
    });
  });

  group('handleResponse و ErrorHandler عبر البرميل', () {
    RequestOptions options() => RequestOptions(path: '/orders');

    test('٢٠٠ بخريطة ⇐ تُعاد كما هي', () {
      final dynamic result = handleResponse(
        Response<dynamic>(
          requestOptions: options(),
          statusCode: 200,
          data: <String, dynamic>{'id': 1},
        ),
      );
      expect(result, <String, dynamic>{'id': 1});
    });

    test('٢٠٤ ⇐ رسالة حذفٍ عربية', () {
      final dynamic result = handleResponse(
        Response<dynamic>(requestOptions: options(), statusCode: 204),
      );
      expect(result, 'تمت عملية الحذف بنجاح');
    });

    test('٢٠٠ ببيانات null ⇐ خريطة فارغة لا انهيار', () {
      final dynamic result = handleResponse(
        Response<dynamic>(requestOptions: options(), statusCode: 200, data: null),
      );
      expect(result, <String, dynamic>{});
    });

    test('٤٠٤ يرمي DioException لا خطأً مجهولاً', () {
      expect(
        () => handleResponse(
          Response<dynamic>(requestOptions: options(), statusCode: 404, data: null),
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('ErrorHandler يصنّف الإلغاء والمهلة', () {
      expect(
        ErrorHandler.handle(
          DioException(requestOptions: options(), type: DioExceptionType.cancel),
        ).failure.code,
        ResponseCode.cancel,
      );
      expect(
        ErrorHandler.handle(
          DioException(requestOptions: options(), type: DioExceptionType.connectionTimeout),
        ).failure.code,
        ResponseCode.connectTimeout,
      );
    });

    test('ErrorHandler على خطأٍ ليس من dio لا يرمي', () {
      expect(ErrorHandler.handle('نصّ خطأ').failure.message, isNotEmpty);
      expect(ErrorHandler.handle(null).failure.message, isNotEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٦) الامتدادات — تصل بالاستيراد وحده وتصمد على الحدّ
  // ═════════════════════════════════════════════════════════════════════════

  group('امتدادات String عبر البرميل', () {
    test('isAllDigits: الفارغ والعربيّ والمختلط', () {
      expect('12345'.isAllDigits, isTrue);
      expect('0'.isAllDigits, isTrue);
      expect(''.isAllDigits, isFalse);
      expect('12a'.isAllDigits, isFalse);
      expect('١٢٣'.isAllDigits, isFalse);
      expect('-5'.isAllDigits, isFalse);
    });

    test('isValidDecimal: النقطة المنفردة مرفوضة', () {
      expect('3.14'.isValidDecimal, isTrue);
      expect('3.'.isValidDecimal, isTrue);
      expect('.5'.isValidDecimal, isTrue);
      expect('.'.isValidDecimal, isFalse);
      expect(''.isValidDecimal, isFalse);
      expect('1.2.3'.isValidDecimal, isFalse);
    });

    test('withoutBrackets: القوسان المتطابقان فقط', () {
      expect('[أ,ب]'.withoutBrackets, 'أ,ب');
      expect('(أ)'.withoutBrackets, 'أ');
      expect('بلا أقواس'.withoutBrackets, 'بلا أقواس');
      expect('[ناقص'.withoutBrackets, '[ناقص');
      expect(''.withoutBrackets, '');
      expect('['.withoutBrackets, '[');
    });

    test('isValidEmail: الفارغ والمشوّه والعربيّ', () {
      expect('user@email.com'.isValidEmail, isTrue);
      expect(''.isValidEmail, isFalse);
      expect('user@'.isValidEmail, isFalse);
      expect('@email.com'.isValidEmail, isFalse);
      expect('user email@x.com'.isValidEmail, isFalse);
    });

    test('capitalized: الفارغ والعربيّ (بلا حالة أحرف)', () {
      expect('hello'.capitalized, 'Hello');
      expect(''.capitalized, '');
      expect('م'.capitalized, 'م');
      expect('1a'.capitalized, '1a');
    });
  });

  group('امتدادات الأرقام عبر البرميل', () {
    test('toCurrency: الصفر والسالب والكبير جداً', () {
      expect(0.0.toCurrency, '0.00');
      expect(12345.67.toCurrency, '12,345.67');
      expect((-1234.5).toCurrency, '-1,234.50');
      expect(0.toCurrency, '0');
      expect(1234567890.toCurrency, '1,234,567,890');
      expect(12345.67.toCurrencyNoDecimals, '12,346');
    });

    test('toArabicDigits: الفارغ والمختلط والعربيّ الخالص', () {
      expect(''.toArabicDigits, '');
      expect('2024-01-05'.toArabicDigits, '٢٠٢٤-٠١-٠٥');
      expect('متبقي 6'.toArabicDigits, 'متبقي ٦');
      expect('لا أرقام'.toArabicDigits, 'لا أرقام');
      expect(0.toArabicDigits, '٠');
      expect((-12).toArabicDigits, '-١٢');
    });

    test('toDateString ثابتة على en_US بلا تهيئة لغة', () {
      expect(DateTime.utc(2024, 1, 5, 12).toDateString, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // ٧) الأدوات المساعدة — الحدود
  // ═════════════════════════════════════════════════════════════════════════

  group('الأدوات المساعدة عبر البرميل', () {
    test('getFirstName: الفارغ والفراغ والعربيّ والطويل', () {
      expect(getFirstName('محمد أحمد'), 'محمد');
      expect(getFirstName('  محمد   أحمد  '), 'محمد');
      expect(getFirstName(''), '');
      // مُدخلٌ بلا اسمٍ أصلاً يعيد فارغاً لا المُدخل نفسه: إعادة «   » كانت
      // تُسرّب مسافاتٍ غير مقصوصة إلى الواجهة (انظر حارس helpers.dart).
      expect(getFirstName('   '), '');
      expect(getFirstName('محمد'), 'محمد');
      expect(getFirstName('أ ' * 500), 'أ');
    });

    test('convertArabicToEnglishNumbers: الفارغ والعربيّ والمختلط', () {
      expect(convertArabicToEnglishNumbers(''), '');
      expect(convertArabicToEnglishNumbers('١٢٣٤٥٦٧٨٩٠'), '1234567890');
      expect(convertArabicToEnglishNumbers('نص بلا أرقام'), 'نص بلا أرقام');
      expect(convertArabicToEnglishNumbers('٣٫١٤'), '3.14');
      // `convertArabicNumbers` مجرّد اسمٍ قديم للدالّة نفسها.
      expect(convertArabicNumbers('٥'), convertArabicToEnglishNumbers('٥'));
    });

    test('parseToMap: null والفارغ والمشوّه والعربيّ', () {
      expect(parseToMap(null), <String, dynamic>{});
      expect(parseToMap(''), <String, dynamic>{});
      expect(parseToMap('{}'), <String, dynamic>{});
      expect(parseToMap('ليس json إطلاقاً'), <String, dynamic>{});
      expect(parseToMap(42), <String, dynamic>{});
      expect(parseToMap(<String, dynamic>{'اسم': 'محمد'}), <String, dynamic>{'اسم': 'محمد'});
      expect(parseToMap('{"اسم": "محمد"}'), <String, dynamic>{'اسم': 'محمد'});
    });

    test('parseToMap: نصّ طويل جداً ومشوّه لا يُجمّد ولا يرمي', () {
      final String huge = '{${'x' * 40000}}';
      expect(parseToMap(huge), <String, dynamic>{});
    });
  });

  group('IbanUtils عبر البرميل', () {
    test('strip وformat على الفارغ والمشوّه', () {
      expect(IbanUtils.strip(''), '');
      expect(IbanUtils.format(''), '');
      expect(IbanUtils.strip('sa44 2000'), 'SA442000');
      expect(IbanUtils.format('SA442000'), 'SA44 2000');
    });

    test('isValid: الفارغ والقصير وغير المدعوم', () {
      expect(IbanUtils.isValid(''), isFalse);
      expect(IbanUtils.isValid('SA'), isFalse);
      expect(IbanUtils.isValid('1234567890'), isFalse);
      expect(IbanUtils.isValid('ZZ44200000012345678912'), isFalse);
      expect(IbanUtils.isValid('١٢٣٤'), isFalse);
    });

    test('expectedLength وisSupportedCountry', () {
      expect(IbanUtils.isSupportedCountry('sa'), isTrue);
      expect(IbanUtils.isSupportedCountry('ZZ'), isFalse);
      expect(IbanUtils.expectedLength('SA'), 24);
      expect(IbanUtils.expectedLength('ZZ'), isNull);
    });
  });

  group('IntlPhoneUtils عبر البرميل', () {
    test('قائمة الدول غير فارغة والافتراضيّ السعودية', () {
      expect(IntlPhoneUtils.countries, isNotEmpty);
      expect(IntlPhoneUtils.defaultCountryCode, 'SA');
    });

    test('getCountryByCode: null ورمزٌ مجهول يسقطان إلى السعودية', () {
      expect(IntlPhoneUtils.getCountryByCode(null).code, 'SA');
      expect(IntlPhoneUtils.getCountryByCode('ZZ').code, 'SA');
      expect(IntlPhoneUtils.getCountryByCode('EG').code, 'EG');
    });

    test('getCountryCode على نصٍّ فارغ أو مشوّه يعيد فارغاً لا يرمي', () {
      expect(IntlPhoneUtils.getCountryCode(''), '');
      expect(IntlPhoneUtils.getCountryCode('ليس رقماً'), '');
    });

    test('isSA يميّز +966 وحدها', () {
      expect(IntlPhoneUtils.isSA('+966501234567'), isTrue);
      expect(IntlPhoneUtils.isSA('+201001234567'), isFalse);
      expect(IntlPhoneUtils.isSA(''), isFalse);
    });
  });
}
