// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك، وهو يُثبت أنّ
// `DioException` و`Response` و`Headers` مُعادة التصدير — لولاها لما استطاع
// مستدعٍ أن يبني خطأً ليُمرّره إلى `ErrorHandler.handle` أصلاً.
import 'dart:io' show HttpDate, SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار شامل لـ [ErrorHandler] — مترجم كلّ خطأ شبكي إلى [Failure].
///
/// كلّ الأخطاء تُبنى يدويّاً (لا محاكاة): `ErrorHandler.handle` دالّةٌ نقيّة
/// لا تلمس شبكةً ولا زمناً، فمدخلها كائنٌ ومخرجها كائن.

// ═════════════════════════════════════════════════════════════════════════
// أدوات البناء
// ═════════════════════════════════════════════════════════════════════════

final RequestOptions _options = RequestOptions(path: '/v1/orders');

/// خطأ Dio بلا استجابة أصلاً (انقطاعٌ قبل أن يردّ الخادم).
DioException _bare(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

/// خطأ Dio باستجابة: كودٌ وجسمٌ وترويسات.
DioException _withResponse({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
  Object? data,
  Map<String, List<String>>? headers,
  Object? error,
}) => DioException(
  requestOptions: _options,
  type: type,
  error: error,
  response: Response<dynamic>(
    requestOptions: _options,
    statusCode: statusCode,
    data: data,
    headers: headers == null ? null : Headers.fromMap(headers),
  ),
);

/// استجابة 429 بترويسة Retry-After (أو بلا ترويسة إن كانت `values` فارغة).
DioException _throttled({List<String>? values, String name = 'retry-after'}) =>
    _withResponse(
      statusCode: 429,
      headers: values == null
          ? null
          : <String, List<String>>{name: values},
    );

Failure _handle(Object? error) => ErrorHandler.handle(error).failure;

/// الرسالة الاحتياطية التي يعرضها [Failure.displayMessage] حين لا رسالة —
/// تُقرأ من النموذج نفسه كيلا يقارن الاختبار نصّاً منسوخاً بيده.
final String _fallbackMessage = const Failure(code: 0).displayMessage;

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // 1. أنواع DioException — التسعة كلّها
  // ═══════════════════════════════════════════════════════════════════════
  group('أنواع DioException (بلا استجابة)', () {
    test('connectionTimeout → مهلة اتصال', () {
      final Failure failure = _handle(
        _bare(DioExceptionType.connectionTimeout),
      );
      expect(failure.code, ResponseCode.connectTimeout);
      expect(failure.message, ResponseMessage.connectTimeout);
    });

    test('sendTimeout → مهلة إرسال', () {
      final Failure failure = _handle(_bare(DioExceptionType.sendTimeout));
      expect(failure.code, ResponseCode.sendTimeout);
      expect(failure.message, ResponseMessage.sendTimeout);
    });

    test('receiveTimeout → مهلة استلام', () {
      final Failure failure = _handle(_bare(DioExceptionType.receiveTimeout));
      expect(failure.code, ResponseCode.receiveTimeout);
      expect(failure.message, ResponseMessage.receiveTimeout);
    });

    test('cancel → إلغاء العملية', () {
      final Failure failure = _handle(_bare(DioExceptionType.cancel));
      expect(failure.code, ResponseCode.cancel);
      expect(failure.message, ResponseMessage.cancelled);
    });

    // تراجع (regression): كان `connectionError` يُصنّف 504 فيراه المستدعي عطلَ
    // خادمٍ لا عطلَ شبكة، فتفوته شاشة «لا يوجد اتصال» وسياسةُ إعادة المحاولة.
    test('connectionError → كود «لا اتصال» لا كود عطل خادم', () {
      final Failure failure = _handle(_bare(DioExceptionType.connectionError));
      expect(failure.code, ResponseCode.noInternetConnection);
      expect(failure.message, ResponseMessage.connectionError);
      expect(ResponseCode.isServerError(failure.code), isFalse);
    });

    test('connectionError الملفوف حول SocketException يبقى خطأ شبكة', () {
      // الخطأ `DioException` أوّلاً وإن كان سببه `SocketException`.
      final Failure failure = _handle(
        _bare(
          DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup'),
        ),
      );
      expect(failure.code, ResponseCode.noInternetConnection);
      expect(failure.message, ResponseMessage.connectionError);
    });

    test('unknown → خطأ غير متوقع', () {
      final Failure failure = _handle(_bare(DioExceptionType.unknown));
      expect(failure.code, ResponseCode.unknown);
      expect(failure.message, ResponseMessage.unknown);
    });

    test('badResponse بلا استجابة أصلاً → طلب غير صالح', () {
      final Failure failure = _handle(_bare(DioExceptionType.badResponse));
      expect(failure.code, ResponseCode.badRequest);
      expect(failure.message, ResponseMessage.badRequest);
    });

    test('badCertificate → كود 403', () {
      final Failure failure = _handle(_bare(DioExceptionType.badCertificate));
      expect(failure.code, ResponseCode.forbidden);
    });

    test(
      'badCertificate لا يتّهم حساب المستخدم بعدم التفعيل',
      () {
        // شهادةُ TLS فاسدة عطلُ اتصالٍ لا حالةُ حساب. `ErrorType.forbidden`
        // رسالتها «الحساب غير مُفعّل» وهي تُعرض للمستخدم كما هي في `showToast`.
        final Failure failure = _handle(_bare(DioExceptionType.badCertificate));
        expect(failure.displayMessage, isNot(contains('الحساب غير مُفعّل')));
      },
    );

    test(
      'transformTimeout → مهلة لا «خطأ غير متوقع»',
      () {
        // نوعٌ أضافته dio 5.x: انتهت مهلة تحويل الجسم بعد وصوله. أقربُ ترجمةٍ
        // صحيحة مهلةُ استلام؛ أمّا `default` فيبتلعه ويُظهر «خطأ غير متوقع».
        final Failure failure = _handle(
          _bare(DioExceptionType.transformTimeout),
        );
        expect(failure.code, ResponseCode.receiveTimeout);
      },
    );

    test('كلّ أنواع DioException تُنتج رسالةً غير فارغة', () {
      for (final DioExceptionType type in DioExceptionType.values) {
        final Failure failure = _handle(_bare(type));
        expect(
          failure.displayMessage.trim(),
          isNotEmpty,
          reason: 'النوع $type بلا رسالة',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. أكواد الحالة عبر badResponse (بلا جسمٍ مفيد)
  // ═══════════════════════════════════════════════════════════════════════
  group('أكواد الحالة (badResponse بلا جسم)', () {
    test('404 → لم نعثر على العنصر', () {
      final Failure failure = _handle(_withResponse(statusCode: 404));
      expect(failure.code, ResponseCode.notFound);
      expect(failure.message, ResponseMessage.notFound);
    });

    test('401 → غير مصرّح', () {
      final Failure failure = _handle(_withResponse(statusCode: 401));
      expect(failure.code, ResponseCode.unauthorized);
      expect(failure.message, ResponseMessage.unauthorized);
    });

    test('500 → خطأ داخلي في الخادم', () {
      final Failure failure = _handle(_withResponse(statusCode: 500));
      expect(failure.code, ResponseCode.internalServerError);
      expect(failure.message, ResponseMessage.internalServerError);
    });

    test('كلّ أخطاء الخادم (502, 503, 504, 599) تُوحَّد في 500', () {
      for (final int code in <int>[501, 502, 503, 504, 599]) {
        final Failure failure = _handle(_withResponse(statusCode: code));
        expect(failure.code, ResponseCode.internalServerError, reason: '$code');
        expect(failure.message, ResponseMessage.internalServerError);
      }
    });

    test('كودٌ خارج 4xx و5xx (200، 302، 0، سالب) → طلب غير صالح', () {
      for (final int code in <int>[200, 204, 302, 0, -7]) {
        final Failure failure = _handle(_withResponse(statusCode: code));
        expect(failure.code, ResponseCode.badRequest, reason: '$code');
      }
    });

    test('statusCode غائب (null) مع جسمٍ غير صالح → طلب غير صالح', () {
      final Failure failure = _handle(_withResponse(data: 'نصّ غير JSON'));
      expect(failure.code, ResponseCode.badRequest);
    });

    for (final int code in <int>[400, 403, 409, 422]) {
      test(
        '$code بلا جسم يحتفظ برسالته المخصّصة لا برسالة «غير متوقع»',
        () {
          final Failure failure = _handle(_withResponse(statusCode: code));
          expect(failure.code, code);
          expect(
            failure.message,
            isNotNull,
            reason: 'رسالة الحالة $code ضاعت كلّياً',
          );
          expect(failure.displayMessage, isNot(_fallbackMessage));
        },
      );
    }

    test('403 بلا جسم: الكود يصل سليماً وإن ضاعت الرسالة', () {
      // الكود يصل سليماً، والرسالة صارت رسالة 403 المعلّبة لا العامّة (انظر
      // الاختبار المُعمَّم أعلاه).
      final Failure failure = _handle(_withResponse(statusCode: 403));
      expect(failure.code, ResponseCode.forbidden);
      expect(failure.hasFields, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. جسم Map — رسالة الخادم تسبق الرسالة العامّة
  // ═══════════════════════════════════════════════════════════════════════
  group('جسم الاستجابة Map', () {
    test('400 برسالة عربية من الخادم يعرضها كما هي', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{'message': 'البريد الإلكتروني مستخدم مسبقاً'},
        ),
      );
      expect(failure.code, 400);
      expect(failure.message, 'البريد الإلكتروني مستخدم مسبقاً');
    });

    test('ترتيب المفاتيح: message ثمّ error ثمّ details ثمّ detail ثمّ errors', () {
      expect(
        _handle(
          _withResponse(
            statusCode: 400,
            data: <String, dynamic>{'error': 'ثانٍ', 'message': 'أوّل'},
          ),
        ).message,
        'أوّل',
      );
      expect(
        _handle(
          _withResponse(
            statusCode: 400,
            data: <String, dynamic>{'detail': 'رابع', 'details': 'ثالث'},
          ),
        ).message,
        'ثالث',
      );
      expect(
        _handle(
          _withResponse(
            statusCode: 400,
            data: <String, dynamic>{'errors': 'خامس'},
          ),
        ).message,
        'خامس',
      );
    });

    test('مفتاحٌ غير نصّيّ لا يُسقط بقيّة المفاتيح', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{'message': 400, 'detail': 'الرسالة الحقيقية'},
        ),
      );
      expect(failure.message, 'الرسالة الحقيقية');
    });

    test('رسالةٌ فارغة تُتخطّى إلى المفتاح التالي', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{'message': '', 'error': 'غير فارغ'},
        ),
      );
      expect(failure.message, 'غير فارغ');
    });

    test('أخطاء الحقول تصل مع الرسالة', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{
            'message': 'تحقّق من البيانات',
            'fields': <dynamic>[
              <String, dynamic>{'field': 'phone', 'message': 'رقم غير صالح'},
              <String, dynamic>{'field': 'email', 'message': 'مطلوب'},
            ],
          },
        ),
      );
      expect(failure.hasFields, isTrue);
      expect(failure.fields.length, 2);
      expect(failure.fieldError('phone'), 'رقم غير صالح');
      expect(failure.fieldError('email'), 'مطلوب');
      expect(failure.fieldError('لا-وجود-له'), isNull);
    });

    test('عنصرٌ فاسد في fields يُتخطّى وحده ولا يُسقط الصحيح', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{
            'fields': <dynamic>[
              'نصّ لا خريطة',
              <String, dynamic>{'message': 'بلا اسم حقل'},
              <String, dynamic>{
                'field': 'iban',
                'message': <dynamic>['مطلوب', 'قصير'],
              },
            ],
          },
        ),
      );
      expect(failure.fields.length, 1);
      expect(failure.fieldError('iban'), 'مطلوب، قصير');
    });

    test('رسالة الخادم تسبق رسالة 404 العامّة', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 404,
          data: <String, dynamic>{'detail': 'الطلب غير موجود أو حُذف'},
        ),
      );
      expect(failure.code, 404);
      expect(failure.message, 'الطلب غير موجود أو حُذف');
    });

    test('رسالة الخادم تسبق رسالة 500 العامّة', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 500,
          data: <String, dynamic>{'message': 'تعذّر حفظ الطلب'},
        ),
      );
      expect(failure.code, 500);
      expect(failure.message, 'تعذّر حفظ الطلب');
    });

    test('جسمٌ Map فارغ لا يُصادر الرسالة العامّة (404 يبقى 404)', () {
      final Failure failure = _handle(
        _withResponse(statusCode: 404, data: <String, dynamic>{}),
      );
      expect(failure.message, ResponseMessage.notFound);
    });

    test('Map بلا أيّ مفتاح رسالةٍ معروف → لا رسالة', () {
      // جسمٌ غيرُ متوقَّع الشكل: الرسالة null والمستدعي يرى «حدث خطأ غير متوقع».
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{'code': 'E_LIMIT', 'ok': false},
        ),
      );
      expect(failure.message, isNull);
      expect(failure.displayMessage, _fallbackMessage);
    });

    test('Map<dynamic, dynamic> ليس Map<String, dynamic> فلا تُقرأ رسالته', () {
      final Map<dynamic, dynamic> loose = <dynamic, dynamic>{
        'message': 'رسالة ضائعة',
      };
      final Failure failure = _handle(
        _withResponse(statusCode: 400, data: loose),
      );
      expect(failure.code, 400);
      expect(failure.message, isNull);
    });

    test('استجابةٌ بجسمٍ وبلا statusCode → الكود صفر', () {
      // صفرٌ هو نفسه `ResponseCode.noInternetConnection` — حالةٌ نادرة يوثّقها
      // الاختبار كيلا تتغيّر صامتةً.
      final Failure failure = _handle(
        _withResponse(data: <String, dynamic>{'message': 'بلا كود'}),
      );
      expect(failure.code, 0);
      expect(failure.message, 'بلا كود');
    });

    test('رسالةٌ طويلة جداً تصل كاملةً بلا بتر', () {
      final String long = 'ن' * 10000;
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data: <String, dynamic>{'message': long},
        ),
      );
      expect(failure.message?.length, 10000);
      expect(failure.message, long);
    });

    test('رسالةٌ عربية بمحارف خاصّة وإيموجي تصل كما هي', () {
      const String text = 'فشل «الدفع» — تأكّد من ١٢٣ ثمّ أعد المحاولة 🙏';
      final Failure failure = _handle(
        _withResponse(
          statusCode: 402,
          data: <String, dynamic>{'message': text},
        ),
      );
      expect(failure.message, text);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. 429 — تجاوز حدّ المعدّل وترويسة Retry-After
  // ═══════════════════════════════════════════════════════════════════════
  group('429 — Retry-After', () {
    test('ترويسة مفردة رقمية: الثواني في الرسالة وفي retryAfter', () {
      final Failure failure = _handle(_throttled(values: <String>['120']));
      expect(failure.code, ResponseCode.tooManyRequests);
      expect(failure.isTooManyRequests, isTrue);
      expect(failure.retryAfter, 120);
      expect(failure.message, ResponseMessage.tooManyRequestsAfter(120));
      expect(failure.message, contains('120'));
    });

    test('بلا ترويسة: رسالة عامّة و retryAfter فارغ', () {
      final Failure failure = _handle(_throttled());
      expect(failure.code, ResponseCode.tooManyRequests);
      expect(failure.retryAfter, isNull);
      expect(failure.message, ResponseMessage.tooManyRequests);
    });

    test('ترويسة مكرّرة: تُقرأ الأولى ولا يُرمى استثناء', () {
      // `headers.value()` يرمي عند التكرار — ولهذا تُقرأ القائمة مباشرةً.
      final DioException error = _throttled(values: <String>['30', '60']);
      expect(
        () => error.response!.headers.value('retry-after'),
        throwsA(isA<Exception>()),
      );
      final Failure failure = _handle(error);
      expect(failure.retryAfter, 30);
      expect(failure.message, ResponseMessage.tooManyRequestsAfter(30));
    });

    test('قائمة قيمٍ فارغة كأنّها غائبة', () {
      final Failure failure = _handle(_throttled(values: <String>[]));
      expect(failure.retryAfter, isNull);
      expect(failure.message, ResponseMessage.tooManyRequests);
    });

    test('اسم الترويسة غير حسّاس لحالة الأحرف', () {
      final Failure failure = _handle(
        _throttled(values: <String>['45'], name: 'Retry-After'),
      );
      expect(failure.retryAfter, 45);
    });

    test('مسافاتٌ حول القيمة تُقصّ', () {
      final Failure failure = _handle(_throttled(values: <String>['  90  ']));
      expect(failure.retryAfter, 90);
    });

    test('تاريخ HTTP مستقبليّ → ثوانٍ محسوبة لا قيمة ضائعة', () {
      // RFC 7231 يجيز الصيغتين: ثوانٍ أو تاريخ HTTP — وnginx وCloudflare
      // يُرسلان الثانية. التاريخ يُبنى من الآن كيلا يشيخ الاختبار.
      final String header = HttpDate.format(
        DateTime.now().toUtc().add(const Duration(seconds: 120)),
      );
      final Failure failure = _handle(_throttled(values: <String>[header]));
      expect(failure.retryAfter, isNotNull);
      // هامشٌ للثانية المبتورة في صياغة الترويسة ولزمن التنفيذ.
      expect(failure.retryAfter, inInclusiveRange(110, 120));
      expect(
        failure.message,
        ResponseMessage.tooManyRequestsAfter(failure.retryAfter!),
      );
    });

    test('تاريخ HTTP مضى → صفر (أعد المحاولة الآن) لا قيمة سالبة', () {
      final Failure failure = _handle(
        _throttled(values: <String>['Wed, 21 Oct 2015 07:28:00 GMT']),
      );
      expect(failure.retryAfter, 0);
      expect(failure.message, ResponseMessage.tooManyRequestsAfter(0));
    });

    test('قيمٌ مشوّهة أخرى: فارغة، كسر عشري، أرقام عربية، رقمٌ أضخم من 64bit', () {
      for (final String raw in <String>[
        '',
        '   ',
        '12.5',
        '١٢٠',
        '999999999999999999999',
        'soon',
        '30, 60',
      ]) {
        final Failure failure = _handle(_throttled(values: <String>[raw]));
        expect(failure.retryAfter, isNull, reason: 'القيمة «$raw»');
        expect(failure.message, ResponseMessage.tooManyRequests);
      }
    });

    test('صفر ثانية يمرّ كما هو', () {
      final Failure failure = _handle(_throttled(values: <String>['0']));
      expect(failure.retryAfter, 0);
    });

    test(
      'قيمة سالبة تُرفض كما تُرفض القيمة غير الرقمية',
      () {
        // «يُرجى المحاولة بعد -5 ثانية» نصٌّ يصل المستخدم عبر `showToast`،
        // و`retryAfter` السالب يجعل أيّ عدّادٍ تنازليّ عند المستدعي مقلوباً.
        final Failure failure = _handle(_throttled(values: <String>['-5']));
        expect(failure.retryAfter, isNull);
        expect(failure.message, ResponseMessage.tooManyRequests);
      },
    );

    test('الرسالة العربية تسبق رسالة الخادم عند 429 (سلوك مقصود)', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 429,
          data: <String, dynamic>{'detail': 'Request was throttled.'},
          headers: <String, List<String>>{
            'retry-after': <String>['60'],
          },
        ),
      );
      expect(failure.message, ResponseMessage.tooManyRequestsAfter(60));
      expect(failure.retryAfter, 60);
    });

    test('429 يُعالَج أيّاً كان نوع DioException', () {
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.badResponse,
        DioExceptionType.unknown,
        DioExceptionType.receiveTimeout,
      ]) {
        final Failure failure = _handle(
          _withResponse(
            type: type,
            statusCode: 429,
            headers: <String, List<String>>{
              'retry-after': <String>['15'],
            },
          ),
        );
        expect(failure.code, ResponseCode.tooManyRequests, reason: '$type');
        expect(failure.retryAfter, 15);
      }
    });

    test('429 بجسمٍ نصّيّ ضخم لا يتسرّب إلى الرسالة', () {
      final Failure failure = _handle(
        _withResponse(statusCode: 429, data: '<!DOCTYPE html><html>...'),
      );
      expect(failure.message, ResponseMessage.tooManyRequests);
    });

    test('428 و430 ليسا 429 (حدّا النطاق)', () {
      for (final int code in <int>[428, 430]) {
        final Failure failure = _handle(_withResponse(statusCode: code));
        expect(failure.retryAfter, isNull, reason: '$code');
        expect(failure.isTooManyRequests, isFalse);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. تحليل الجسم بأشكاله (_parseResponseData)
  // ═══════════════════════════════════════════════════════════════════════
  group('أشكال جسم الاستجابة', () {
    test('نصّ JSON صالح عند 400 يُحلَّل وتُقرأ رسالته', () {
      final Failure failure = _handle(
        _withResponse(statusCode: 400, data: '{"message":"رصيدك لا يكفي"}'),
      );
      expect(failure.code, 400);
      expect(failure.message, 'رصيدك لا يكفي');
    });

    test('نصّ JSON بأخطاء حقول عند 422 يُحلَّل كاملاً', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 422,
          data:
              '{"detail":"بيانات ناقصة","fields":[{"field":"name","message":"مطلوب"}]}',
        ),
      );
      expect(failure.message, 'بيانات ناقصة');
      expect(failure.fieldError('name'), 'مطلوب');
    });

    test('صفحة HTML لا تتسرّب إلى رسالة المستخدم', () {
      final Failure failure = _handle(
        _withResponse(
          statusCode: 400,
          data:
              '<!DOCTYPE html><html lang="en" dir="rtl"><head><title>خطأ</title></head></html>',
        ),
      );
      expect(failure.message, isNull);
      expect(failure.displayMessage, isNot(contains('DOCTYPE')));
    });

    test('نصوصٌ غير JSON وأجسامٌ غير خرائط كلّها بلا رسالة', () {
      final List<Object> bodies = <Object>[
        'Bad Request',
        '',
        '   ',
        'null',
        '[]',
        '[{"message":"في مصفوفة"}]',
        '"نصّ JSON لا خريطة"',
        42,
        3.14,
        true,
        <int>[1, 2, 3],
        <Object>[<String, dynamic>{'message': 'داخل قائمة'}],
      ];
      for (final Object body in bodies) {
        final Failure failure = _handle(
          _withResponse(statusCode: 400, data: body),
        );
        expect(failure.code, 400, reason: '$body');
        expect(failure.message, isNull, reason: '$body');
      }
    });

    test('جسمٌ null يسلك مسلك «بلا جسم»', () {
      final Failure failure = _handle(_withResponse(statusCode: 404));
      expect(failure.message, ResponseMessage.notFound);
    });

    // تراجع (regression): كان فرعا 404 و401 في `_handleBadResponse` يسبقان
    // `_parseResponseData`، فرسالة الخادم في جسمٍ نصّيّ تضيع — بينما تصل لو
    // سلّمتها Dio خريطةً. والفرق يعود إلى `responseType` لا إلى الخادم.
    test('نصّ JSON عند 404 يُقرأ كما يُقرأ عند 400', () {
      final Failure failure = _handle(
        _withResponse(statusCode: 404, data: '{"detail":"الطلب غير موجود"}'),
      );
      expect(failure.message, 'الطلب غير موجود');
    });

    test('نصّ JSON عند 401 تصل رسالته كذلك', () {
      final Failure failure = _handle(
        _withResponse(statusCode: 401, data: '{"detail":"انتهت صلاحية الجلسة"}'),
      );
      expect(failure.code, ResponseCode.unauthorized);
      expect(failure.message, 'انتهت صلاحية الجلسة');
    });

    test('نصّ JSON بلا مفتاح رسالةٍ عند 404 يُبقي الرسالة المعلّبة', () {
      // جسمٌ لا يفيد المستخدم بشيء لا يُصادر رسالة الحالة العامّة.
      final Failure failure = _handle(
        _withResponse(statusCode: 404, data: '{"code":"E_GONE"}'),
      );
      expect(failure.code, ResponseCode.notFound);
      expect(failure.message, ResponseMessage.notFound);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. أخطاء ليست من Dio
  // ═══════════════════════════════════════════════════════════════════════
  group('أخطاء غير Dio', () {
    test('SocketException → خلل في الاتصال', () {
      final Failure failure = _handle(
        const SocketException('Connection refused'),
      );
      expect(failure.code, ResponseCode.socketException);
      expect(failure.message, ResponseMessage.socketException);
    });

    test('نصّ الاستثناء التقنيّ لا يصل إلى المستخدم', () {
      final Failure failure = _handle(
        TypeError(),
      );
      expect(failure.code, ResponseCode.unknown);
      expect(failure.message, ResponseMessage.unknown);
      expect(failure.displayMessage, isNot(contains('subtype')));
      expect(failure.displayMessage, isNot(contains('type ')));
    });

    test('FormatException لا تكشف تفاصيلها', () {
      final Failure failure = _handle(
        const FormatException('Unexpected character (at character 1)'),
      );
      expect(failure.message, ResponseMessage.unknown);
      expect(failure.displayMessage, isNot(contains('Unexpected')));
    });

    test('null لا يُسقط المعالج', () {
      final Failure failure = _handle(null);
      expect(failure.code, ResponseCode.unknown);
      expect(failure.message, ResponseMessage.unknown);
    });

    test('أنواعٌ متفرّقة (نصّ، عدد، قائمة، خريطة، Error) كلّها «غير متوقع»', () {
      final List<Object> errors = <Object>[
        'خطأ نصّي',
        '',
        0,
        -1,
        <String>[],
        <String, dynamic>{'message': 'لن تُقرأ'},
        StateError('bad state'),
        ArgumentError.notNull('id'),
        Exception('عام'),
      ];
      for (final Object error in errors) {
        final Failure failure = _handle(error);
        expect(failure.code, ResponseCode.unknown, reason: '$error');
        expect(failure.message, ResponseMessage.unknown, reason: '$error');
        expect(failure.hasFields, isFalse);
        expect(failure.retryAfter, isNull);
      }
    });

    test('ErrorHandler نفسه استثناء يمكن رميه', () {
      expect(ErrorHandler.handle(null), isA<Exception>());
    });

    test('خطأ Dio ملفوفٌ داخل خطأ Dio يُعالَج بالخارجيّ', () {
      final Failure failure = _handle(
        _bare(
          DioExceptionType.cancel,
          error: _bare(DioExceptionType.receiveTimeout),
        ),
      );
      expect(failure.code, ResponseCode.cancel);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. ErrorType.toFailure — جدول الترجمة
  // ═══════════════════════════════════════════════════════════════════════
  group('ErrorType.toFailure', () {
    test('كلّ قيمة تُنتج رسالةً عربية غير فارغة', () {
      for (final ErrorType type in ErrorType.values) {
        final Failure failure = type.toFailure();
        expect(failure.message, isNotNull, reason: '$type');
        expect(failure.message!.trim(), isNotEmpty, reason: '$type');
        expect(failure.fields, isEmpty);
        expect(failure.retryAfter, isNull);
      }
    });

    test('الأكواد المخصّصة السالبة تبقى على حالها', () {
      expect(ErrorType.connectTimeout.toFailure().code, -11);
      expect(ErrorType.cancelled.toFailure().code, -12);
      expect(ErrorType.receiveTimeout.toFailure().code, -13);
      expect(ErrorType.sendTimeout.toFailure().code, -14);
      expect(ErrorType.cacheError.toFailure().code, -15);
      expect(ErrorType.wrongPassword.toFailure().code, -17);
      expect(ErrorType.sellerAccountNotFound.toFailure().code, -18);
      expect(ErrorType.socketException.toFailure().code, -1);
    });

    test('connectionError و noInternetConnection يشتركان في كود «لا اتصال»', () {
      expect(
        ErrorType.connectionError.toFailure().code,
        ResponseCode.noInternetConnection,
      );
      expect(
        ErrorType.noInternetConnection.toFailure().code,
        ResponseCode.noInternetConnection,
      );
      // الرسالتان تبقيان مختلفتين: الأولى تعذّر الوصول للخادم، والثانية شبكة
      // الجهاز نفسها.
      expect(
        ErrorType.connectionError.toFailure().message,
        isNot(ErrorType.noInternetConnection.toFailure().message),
      );
    });

    test('لا واحدة من الحالات الناجحة تُعدّ خطأ خادم', () {
      expect(ErrorType.success.toFailure().code, ResponseCode.success);
      expect(
        ErrorType.successNoContent.toFailure().code,
        ResponseCode.noContent,
      );
    });
  });
}
