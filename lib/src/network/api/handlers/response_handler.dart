import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/response_code.dart';

/// معالج استجابات API
dynamic handleResponse(Response<dynamic> response) {
  try {
    final int statusCode = response.statusCode ?? 500;
    final dynamic data = response.data;
    final RequestOptions requestOptions = response.requestOptions;

    if (ResponseCode.isSuccessful(statusCode)) {
      return _handleSuccessResponse(statusCode, data, response, requestOptions);
    } else if (ResponseCode.isBadHtmlResponse(data.toString())) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: requestOptions,
        response: response,
      );
    } else if (ResponseCode.isServerError(statusCode)) {
      // badResponse: استجابةٌ وصلت بكود خطأ — هذا وحده ما يوجّه ErrorHandler
      // إلى _handleBadResponse فيصنّف 5xx كـ internalServerError بدل unknown.
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        error: data ?? 'حدث خطأ غير متوقع',
        type: DioExceptionType.badResponse,
      );
    } else if (ResponseCode.isClientError(statusCode)) {
      throw DioException.badResponse(
        statusCode: statusCode,
        requestOptions: requestOptions,
        response: response,
      );
    } else {
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        error: data ?? 'حدث خطأ غير متوقع',
        type: DioExceptionType.unknown,
      );
    }
  } on DioException {
    rethrow;
  } on Exception catch (e) {
    throw DioException(
      requestOptions: response.requestOptions,
      error: 'خطأ غير متوقع: ${e.toString()}',
      type: DioExceptionType.unknown,
    );
  }
}

dynamic _handleSuccessResponse(
  int statusCode,
  dynamic data,
  Response<dynamic> response,
  RequestOptions requestOptions,
) {
  // التحقق من استجابة HTML خاطئة
  if (data != null && ResponseCode.isBadHtmlResponse(data.toString())) {
    throw DioException.badResponse(
      statusCode: ResponseCode.internalServerError,
      requestOptions: requestOptions,
      // الاستجابة تُبدَّل بنسخةٍ كودُها 500 لا تُمرَّر كما هي: وسيط
      // `statusCode` في `DioException.badResponse` يصوغ نصّ الرسالة وحده
      // ولا يمسّ `response.statusCode`. فلولا النسخة لوصل ErrorHandler كودُ
      // النجاح (200) — لا خطأ عميلٍ ولا خطأ خادم — فيسقط إلى `badRequest`
      // فيُقال للمستخدم «طلب غير صالح» وطلبُه سليم، والعطل عطلُ خادمٍ ردّ
      // صفحةَ خطأ مكان البيانات.
      response: _asServerError(response, requestOptions),
    );
  }

  // استجابة حذف ناجحة
  if (statusCode == ResponseCode.noContent) {
    return 'تمت عملية الحذف بنجاح';
  }

  // جسمٌ نصّيٌّ فارغ = جسمٌ فارغ، فيُعامَل معاملة `null` تماماً.
  // السبب: `DioConsumer` يثبّت `ResponseType.plain` على العميل كلّه، ومحوِّل
  // dio لا يُعيد `null` للجسم الفارغ إلّا حين يكون Content-Type من نوع JSON؛
  // وإلّا يصل النصّ `''`. فاستجابة 200/201 بلا محتوى و`Content-Type: text/html`
  // — افتراضُ Django لـ`HttpResponse(status=200)` — كانت تعبر حارس
  // `data != null`، ويفشل فكّها، فيُعاد النصّ الخام إلى `Model.fromJson`
  // فينفجر بـ«String is not a subtype of Map». الحمايةُ التي وُضعت لجسم
  // `null` يجب أن تشمله.
  if (data is String && data.trim().isEmpty) {
    return <String, dynamic>{};
  }

  // محاولة فك تشفير JSON
  if (data != null) {
    try {
      return data is String ? jsonDecode(data) : data;
    } on Exception catch (_) {
      return data;
    }
  }

  return <String, dynamic>{};
}

/// نسخةٌ من الاستجابة بكود 500 — لتصنيف صفحةِ HTML وصلت بكود نجاح.
///
/// نسخةٌ لا تعديلٌ في مكانه: الاستجابة يملكها المستدعي وقد يقرؤها بعد
/// التقاط الاستثناء، فلا يُغيَّر كودُها تحت يده.
Response<dynamic> _asServerError(
  Response<dynamic> response,
  RequestOptions requestOptions,
) => Response<dynamic>(
  requestOptions: requestOptions,
  statusCode: ResponseCode.internalServerError,
  statusMessage: response.statusMessage,
  data: response.data,
  headers: response.headers,
  isRedirect: response.isRedirect,
  redirects: response.redirects,
  extra: response.extra,
);

/// معالج استجابات API الصارم — خريطة JSON أو خطأٌ مفهوم.
///
/// يمرّ على [handleResponse] أوّلاً فيرث كلّ فحوصه: أكواد الحالة، وصفحات
/// HTML، والجسم الفارغ. ثمّ يفرض ما لا يفرضه: أن تكون النتيجة
/// `Map<String, dynamic>`.
///
/// **متى يُستعمل أيّهما:**
/// - [handleJsonResponse] حين تُمرَّر النتيجة إلى `Model.fromJson` — أيّ نقطة
///   نهاية عقدُها كائن JSON. فإن ردّ الخادم نصّاً (صفحة، تقرير، رسالة) جاء
///   الخطأ من هنا واضحاً بمساره ومقتطفٍ من الجسم، بدل
///   `TypeError: String is not a subtype of Map` منفجراً داخل `fromJson`.
/// - [handleResponse] حين يكون النصّ الخام مقصوداً (تقرير، رسالة، CSV، رمز
///   تحقّق) أو حين يكون جذر الجسم قائمة JSON — فهو يُعيدها كما هي.
///
/// يُعيد خريطةً فارغة للجسم الفارغ ولكود 204، كما يفعل [handleResponse]
/// تماماً — «لا محتوى» جسمٌ فارغ لا خطأ.
///
/// يرمي [DioException] من نوع [DioExceptionType.unknown] حين لا يكون الجسم
/// كائن JSON، ويرمي ما يرميه [handleResponse] في سائر الحالات.
Map<String, dynamic> handleJsonResponse(Response<dynamic> response) {
  final dynamic data = handleResponse(response);

  // 204: [handleResponse] يردّ رسالة حذفٍ نصّيةً للعرض، وعقدُ هذه الدالّة
  // خريطة. «لا محتوى» معناه جسمٌ فارغ، فيُعامَل معاملته.
  if (response.statusCode == ResponseCode.noContent) {
    return <String, dynamic>{};
  }

  if (data is Map<String, dynamic>) return data;

  // خريطةٌ بنوعٍ أعمّ (`Map<dynamic, dynamic>` من مُحوِّلٍ أو ذاكرةِ تخزينٍ
  // مثلاً): تُنسخ بنوعها الصحيح ما دامت مفاتيحها كلّها نصوصاً.
  if (data is Map && data.keys.every((dynamic key) => key is String)) {
    return Map<String, dynamic>.from(data);
  }

  throw DioException(
    requestOptions: response.requestOptions,
    response: response,
    error:
        'الاستجابة ليست كائن JSON — ${response.requestOptions.path} '
        'أعاد ${_describeNonJsonObject(data)}',
    type: DioExceptionType.unknown,
  );
}

/// وصفٌ عربيٌّ موجز لجسمٍ ليس كائن JSON — يدخل رسالة الخطأ لا شاشة المستخدم.
String _describeNonJsonObject(dynamic data) {
  if (data == null) return 'القيمة null';
  if (data is String) {
    return 'نصّاً غير قابلٍ للفكّ كـJSON: «${_excerpt(data)}»';
  }
  if (data is List) return 'قائمةً (${data.length} عنصراً) لا كائناً';
  if (data is Map) return 'خريطةً مفاتيحُها ليست كلّها نصوصاً';
  return 'قيمةً من نوع ${data.runtimeType}: «${_excerpt(data.toString())}»';
}

/// مقتطفٌ قصير من الجسم — يكفي للتشخيص ولا يُغرق السجلّ بتقريرٍ كامل.
String _excerpt(String raw) {
  final String trimmed = raw.trim();
  return trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 120)}…';
}
