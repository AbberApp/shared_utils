// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك، وهو يُثبت أنّ
// `Response` و`DioException` مُعادا التصدير — لولاهما لما جاز نداء
// `handleResponse` أصلاً من خارج المكتبة.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// استجابة Dio جاهزة — كلّ اختبار يبني واحدة بجسمٍ وكودٍ فقط.
Response<dynamic> _res(
  dynamic data, {
  int? code = 200,
  String path = '/api/items',
}) => Response<dynamic>(
  requestOptions: RequestOptions(path: path),
  statusCode: code,
  data: data,
);

/// يلتقط الاستثناء المرميّ من [handleResponse] ليُفحص حقلاً حقلاً.
DioException _errorOf(Response<dynamic> response) {
  try {
    handleResponse(response);
  } on DioException catch (e) {
    return e;
  }
  fail('كان يجب أن يُرمى DioException للكود ${response.statusCode}');
}

/// ترويسة صفحة الخطأ مرصوصةً — أضيقُ شكلٍ تصل به وثيقةُ HTML.
const String _htmlMarker =
    '<!DOCTYPE html><html lang="en" dir="rtl"><head><title>خطأ';

/// صفحة خطأ الخادم كما يبعثها الواجهة الخلفية فعلاً.
const String _htmlErrorPage =
    '$_htmlMarker في الخادم</title></head><body><h1>خطأ</h1></body></html>';

/// جسمٌ ينفجر عند `toString()` — لاختبار شبكة الأمان الخارجية.
class _ExplodingBody {
  @override
  String toString() => throw const FormatException('toString انفجر');
}

/// جسمٌ يرمي `Error` (لا `Exception`) عند `toString()`.
class _ErrorThrowingBody {
  @override
  String toString() => throw StateError('toString رمى Error');
}

void main() {
  group('نجاح — خريطة وقائمة ونصّ JSON', () {
    test('200 بخريطة مفكوكة: تُعاد هي نفسها بلا نسخ', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'id': 7,
        'name': 'أحمد',
      };
      expect(handleResponse(_res(body)), same(body));
    });

    test('200 بنصّ JSON لخريطة: يُفكّ إلى Map بقيمه العربية', () {
      final dynamic result = handleResponse(
        _res('{"id":7,"name":"أحمد","city":"الرياض"}'),
      );
      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], 7);
      expect(result['name'], 'أحمد');
      expect(result['city'], 'الرياض');
    });

    test('200 بقائمة مفكوكة: تُعاد هي نفسها', () {
      final List<dynamic> body = <dynamic>[1, 2, 3];
      expect(handleResponse(_res(body)), same(body));
    });

    test('200 بنصّ JSON لقائمة: يُفكّ إلى List', () {
      final dynamic result = handleResponse(_res('[{"id":1},{"id":2}]'));
      expect(result, isA<List<dynamic>>());
      expect(result.length, 2);
      expect(result[1]['id'], 2);
    });

    test('200 بنصّ JSON متداخل عميق: يُفكّ بالكامل', () {
      final String body = jsonEncode(<String, dynamic>{
        'count': 2,
        'results': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'owner': <String, dynamic>{
              'name': 'محمد',
              'tags': <String>['ذهبي', 'موثّق'],
            },
          },
        ],
      });
      final dynamic result = handleResponse(_res(body));
      expect(result['count'], 2);
      expect(result['results'][0]['owner']['name'], 'محمد');
      expect(result['results'][0]['owner']['tags'], <String>['ذهبي', 'موثّق']);
    });

    test('200 بنصّ فيه محارف عربية ومهرّبة: يعود كما أُرسل', () {
      final Map<String, dynamic> original = <String, dynamic>{
        'note': 'سطرٌ\nجديد "باقتباس" وشرطة \\',
        'emoji': 'تم ✓',
      };
      final dynamic result = handleResponse(_res(jsonEncode(original)));
      expect(result, equals(original));
    });

    test('200 بنصّ JSON لعدد: يُفكّ إلى int لا يبقى نصّاً', () {
      expect(handleResponse(_res('42')), 42);
    });

    test('200 بنصّ JSON لعدد سالب وعشريّ: يُفكّ كما هو', () {
      expect(handleResponse(_res('-7')), -7);
      expect(handleResponse(_res('-0.5')), -0.5);
      expect(handleResponse(_res('0')), 0);
    });

    test('200 بنصّ JSON منطقي: يُفكّ إلى bool', () {
      expect(handleResponse(_res('true')), isTrue);
      expect(handleResponse(_res('false')), isFalse);
    });

    test('200 بنصّ "null": JSON صالح فيعود null (لا خريطة فارغة)', () {
      // مقصود توثيقه: خلافاً لجسم null الحقيقي الذي يعود {}.
      expect(handleResponse(_res('null')), isNull);
    });

    test('200 بقائمة بايتات (List<int>): تُعاد كما هي بلا محاولة فكّ', () {
      final List<int> bytes = <int>[137, 80, 78, 71];
      expect(handleResponse(_res(bytes)), same(bytes));
    });

    test('نصّ JSON طويل جدّاً (٥٠٠٠ عنصر): يُفكّ كاملاً', () {
      final String body = jsonEncode(
        List<Map<String, dynamic>>.generate(
          5000,
          (int i) => <String, dynamic>{'id': i, 'name': 'عنصر $i'},
        ),
      );
      final dynamic result = handleResponse(_res(body));
      expect(result.length, 5000);
      expect(result[4999]['name'], 'عنصر 4999');
    });
  });

  group('أكواد النجاح 2xx المختلفة', () {
    for (final int code in <int>[200, 201, 202, 203, 206, 299]) {
      test('$code: الجسم يمرّ كما هو', () {
        final Map<String, dynamic> body = <String, dynamic>{'ok': true};
        expect(handleResponse(_res(body, code: code)), same(body));
      });
    }

    test('204: رسالة حذفٍ عربية بدل الجسم', () {
      expect(handleResponse(_res(null, code: 204)), 'تمت عملية الحذف بنجاح');
    });

    test('204 ولو وصل جسم: الرسالة نفسها والجسم يُهمل', () {
      expect(
        handleResponse(_res(<String, dynamic>{'id': 3}, code: 204)),
        'تمت عملية الحذف بنجاح',
      );
    });

    test('205 بجسم null: خريطة فارغة لا null', () {
      final dynamic result = handleResponse(_res(null, code: 205));
      expect(result, isA<Map<dynamic, dynamic>>());
      expect(result, isEmpty);
    });
  });

  group('الجسم الفارغ', () {
    test('200 بجسم null: {} تحمي Model.fromJson من null', () {
      final dynamic result = handleResponse(_res(null));
      expect(result, isA<Map<dynamic, dynamic>>());
      expect(result, isEmpty);
    });

    test('200 بخريطة فارغة: تُعاد فارغة لا تُبدَّل', () {
      final Map<String, dynamic> body = <String, dynamic>{};
      expect(handleResponse(_res(body)), same(body));
    });

    test('200 بقائمة فارغة: تُعاد فارغة', () {
      expect(handleResponse(_res(<dynamic>[])), isEmpty);
    });

    test('200 بنصّ "{}" و"[]": يُفكّان إلى فارغَين', () {
      expect(handleResponse(_res('{}')), isEmpty);
      expect(handleResponse(_res('[]')), isEmpty);
    });

    test('200 بنصّ فارغ: لا يرمي البتّة', () {
      expect(() => handleResponse(_res('')), returnsNormally);
      expect(() => handleResponse(_res('   ')), returnsNormally);
    });

    test('200 بجسمٍ نصّيٍّ فارغ: {} كحال جسم null (لا نصّ يكسر fromJson)', () {
      // خادمٌ يردّ 200 بلا محتوى يصل جسمه '' لا null (أثرُ ResponseType.plain)،
      // فكان يُعاد نصّاً ويُمرَّر إلى Model.fromJson فينفجر بـ«String is not a
      // subtype of Map». صار يُعامَل معاملة الجسم الفارغ.
      expect(handleResponse(_res('')), isA<Map<dynamic, dynamic>>());
      expect(handleResponse(_res('   ')), isA<Map<dynamic, dynamic>>());
      expect(handleResponse(_res('')), isEmpty);
      expect(handleResponse(_res('\n\t  ')), isEmpty);
    });

    test('201 بجسمٍ نصّيٍّ فارغ: {} كذلك — كلّ أكواد النجاح سواء', () {
      expect(handleResponse(_res('', code: 201)), isEmpty);
    });

    test('نصّ غير فارغ غير قابل للتحليل: ما زال يعود خاماً لا {}', () {
      // حدُّ الإصلاح: الفراغ وحده يُبدَّل بخريطة، وردُّ النصّ العاديّ محفوظ.
      expect(handleResponse(_res('تم بنجاح')), 'تم بنجاح');
    });
  });

  group('جسم غير قابل للتحليل — يُعاد خاماً بلا رمي', () {
    test('نصّ عربي عادي: يعود كما هو', () {
      expect(handleResponse(_res('مرحباً بك')), 'مرحباً بك');
    });

    test('نصّ مشوّه يشبه JSON: يعود خاماً', () {
      expect(handleResponse(_res('not json {{{')), 'not json {{{');
    });

    test('JSON مبتور: يعود خاماً لا يرمي', () {
      expect(handleResponse(_res('{"id":1')), '{"id":1');
    });

    test('JSON بفاصلة زائدة: يعود خاماً', () {
      expect(handleResponse(_res('{"id":1,}')), '{"id":1,}');
    });

    test('نصّ طويل جدّاً غير قابل للتحليل: يعود بطوله كاملاً', () {
      final String long = 'تقرير ${'أ' * 200000}';
      final dynamic result = handleResponse(_res(long));
      expect(result, same(long));
      expect(result.length, greaterThan(200000));
    });
  });

  group('أخطاء العميل 4xx', () {
    for (final int code in <int>[400, 401, 403, 404, 409, 422, 429, 499]) {
      test('$code: DioException من نوع badResponse', () {
        final DioException e = _errorOf(
          _res(<String, dynamic>{'detail': 'خطأ'}, code: code),
        );
        expect(e.type, DioExceptionType.badResponse);
        expect(e.response?.statusCode, code);
      });
    }

    test('400: جسم الأخطاء يبقى في response.data ليقرأه ErrorHandler', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'phone': <String>['رقم غير صالح'],
      };
      final DioException e = _errorOf(_res(body, code: 400));
      expect(e.response?.data, same(body));
    });

    test('404: requestOptions محفوظة بمسارها', () {
      final DioException e = _errorOf(_res(null, code: 404, path: '/api/x/9'));
      expect(e.requestOptions.path, '/api/x/9');
    });

    test('4xx بجسم null: يرمي ولا ينهار', () {
      expect(
        _errorOf(_res(null, code: 400)).type,
        DioExceptionType.badResponse,
      );
    });
  });

  group('أخطاء الخادم 5xx', () {
    for (final int code in <int>[500, 501, 502, 503, 504, 599]) {
      test('$code: badResponse كي يصنّفها ErrorHandler خطأ خادم', () {
        final DioException e = _errorOf(_res('boom', code: code));
        expect(e.type, DioExceptionType.badResponse);
        expect(e.response?.statusCode, code);
      });
    }

    test('500 بجسم null: رسالة عربية افتراضية في error', () {
      expect(_errorOf(_res(null, code: 500)).error, 'حدث خطأ غير متوقع');
    });

    test('500 بخريطة: الخريطة نفسها في error', () {
      final Map<String, dynamic> body = <String, dynamic>{'detail': 'تعطّل'};
      expect(_errorOf(_res(body, code: 500)).error, same(body));
    });
  });

  group('أكواد خارج النطاقات — تصنيف unknown', () {
    for (final int code in <int>[-1, 0, 100, 199, 301, 302, 399, 600, 999]) {
      test('$code: DioException من نوع unknown', () {
        final DioException e = _errorOf(_res(null, code: code));
        expect(e.type, DioExceptionType.unknown);
        expect(e.error, 'حدث خطأ غير متوقع');
      });
    }

    test('0 بجسمٍ موجود: الجسم يصل في error', () {
      final Map<String, dynamic> body = <String, dynamic>{'x': 1};
      expect(_errorOf(_res(body, code: 0)).error, same(body));
    });

    test('كود مفقود (null): يُعامَل كـ500 فيُرمى badResponse', () {
      final DioException e = _errorOf(_res('تعذّر', code: null));
      expect(e.type, DioExceptionType.badResponse);
      // الاستجابة نفسها تبقى بلا كود — الافتراضُ 500 محليٌّ داخل الدالة وحدها.
      expect(e.response?.statusCode, isNull);
    });
  });

  group('حمولة HTML', () {
    test('200 بصفحة خطأ HTML: يُرمى بدل أن تُعاد الصفحة نصّاً', () {
      final DioException e = _errorOf(_res(_htmlErrorPage));
      expect(e.type, DioExceptionType.badResponse);
    });

    test('500 بصفحة خطأ HTML: يُرمى', () {
      expect(
        _errorOf(_res(_htmlErrorPage, code: 500)).type,
        DioExceptionType.badResponse,
      );
    });

    test('403 بصفحة خطأ HTML: يُرمى والاستجابة تحتفظ بكودها', () {
      final DioException e = _errorOf(_res(_htmlErrorPage, code: 403));
      expect(e.type, DioExceptionType.badResponse);
      expect(e.response?.statusCode, 403);
    });

    test('204 بصفحة HTML: الرفض أسبق من رسالة الحذف', () {
      expect(
        _errorOf(_res(_htmlErrorPage, code: 204)).type,
        DioExceptionType.badResponse,
      );
    });

    test('خريطة يحوي أحد حقولها القالب: تمرّ — الفحص على بداية الجسم', () {
      // الفحص يسأل «هل الجسم وثيقةُ HTML؟» فينظر في بدايته بعد التشذيب.
      // نصُّ خريطةٍ يبدأ بـ`{`، فهي بياناتٌ سليمة وإن اقتبس أحد حقولها
      // الصفحة — واتّهامها يُضيّع ردّ الخادم الحقيقيّ على المستخدم.
      final Map<String, dynamic> body = <String, dynamic>{
        'raw': _htmlErrorPage,
      };
      expect(handleResponse(_res(body)), same(body));
    });

    test('خريطة سليمة لا تحوي القالب: تمرّ بلا رفض', () {
      final Map<String, dynamic> body = <String, dynamic>{'html': '<b>نص</b>'};
      expect(handleResponse(_res(body)), same(body));
    });

    test('200 بصفحة HTML: الخطأ المرميّ يحمل تصنيف خادم 500 لا 200', () {
      // `DioException.badResponse(statusCode: 500)` لا تمسّ response.statusCode
      // (dio تستعمله لصياغة message وحدها)، فكان يصل ErrorHandler كودُ 200:
      // لا 4xx ولا 5xx، فيسقط إلى badRequest بدل internalServerError.
      expect(_errorOf(_res(_htmlErrorPage)).response?.statusCode, 500);
    });

    test(
      '200 بصفحة HTML: ErrorHandler يصنّفها عطلَ خادم لا «طلباً غير صالح»',
      () {
        final Failure failure = ErrorHandler.handle(
          _errorOf(_res(_htmlErrorPage)),
        ).failure;
        expect(failure.code, ResponseCode.internalServerError);
      },
    );

    test(
      '200 بصفحة HTML: الاستجابة الأصلية لا يُغيَّر كودها تحت يد المستدعي',
      () {
        // النسخةُ بكود 500 تدخل الاستثناء وحده؛ ما يملكه المستدعي يبقى كما هو.
        final Response<dynamic> response = _res(_htmlErrorPage);
        _errorOf(response);
        expect(response.statusCode, 200);
        expect(response.data, same(_htmlErrorPage));
      },
    );

    test(
      'صفحة HTML عامّة (سطور، أو من nginx) بكود 200: تُرفض لا تُعاد نصّاً',
      () {
        // API لا يردّ HTML أبداً؛ أيّ صفحة (بوّابة دخول، 502 من nginx،
        // قالبنا نفسه بسطرٍ جديد) يجب أن تُرفض، وإلّا مرّت نصّاً إلى
        // Model.fromJson فانفجرت هناك برسالة لا تدلّ على السبب.
        const String nginx =
            '<!DOCTYPE html>\n<html>\n<head><title>502 Bad '
            'Gateway</title></head>\n<body>nginx</body>\n</html>';
        expect(_errorOf(_res(nginx)).type, DioExceptionType.badResponse);
      },
    );
  });

  group('شبكة الأمان الخارجية', () {
    test(
      'جسم يرمي Exception عند toString (كود نجاح): unknown برسالة عربية',
      () {
        final DioException e = _errorOf(_res(_ExplodingBody()));
        expect(e.type, DioExceptionType.unknown);
        expect(e.error.toString(), startsWith('خطأ غير متوقع: '));
      },
    );

    test('جسم يرمي Exception عند toString (كود خطأ): unknown كذلك', () {
      final DioException e = _errorOf(_res(_ExplodingBody(), code: 500));
      expect(e.type, DioExceptionType.unknown);
      // مقصود توثيقه: هذا المسار وحده يفقد response فلا يبقى للكود أثر.
      expect(e.response, isNull);
    });

    test(
      'جسم يرمي Error (لا Exception): يتسرّب كما هو — الشبكة تلتقط Exception فقط',
      () {
        expect(
          () => handleResponse(_res(_ErrorThrowingBody())),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('ثبات', () {
    test('نداءان متتاليان على الاستجابة نفسها يعطيان النتيجة نفسها', () {
      final Response<dynamic> response = _res('{"id":1,"name":"سارة"}');
      expect(handleResponse(response), equals(handleResponse(response)));
    });
  });

  _jsonGroups();
}

/// يلتقط الاستثناء المرميّ من [handleJsonResponse] ليُفحص حقلاً حقلاً.
DioException _jsonErrorOf(Response<dynamic> response) {
  try {
    handleJsonResponse(response);
  } on DioException catch (e) {
    return e;
  }
  fail('كان يجب أن يُرمى DioException للجسم ${response.data.runtimeType}');
}

void _jsonGroups() {
  group('handleJsonResponse — نجاحٌ بخريطة', () {
    test('خريطة مفكوكة: تُعاد هي نفسها بلا نسخ', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'id': 7,
        'name': 'أحمد',
      };
      expect(handleJsonResponse(_res(body)), same(body));
    });

    test('نصّ JSON لكائن: يُفكّ إلى خريطةٍ بقيمه العربية', () {
      final Map<String, dynamic> result = handleJsonResponse(
        _res('{"id":7,"name":"أحمد","city":"الرياض"}'),
      );
      expect(result['id'], 7);
      expect(result['name'], 'أحمد');
      expect(result['city'], 'الرياض');
    });

    test('نصّ JSON متداخل عميق: يُفكّ بالكامل', () {
      final Map<String, dynamic> result = handleJsonResponse(
        _res(
          jsonEncode(<String, dynamic>{
            'count': 1,
            'results': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'owner': <String, dynamic>{'name': 'محمد'},
              },
            ],
          }),
        ),
      );
      expect(result['count'], 1);
      expect(result['results'][0]['owner']['name'], 'محمد');
    });

    test('نصّ "{}" : خريطة فارغة لا خطأ', () {
      expect(handleJsonResponse(_res('{}')), isEmpty);
    });

    test('خريطة بنوعٍ أعمّ ومفاتيح نصّية: تُنسخ إلى Map<String, dynamic>', () {
      final Map<dynamic, dynamic> body = <dynamic, dynamic>{
        'id': 3,
        'name': 'سارة',
      };
      final Map<String, dynamic> result = handleJsonResponse(_res(body));
      expect(result, isA<Map<String, dynamic>>());
      expect(result, isNot(same(body)));
      expect(result['name'], 'سارة');
    });

    test('Map<String, String>: يمرّ كما هو (تغايرُ الأنواع في Dart)', () {
      final Map<String, String> body = <String, String>{'name': 'ليلى'};
      expect(handleJsonResponse(_res(body)), same(body));
    });

    test('نداءان متتاليان يعطيان النتيجة نفسها', () {
      final Response<dynamic> response = _res('{"id":1,"name":"سارة"}');
      expect(
        handleJsonResponse(response),
        equals(handleJsonResponse(response)),
      );
    });
  });

  group('handleJsonResponse — الجسم الفارغ و204', () {
    test('جسم null: خريطة فارغة كحال handleResponse', () {
      expect(handleJsonResponse(_res(null)), isEmpty);
    });

    test('جسم نصّيّ فارغ أو مسافات: خريطة فارغة لا خطأ', () {
      expect(handleJsonResponse(_res('')), isEmpty);
      expect(handleJsonResponse(_res('   ')), isEmpty);
      expect(handleJsonResponse(_res('\n\t  ')), isEmpty);
    });

    test('204: خريطة فارغة لا رسالة الحذف النصّية', () {
      // handleResponse يردّ نصّاً للعرض؛ عقدُ الصارمة خريطة، و«لا محتوى»
      // جسمٌ فارغ لا خطأ.
      expect(handleJsonResponse(_res(null, code: 204)), isEmpty);
      expect(
        handleJsonResponse(_res(<String, dynamic>{'id': 3}, code: 204)),
        isEmpty,
      );
    });

    test('205 بجسم null: خريطة فارغة', () {
      expect(handleJsonResponse(_res(null, code: 205)), isEmpty);
    });

    test('201 بجسم نصّيّ فارغ: خريطة فارغة', () {
      expect(handleJsonResponse(_res('', code: 201)), isEmpty);
    });
  });

  group('handleJsonResponse — جسمٌ ليس كائن JSON يرمي خطأً مفهوماً', () {
    test('نصّ عربي عادي: unknown لا نصّ يتسرّب إلى fromJson', () {
      final DioException e = _jsonErrorOf(_res('تم بنجاح'));
      expect(e.type, DioExceptionType.unknown);
      expect(e.error.toString(), contains('ليست كائن JSON'));
      expect(e.error.toString(), contains('تم بنجاح'));
    });

    test('رسالة الخطأ تحمل مسار الطلب', () {
      final DioException e = _jsonErrorOf(_res('تقرير', path: '/api/report/9'));
      expect(e.error.toString(), contains('/api/report/9'));
    });

    test('الاستثناء يحتفظ بالاستجابة وبـrequestOptions', () {
      final Response<dynamic> response = _res('CSV;1;2', path: '/api/export');
      final DioException e = _jsonErrorOf(response);
      expect(e.response, same(response));
      expect(e.requestOptions.path, '/api/export');
    });

    test('JSON مبتور أو مشوّه: يرمي بدل أن يعود خاماً', () {
      expect(_jsonErrorOf(_res('{"id":1')).type, DioExceptionType.unknown);
      expect(_jsonErrorOf(_res('not json {{{')).type, DioExceptionType.unknown);
      expect(_jsonErrorOf(_res('{"id":1,}')).type, DioExceptionType.unknown);
    });

    test('قائمة JSON في الجذر (نصّاً أو مفكوكة): يرمي ويذكر العدد', () {
      final DioException e = _jsonErrorOf(_res('[{"id":1},{"id":2}]'));
      expect(e.type, DioExceptionType.unknown);
      expect(e.error.toString(), contains('قائمةً (2 عنصراً)'));
      expect(
        _jsonErrorOf(_res(<dynamic>[1, 2, 3])).type,
        DioExceptionType.unknown,
      );
      expect(
        _jsonErrorOf(_res(<dynamic>[])).error.toString(),
        contains('قائمةً (0 عنصراً)'),
      );
    });

    test('قائمة بايتات: يرمي — الملفّات تُقرأ بـhandleResponse', () {
      expect(
        _jsonErrorOf(_res(<int>[137, 80, 78, 71])).type,
        DioExceptionType.unknown,
      );
    });

    test('نصّ "null": يرمي ويُسمّي القيمة (handleResponse يُعيدها null)', () {
      expect(_jsonErrorOf(_res('null')).error.toString(), contains('null'));
    });

    test('قيمة JSON مفردة (عدد أو منطقيّ): يرمي ويذكر نوعها', () {
      expect(_jsonErrorOf(_res('42')).error.toString(), contains('int'));
      expect(_jsonErrorOf(_res('-0.5')).error.toString(), contains('double'));
      expect(_jsonErrorOf(_res('true')).error.toString(), contains('bool'));
    });

    test('خريطة بمفاتيح غير نصّية: يرمي بوصفٍ يدلّ على السبب', () {
      final DioException e = _jsonErrorOf(
        _res(<dynamic, dynamic>{1: 'أ', 2: 'ب'}),
      );
      expect(e.type, DioExceptionType.unknown);
      expect(e.error.toString(), contains('مفاتيحُها ليست كلّها نصوصاً'));
    });

    test('خريطة فارغة بنوعٍ أعمّ: تمرّ (لا مفاتيح تُخالف)', () {
      expect(handleJsonResponse(_res(<dynamic, dynamic>{})), isEmpty);
    });

    test('تقرير طويل: الرسالة تبقى قصيرة بمقتطفٍ مبتور', () {
      final String long = 'تقرير ${'أ' * 200000}';
      final String message = _jsonErrorOf(_res(long)).error.toString();
      expect(message.length, lessThan(300));
      expect(message, contains('…'));
    });
  });

  group('handleJsonResponse — يرث أخطاء handleResponse كما هي', () {
    for (final int code in <int>[400, 401, 403, 404, 409, 429, 499]) {
      test('$code: badResponse بكوده محفوظاً', () {
        final DioException e = _jsonErrorOf(
          _res(<String, dynamic>{'detail': 'خطأ'}, code: code),
        );
        expect(e.type, DioExceptionType.badResponse);
        expect(e.response?.statusCode, code);
      });
    }

    test('400: جسم أخطاء الحقول يبقى في response.data ليقرأه ErrorHandler', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'phone': <String>['رقم غير صالح'],
      };
      expect(_jsonErrorOf(_res(body, code: 400)).response?.data, same(body));
    });

    test('500: badResponse لا unknown', () {
      final DioException e = _jsonErrorOf(_res('boom', code: 500));
      expect(e.type, DioExceptionType.badResponse);
      expect(e.response?.statusCode, 500);
    });

    test('كود خارج النطاقات: unknown برسالة handleResponse العربية', () {
      expect(_jsonErrorOf(_res(null, code: 999)).error, 'حدث خطأ غير متوقع');
    });

    test('صفحة خطأ HTML بكود 200: تُرفض قبل فحص النوع', () {
      expect(
        _jsonErrorOf(_res(_htmlErrorPage)).type,
        DioExceptionType.badResponse,
      );
    });

    test('204 بصفحة HTML: الرفض أسبق من الخريطة الفارغة', () {
      expect(
        _jsonErrorOf(_res(_htmlErrorPage, code: 204)).type,
        DioExceptionType.badResponse,
      );
    });

    test('جسم يرمي Exception عند toString: unknown كما في handleResponse', () {
      final DioException e = _jsonErrorOf(_res(_ExplodingBody()));
      expect(e.type, DioExceptionType.unknown);
      expect(e.error.toString(), startsWith('خطأ غير متوقع: '));
    });

    test('جسم يرمي Error: يتسرّب كما هو — الشبكة تلتقط Exception فقط', () {
      expect(
        () => handleJsonResponse(_res(_ErrorThrowingBody())),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('handleJsonResponse مع ErrorHandler', () {
    test('نصّ خام بكود 200: فشلٌ عامّ لا «طلب غير صالح» يلوم المستخدم', () {
      // unknown مقصود: الطلب كان سليماً، والعيب في جسم الاستجابة.
      final Failure failure = ErrorHandler.handle(
        _jsonErrorOf(_res('تقرير نصّي')),
      ).failure;
      expect(failure.code, ResponseCode.unknown);
      expect(failure.displayMessage, isNotEmpty);
    });

    test('404: يبقى «غير موجود» كما لو نُودي handleResponse', () {
      final Failure failure = ErrorHandler.handle(
        _jsonErrorOf(_res(null, code: 404)),
      ).failure;
      expect(failure.code, ResponseCode.notFound);
    });
  });
}
