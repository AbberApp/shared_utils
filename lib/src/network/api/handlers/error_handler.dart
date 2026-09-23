import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/failure.dart';
import '../models/response_code.dart';
import '../models/response_message.dart';

/// أنواع الأخطاء المحتملة
enum ErrorType {
  success,
  successNoContent,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  internalServerError,
  notImplemented,
  badGateway,
  serviceUnavailable,
  gatewayTimeout,
  connectionError,
  connectTimeout,
  receiveTimeout,
  sendTimeout,
  cancelled,
  cacheError,
  noInternetConnection,
  socketException,
  wrongPassword,
  sellerAccountNotFound,
  unknown,
}

/// Extension لتحويل ErrorType إلى Failure
extension ErrorTypeExtension on ErrorType {
  Failure toFailure() {
    switch (this) {
      case ErrorType.success:
        return Failure(code: ResponseCode.success, message: ResponseMessage.success);
      case ErrorType.successNoContent:
        return Failure(code: ResponseCode.noContent, message: ResponseMessage.successNoContent);
      case ErrorType.badRequest:
        return Failure(code: ResponseCode.badRequest, message: ResponseMessage.badRequest);
      case ErrorType.unauthorized:
        return Failure(code: ResponseCode.unauthorized, message: ResponseMessage.unauthorized);
      case ErrorType.forbidden:
        return Failure(code: ResponseCode.forbidden, message: ResponseMessage.forbidden);
      case ErrorType.notFound:
        return Failure(code: ResponseCode.notFound, message: ResponseMessage.notFound);
      case ErrorType.conflict:
        return Failure(code: ResponseCode.conflict, message: ResponseMessage.conflict);
      case ErrorType.internalServerError:
        return Failure(code: ResponseCode.internalServerError, message: ResponseMessage.internalServerError);
      case ErrorType.notImplemented:
        return Failure(code: ResponseCode.notImplemented, message: ResponseMessage.notImplemented);
      case ErrorType.badGateway:
        return Failure(code: ResponseCode.badGateway, message: ResponseMessage.badGateway);
      case ErrorType.serviceUnavailable:
        return Failure(code: ResponseCode.serviceUnavailable, message: ResponseMessage.serviceUnavailable);
      case ErrorType.gatewayTimeout:
        return Failure(code: ResponseCode.gatewayTimeout, message: ResponseMessage.gatewayTimeout);
      case ErrorType.connectionError:
        // عطلُ شبكةٍ لا عطلُ خادم: الاتصال لم يُنشأ أصلاً. كان الكود 504
        // فيُصنَّف عند المستدعي كعطل خادم، فتفوته شاشة «لا يوجد اتصال»
        // وسياسة إعادة المحاولة. الرسالة تبقى كما هي لأنّها أدقّ وصفاً.
        return Failure(code: ResponseCode.noInternetConnection, message: ResponseMessage.connectionError);
      case ErrorType.connectTimeout:
        return Failure(code: ResponseCode.connectTimeout, message: ResponseMessage.connectTimeout);
      case ErrorType.receiveTimeout:
        return Failure(code: ResponseCode.receiveTimeout, message: ResponseMessage.receiveTimeout);
      case ErrorType.sendTimeout:
        return Failure(code: ResponseCode.sendTimeout, message: ResponseMessage.sendTimeout);
      case ErrorType.cancelled:
        return Failure(code: ResponseCode.cancel, message: ResponseMessage.cancelled);
      case ErrorType.cacheError:
        return Failure(code: ResponseCode.cacheError, message: ResponseMessage.cacheError);
      case ErrorType.noInternetConnection:
        return Failure(code: ResponseCode.noInternetConnection, message: ResponseMessage.noInternetConnection);
      case ErrorType.socketException:
        return Failure(code: ResponseCode.socketException, message: ResponseMessage.socketException);
      case ErrorType.wrongPassword:
        return Failure(code: ResponseCode.wrongPassword, message: ResponseMessage.wrongPassword);
      case ErrorType.sellerAccountNotFound:
        return Failure(code: ResponseCode.sellerAccountNotFound, message: ResponseMessage.sellerAccountNotFound);
      case ErrorType.unknown:
        return Failure(code: ResponseCode.unknown, message: ResponseMessage.unknown);
    }
  }
}

/// معالج الأخطاء الرئيسي
class ErrorHandler implements Exception {
  late final Failure failure;

  ErrorHandler.handle(dynamic error) {
    if (error is DioException) {
      failure = _handleDioError(error);
    } else if (error is SocketException) {
      failure = ErrorType.socketException.toFailure();
    } else {
      failure = _handleUnknownError(error);
    }
  }

  Failure _handleDioError(DioException error) {
    // محاولة استخراج الرسالة من الاستجابة
    final responseData = error.response?.data;
    final statusCode = error.response?.statusCode ?? 0;

    // 429 — تجاوز حد المعدّل: رسالة عربية + Retry-After بغضّ النظر عن شكل الجسم.
    if (statusCode == ResponseCode.tooManyRequests) {
      final int? retryAfter = _parseRetryAfter(error.response);
      return Failure(
        code: ResponseCode.tooManyRequests,
        message: retryAfter != null
            ? ResponseMessage.tooManyRequestsAfter(retryAfter)
            : ResponseMessage.tooManyRequests,
        retryAfter: retryAfter,
      );
    }

    if (responseData != null) {
      // `DioConsumer` يفرض `ResponseType.plain`، فجسم كلّ استجابةٍ يصل **نصّاً**
      // لا خريطة. وفحصُ `responseData is Map<String, dynamic>` وحده كان يجعل
      // هذا الفرع ميّتاً في الواقع، فتضيع رسالة الخادم في 401 و404 خاصّةً:
      // `_handleBadResponse` يردّ لهما رسالةً معلّبة لا تقرأ الجسم أصلاً.
      // `_parseResponseData` تفكّ النصّ إلى خريطة وتُعيد `{}` عند الفشل،
      // فتشمل الشكلين معاً.
      final Map<String, dynamic> parsed = _parseResponseData(responseData);
      if (parsed.isNotEmpty) {
        final Failure failure = Failure.fromJson(statusCode, parsed);
        // لا تُصادَر الرسالة المعلّبة إلّا حين يحمل الجسم رسالةً أو أخطاء حقول:
        // جسمٌ كـ `{"code":"E_LIMIT"}` لا يفيد المستخدم بشيء، فالأولى أن يهبط
        // إلى الـ switch لتصله رسالة حالته العامّة.
        if (failure.message != null || failure.hasFields) return failure;
      }
    }

    // تغطيةٌ شاملة بلا `default` مقصودة: `default` كان يبتلع كلّ نوعٍ تضيفه dio
    // لاحقاً فيسقط صامتاً في «خطأ غير متوقع» — ومنه `transformTimeout`. بحذفه
    // يوقف المحلّل أيّ نوعٍ جديد هنا فيُترجَم عمداً لا سهواً.
    switch (error.type) {
      case DioExceptionType.badCertificate:
        // شهادةُ TLS فاسدة عطلُ اتصالٍ لا حالةُ حساب. رسالة `ErrorType.forbidden`
        // «الحساب غير مُفعّل» تُعرض للمستخدم كما هي في `showToast` فتتّهم حسابه
        // بما ليس فيه. الكود يبقى 403 كما يعتمده المستهلكون، والرسالة وحدها
        // تُصحَّح إلى تعذُّر الاتصال بالخادم.
        return const Failure(
          code: ResponseCode.forbidden,
          message: ResponseMessage.connectionError,
        );
      case DioExceptionType.connectionTimeout:
        return ErrorType.connectTimeout.toFailure();
      case DioExceptionType.connectionError:
        return ErrorType.connectionError.toFailure();
      case DioExceptionType.receiveTimeout:
        return ErrorType.receiveTimeout.toFailure();
      case DioExceptionType.sendTimeout:
        return ErrorType.sendTimeout.toFailure();
      case DioExceptionType.cancel:
        return ErrorType.cancelled.toFailure();
      case DioExceptionType.badResponse:
        return _handleBadResponse(error);
      case DioExceptionType.transformTimeout:
        // نوعٌ أضافته dio 5.x: انتهت مهلة تحويل الجسم بعد وصوله كاملاً — أقرب
        // ترجمةٍ صحيحة له مهلةُ الاستلام لا «خطأ غير متوقع».
        return ErrorType.receiveTimeout.toFailure();
      case DioExceptionType.unknown:
        return ErrorType.unknown.toFailure();
    }
  }

  Failure _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode == ResponseCode.notFound) {
      return ErrorType.notFound.toFailure();
    }
    if (statusCode == ResponseCode.unauthorized) {
      return ErrorType.unauthorized.toFailure();
    }
    if (ResponseCode.isClientError(statusCode ?? 0)) {
      final Failure failure = Failure.fromJson(
        statusCode ?? 0,
        _parseResponseData(error.response?.data),
      );
      if (failure.message != null || failure.hasFields) return failure;
      // لا جسم أصلاً: `Failure.fromJson` تردّ رسالةً null فيعرض المستدعي «حدث
      // خطأ غير متوقع»، ورسائل 400 و403 و409 العربية لا تُستعمل أبداً. حالة
      // الاستجابة وحدها أفصح من الرسالة الاحتياطية، فتُستعمل رسالتها المعلّبة.
      // أمّا جسمٌ حاضرٌ بلا رسالةٍ مفهومة فيبقى بلا رسالة كما هو موثّق: الخادم
      // قال شيئاً لم نفهمه، فلا نضع في فمه ما لم يقله.
      if (error.response?.data == null) {
        return Failure(
          code: statusCode ?? 0,
          message: _clientErrorMessage(statusCode ?? 0),
        );
      }
      return failure;
    }
    if (ResponseCode.isServerError(statusCode ?? 0)) {
      return ErrorType.internalServerError.toFailure();
    }
    return ErrorType.badRequest.toFailure();
  }

  /// الرسالة المعلّبة لحالة 4xx حين لا جسم يُقرأ. (404 و401 و429 لا تصل هنا:
  /// لكلٍّ منها فرعُه قبلها.)
  String _clientErrorMessage(int statusCode) {
    switch (statusCode) {
      case ResponseCode.forbidden:
        return ResponseMessage.forbidden;
      case ResponseCode.conflict:
        return ResponseMessage.conflict;
      default:
        // 400 و402 و405 و422 وسائر ما لا رسالة خاصّة له.
        return ResponseMessage.badRequest;
    }
  }

  int? _parseRetryAfter(Response? response) {
    // headers.value() يرمي عند تكرار الترويسة — نقرأ القائمة مباشرةً
    try {
      final List<String>? all = response?.headers['retry-after'];
      if (all == null || all.isEmpty) return null;
      final String raw = all.first.trim();
      final int? seconds = int.tryParse(raw);
      // RFC 7231 يحدّ delay-seconds بعددٍ صحيح غير سالب، فـ«5-» قيمةٌ مشوّهة لا
      // انتظارٌ سالب: تمريرها يبني رسالة «يُرجى المحاولة بعد -5 ثانية» ويقلب أيّ
      // عدّادٍ تنازليّ عند المستدعي. تُعامَل معاملة النصّ غير الرقميّ.
      if (seconds != null) return seconds < 0 ? null : seconds;
      // RFC 7231 يجيز لـ Retry-After صيغتين: عددَ ثوانٍ **أو** تاريخ HTTP،
      // وnginx وCloudflare وبوّابات API كثيرة تُرسل الثانية. بلا هذا المسار
      // كان التاريخ يُعدّ قيمةً مشوّهة فيضيع زمن الانتظار الذي أرسله الخادم،
      // ولا تستطيع الواجهة عرض عدّادٍ تنازليّ ولا جدولة إعادة المحاولة.
      // HttpDate.parse يرمي FormatException على ما ليس تاريخاً — تلتقطه try.
      final DateTime until = HttpDate.parse(raw);
      final int diff = until.difference(DateTime.now()).inSeconds;
      // تاريخٌ مضى معناه «أعد المحاولة الآن» لا انتظارٌ سالب.
      return diff > 0 ? diff : 0;
    } on Object catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _parseResponseData(dynamic data) {
    try {
      if (data is String) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {};
    } on Object catch (_) {
      return {};
    }
  }

  /// نصّ الاستثناء الخام لا يصل إلى المستخدم.
  ///
  /// `Failure.displayMessage` يُعرض مباشرةً في `showToast`، ونصّ الاستثناء
  /// إنجليزيٌّ تقنيّ («type 'String' is not a subtype of…») لا يفهمه المستخدم
  /// العربي وقد يكشف تفاصيل داخلية. فالرسالة موحّدة عربية، والنصّ الخام يبقى
  /// في سجلّ التشخيص وحده.
  Failure _handleUnknownError(dynamic error) {
    if (error != null) {
      log('خطأ غير متوقّع', error: error, name: 'ErrorHandler');
    }
    return ErrorType.unknown.toFailure();
  }
}
