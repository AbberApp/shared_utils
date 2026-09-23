// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك فعلاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار [ResponseCode]: مجالات أكواد HTTP، وثوابت الأخطاء المخصّصة،
/// وكشف صفحات HTML التي يبعثها الخادم مكان JSON.
///
/// **السلوك الصحيح لـ[ResponseCode.isBadHtmlResponse]**: أن تجيب «هل جسم
/// الاستجابة **وثيقةُ** HTML؟» — أي هل يبدأ الجسم (بعد تشذيب الفراغ) بـ
/// `<!doctype html` أو `<html`، بلا حساسيةٍ لحالة الأحرف ولا لما بين الوسوم
/// من مسافاتٍ وأسطر. لا أن تطابق قالباً حرفياً واحداً في أيّ موضع من النصّ.

/// قالب صفحة الخطأ مرصوصاً بلا مسافةٍ ولا سطرٍ جديد بين وسومه — أضيقُ شكلٍ
/// تصل به الصفحة، ومنه كان يُشتقّ الفحص القديم بالمطابقة الحرفية.
const String _exactMarker =
    '<!DOCTYPE html><html lang="en" dir="rtl"><head><title>خطأ';

/// صفحة الخطأ العربية كما يُصدّرها الخادم فعلاً: أسطرٌ ومسافاتٌ بادئة.
const String _arabicHtmlPage = '''
<!DOCTYPE html>
<html lang="en" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <title>خطأ في الخادم</title>
  </head>
  <body>
    <h1>حدث خطأ غير متوقّع</h1>
  </body>
</html>
''';

/// صفحة خطأ Django النموذجية (DEBUG=False) — عنوانها إنجليزيّ.
const String _djangoErrorPage = '''
<!doctype html>
<html lang="en">
<head>
  <title>Server Error (500)</title>
</head>
<body>
  <h1>Server Error (500)</h1><p></p>
</body>
</html>
''';

/// صفحة nginx 502 — لا DOCTYPE فيها أصلاً، تبدأ بـ`<html>` مباشرة.
const String _nginxErrorPage = '''
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.24.0</center>
</body>
</html>
''';

/// جسم JSON سليم بقيمٍ عربية — ما يجب أن يمرّ بلا اتّهام.
const String _arabicJson =
    '{"count": 3, "results": [{"id": 1, "name": "خطأ في الاسم فقط"}]}';

/// كلّ ثوابت الأكواد باسمها — للفحص الشامل بلا نسيان واحدٍ منها.
const Map<String, int> _allCodes = <String, int>{
  'success': ResponseCode.success,
  'created': ResponseCode.created,
  'noContent': ResponseCode.noContent,
  'badRequest': ResponseCode.badRequest,
  'unauthorized': ResponseCode.unauthorized,
  'forbidden': ResponseCode.forbidden,
  'notFound': ResponseCode.notFound,
  'conflict': ResponseCode.conflict,
  'tooManyRequests': ResponseCode.tooManyRequests,
  'internalServerError': ResponseCode.internalServerError,
  'notImplemented': ResponseCode.notImplemented,
  'badGateway': ResponseCode.badGateway,
  'serviceUnavailable': ResponseCode.serviceUnavailable,
  'gatewayTimeout': ResponseCode.gatewayTimeout,
  'unknown': ResponseCode.unknown,
  'connectTimeout': ResponseCode.connectTimeout,
  'cancel': ResponseCode.cancel,
  'receiveTimeout': ResponseCode.receiveTimeout,
  'sendTimeout': ResponseCode.sendTimeout,
  'cacheError': ResponseCode.cacheError,
  'noInternetConnection': ResponseCode.noInternetConnection,
  'wrongPassword': ResponseCode.wrongPassword,
  'socketException': ResponseCode.socketException,
  'sellerAccountNotFound': ResponseCode.sellerAccountNotFound,
};

/// الأكواد المخصّصة وحدها (ما ليس كود HTTP قياسيّاً).
const Map<String, int> _customCodes = <String, int>{
  'unknown': ResponseCode.unknown,
  'connectTimeout': ResponseCode.connectTimeout,
  'cancel': ResponseCode.cancel,
  'receiveTimeout': ResponseCode.receiveTimeout,
  'sendTimeout': ResponseCode.sendTimeout,
  'cacheError': ResponseCode.cacheError,
  'noInternetConnection': ResponseCode.noInternetConnection,
  'wrongPassword': ResponseCode.wrongPassword,
  'socketException': ResponseCode.socketException,
  'sellerAccountNotFound': ResponseCode.sellerAccountNotFound,
};

void main() {
  group('مجالات الأكواد — isSuccessful', () {
    test('يقبل طرفَي 2xx وما بينهما', () {
      for (final int code in <int>[200, 201, 202, 204, 250, 299]) {
        expect(ResponseCode.isSuccessful(code), isTrue, reason: 'رفض $code');
      }
    });

    test('يرفض ما دون 200 وما من 300 فصاعداً', () {
      for (final int code in <int>[100, 199, 300, 301, 304, 400, 500]) {
        expect(ResponseCode.isSuccessful(code), isFalse, reason: 'قبل $code');
      }
    });

    test('يرفض الصفر والسالب وأكواد المكتبة المخصّصة', () {
      expect(ResponseCode.isSuccessful(0), isFalse);
      expect(ResponseCode.isSuccessful(-1), isFalse);
      expect(ResponseCode.isSuccessful(ResponseCode.connectTimeout), isFalse);
      expect(ResponseCode.isSuccessful(ResponseCode.socketException), isFalse);
      expect(
        ResponseCode.isSuccessful(ResponseCode.noInternetConnection),
        isFalse,
      );
    });

    test('يرفض القيم الضخمة في الطرفين (مُدخل مشوّه)', () {
      expect(ResponseCode.isSuccessful(999999), isFalse);
      expect(ResponseCode.isSuccessful(-999999), isFalse);
    });
  });

  group(
    'مجالات الأكواد — isClientError و isServerError و isTooManyRequests',
    () {
      test('isClientError يقبل 400..499 وحدها', () {
        for (final int code in <int>[400, 401, 403, 404, 409, 429, 451, 499]) {
          expect(ResponseCode.isClientError(code), isTrue, reason: 'رفض $code');
        }
        for (final int code in <int>[399, 500, 503, 0, -12, 200]) {
          expect(
            ResponseCode.isClientError(code),
            isFalse,
            reason: 'قبل $code',
          );
        }
      });

      test('isServerError يقبل 500..599 وحدها', () {
        for (final int code in <int>[500, 501, 502, 503, 504, 522, 599]) {
          expect(ResponseCode.isServerError(code), isTrue, reason: 'رفض $code');
        }
        for (final int code in <int>[499, 600, 601, 0, -15, 204]) {
          expect(
            ResponseCode.isServerError(code),
            isFalse,
            reason: 'قبل $code',
          );
        }
      });

      test('isTooManyRequests لـ429 وحده', () {
        expect(ResponseCode.isTooManyRequests(429), isTrue);
        expect(
          ResponseCode.isTooManyRequests(ResponseCode.tooManyRequests),
          isTrue,
        );
        expect(ResponseCode.isTooManyRequests(428), isFalse);
        expect(ResponseCode.isTooManyRequests(430), isFalse);
        expect(ResponseCode.isTooManyRequests(0), isFalse);
        expect(ResponseCode.isTooManyRequests(-429), isFalse);
      });

      test(
        'الصفر — قيمة `statusCode ?? 0` الاحتياطية — لا يقع في أيّ مجال',
        () {
          // ErrorHandler يمرّر `statusCode ?? 0` حين يكون الكود null؛ فالصفر
          // يجب ألّا يُصنَّف نجاحاً ولا خطأ عميلٍ ولا خطأ خادم.
          expect(ResponseCode.isSuccessful(0), isFalse);
          expect(ResponseCode.isClientError(0), isFalse);
          expect(ResponseCode.isServerError(0), isFalse);
        },
      );

      test('المجالات الثلاثة متنافية: لا كود يقع في اثنين منها (0..699)', () {
        for (int code = -100; code <= 699; code++) {
          final int hits = <bool>[
            ResponseCode.isSuccessful(code),
            ResponseCode.isClientError(code),
            ResponseCode.isServerError(code),
          ].where((bool b) => b).length;
          expect(hits, lessThanOrEqualTo(1), reason: 'الكود $code في مجالين');
        }
      });

      test('1xx و3xx لا تقع في أيّ مجالٍ من الثلاثة', () {
        for (final int code in <int>[100, 101, 199, 300, 301, 302, 304, 399]) {
          expect(ResponseCode.isSuccessful(code), isFalse, reason: '$code');
          expect(ResponseCode.isClientError(code), isFalse, reason: '$code');
          expect(ResponseCode.isServerError(code), isFalse, reason: '$code');
        }
      });
    },
  );

  group('ثوابت الأكواد', () {
    test('أكواد HTTP القياسية تطابق معاييرها', () {
      expect(ResponseCode.success, 200);
      expect(ResponseCode.created, 201);
      expect(ResponseCode.noContent, 204);
      expect(ResponseCode.badRequest, 400);
      expect(ResponseCode.unauthorized, 401);
      expect(ResponseCode.forbidden, 403);
      expect(ResponseCode.notFound, 404);
      expect(ResponseCode.conflict, 409);
      expect(ResponseCode.tooManyRequests, 429);
      expect(ResponseCode.internalServerError, 500);
      expect(ResponseCode.notImplemented, 501);
      expect(ResponseCode.badGateway, 502);
      expect(ResponseCode.serviceUnavailable, 503);
      expect(ResponseCode.gatewayTimeout, 504);
    });

    test('لا قيمة مكرّرة بين الثوابت كلّها', () {
      final List<int> values = _allCodes.values.toList();
      expect(
        values.toSet().length,
        values.length,
        reason: 'ثابتان يحملان القيمة نفسها فيتعذّر تمييز الخطأين',
      );
    });

    test('كلّ كود HTTP قياسيّ يصنّفه مصنّفه هو', () {
      expect(ResponseCode.isSuccessful(ResponseCode.success), isTrue);
      expect(ResponseCode.isSuccessful(ResponseCode.created), isTrue);
      expect(ResponseCode.isSuccessful(ResponseCode.noContent), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.badRequest), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.unauthorized), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.forbidden), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.notFound), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.conflict), isTrue);
      expect(ResponseCode.isClientError(ResponseCode.tooManyRequests), isTrue);
      expect(
        ResponseCode.isServerError(ResponseCode.internalServerError),
        isTrue,
      );
      expect(ResponseCode.isServerError(ResponseCode.notImplemented), isTrue);
      expect(ResponseCode.isServerError(ResponseCode.badGateway), isTrue);
      expect(
        ResponseCode.isServerError(ResponseCode.serviceUnavailable),
        isTrue,
      );
      expect(ResponseCode.isServerError(ResponseCode.gatewayTimeout), isTrue);
    });

    test('tooManyRequests يتّسق مع Failure.isTooManyRequests', () {
      const Failure failure = Failure(code: ResponseCode.tooManyRequests);
      expect(failure.isTooManyRequests, isTrue);
    });

    test(
      'الأكواد المخصّصة خارج مجال أكواد HTTP (100..599) فلا تلتبس بها',
      () {
        for (final MapEntry<String, int> e in _customCodes.entries) {
          expect(
            e.value < 100,
            isTrue,
            reason:
                'الكود المخصّص ${e.key} = ${e.value} يصطدم بكود HTTP حقيقي، '
                'فلا يستطيع المستهلك تمييز مصدر الفشل من رقمه',
          );
        }
      },
    );
  });

  group('isBadHtmlResponse — أجسامٌ سليمة لا يجوز اتّهامها', () {
    test('JSON إنجليزيّ عاديّ', () {
      expect(
        ResponseCode.isBadHtmlResponse('{"id": 7, "name": "Ahmed"}'),
        isFalse,
      );
    });

    test('JSON بقيمٍ عربية (وفيه كلمة «خطأ»)', () {
      expect(ResponseCode.isBadHtmlResponse(_arabicJson), isFalse);
    });

    test('نصّ فارغ', () {
      expect(ResponseCode.isBadHtmlResponse(''), isFalse);
    });

    test('فراغٌ محض: مسافات وأسطر جديدة وحدها', () {
      expect(ResponseCode.isBadHtmlResponse('   \n\t  \r\n '), isFalse);
    });

    test("النصّ 'null' — ناتج data.toString() لجسمٍ معدوم", () {
      // المعالج ينادي `data.toString()` فيصير null نصّاً حرفيّاً.
      expect(ResponseCode.isBadHtmlResponse('null'), isFalse);
    });

    test('نصّ عاديّ بلا وسوم', () {
      expect(ResponseCode.isBadHtmlResponse('Internal Server Error'), isFalse);
      expect(ResponseCode.isBadHtmlResponse('حدث خطأ في الخادم'), isFalse);
    });

    test('جسم JSON يذكر «<html» في منتصفه ليس صفحةَ HTML', () {
      // الجسم JSON صالح، ووسم HTML مجرّد نصٍّ داخل رسالة. اتّهامه
      // يُضيّع رسالة الخادم الحقيقية على المستخدم.
      const String body =
          '{"detail": "ممنوع إرسال <html> أو <script> في التعليق"}';
      expect(ResponseCode.isBadHtmlResponse(body), isFalse);
    });

    test('«<html» في منتصف نصٍّ عربيّ طويل ليس صفحةَ HTML', () {
      final String body =
          '${'شرحٌ مطوّل جدّاً لسبب الرفض. ' * 200}الوسم <html> غير مسموح.';
      expect(body.length, greaterThan(1000));
      expect(ResponseCode.isBadHtmlResponse(body), isFalse);
    });

    test('جسم XML ليس صفحةَ HTML', () {
      const String body =
          '<?xml version="1.0" encoding="UTF-8"?><error><code>500</code></error>';
      expect(ResponseCode.isBadHtmlResponse(body), isFalse);
    });

    test('نصّ عربيّ طويل جدّاً بلا أيّ وسم', () {
      final String body = 'لا يوجد اتصال بالإنترنت. ' * 5000;
      expect(body.length, greaterThan(100000));
      expect(ResponseCode.isBadHtmlResponse(body), isFalse);
    });

    test('القالب الحرفيّ التامّ يُكتشف (السلوك القائم الصحيح)', () {
      expect(ResponseCode.isBadHtmlResponse(_exactMarker), isTrue);
      expect(
        ResponseCode.isBadHtmlResponse(
          '$_exactMarker في الخادم</title></head><body></body></html>',
        ),
        isTrue,
      );
    });

    test('فراغٌ بادئ قبل DOCTYPE لا يُفلت الصفحة', () {
      // خوادم كثيرة تسبق الوثيقة بسطرٍ فارغ. الفحص القائم ينجو هنا مصادفةً
      // لأنّ `contains` لا تحفل بالموضع؛ وعلى أيّ إصلاحٍ لاحق (تشذيبٌ ثمّ
      // فحص البداية) أن يبقى ناجحاً.
      final String page = '\n  $_exactMarker</title></head></html>';
      expect(ResponseCode.isBadHtmlResponse(page), isTrue);
    });
  });

  group('isBadHtmlResponse — صفحات HTML حقيقية', () {
    test('صفحة عربية حقيقية بمسافاتٍ وأسطر جديدة تُكتشف', () {
      expect(ResponseCode.isBadHtmlResponse(_arabicHtmlPage), isTrue);
    });

    test('مسافةٌ واحدة بعد <!DOCTYPE html> لا تُفلت الصفحة', () {
      const String page =
          '<!DOCTYPE html> <html lang="en" dir="rtl"><head><title>خطأ في الخادم</title></head></html>';
      expect(ResponseCode.isBadHtmlResponse(page), isTrue);
    });

    test('صفحة خطأ Django النموذجية (500) تُكتشف', () {
      // عنوانها إنجليزيّ ولا سمة dir فيها: الفحص على الوثيقة لا على قالبنا.
      expect(ResponseCode.isBadHtmlResponse(_djangoErrorPage), isTrue);
    });

    test('صفحة nginx 502 (تبدأ بـ<html> بلا DOCTYPE) تُكتشف', () {
      expect(ResponseCode.isBadHtmlResponse(_nginxErrorPage), isTrue);
    });

    test('DOCTYPE بحروفٍ صغيرة يُكتشف (HTML لا يحفل بحالة الأحرف)', () {
      const String page =
          '<!doctype html><html lang="en" dir="rtl"><head><title>خطأ</title></head></html>';
      expect(ResponseCode.isBadHtmlResponse(page), isTrue);
    });

    test('صفحة HTML ضخمة (أكثر من 100 ألف حرف) تُكتشف', () {
      final String page =
          '<!DOCTYPE html>\n<html lang="en">\n<body>\n'
          '${'<p>تفاصيل التتبّع الطويلة جدّاً للخطأ.</p>\n' * 3000}'
          '</body>\n</html>';
      expect(page.length, greaterThan(100000));
      expect(ResponseCode.isBadHtmlResponse(page), isTrue);
    });

    test('قالبُ الخطأ مقتبساً داخل JSON ليس صفحةَ خطأ', () {
      // الفحص على بداية الجسم بعد التشذيب لا على أيّ موضعٍ منه: جسمٌ يبدأ
      // بـ`{` بياناتٌ سليمة وإن اقتبس الصفحة في إحدى قيمه.
      final String body = '{"template": "$_exactMarker"}';
      expect(ResponseCode.isBadHtmlResponse(body), isFalse);
    });
  });
}
