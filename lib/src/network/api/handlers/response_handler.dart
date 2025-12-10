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
    } else if (ResponseCode.isClientError(statusCode)) {
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        error: data ?? 'حدث خطأ غير متوقع',
        type: _getDioExceptionType(statusCode),
      );
    } else if (ResponseCode.isServerError(statusCode)) {
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
  } catch (e) {
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
  Response response,
  RequestOptions requestOptions,
) {
  // التحقق من استجابة HTML خاطئة
  if (data != null && ResponseCode.isBadHtmlResponse(data.toString())) {
    throw DioException.badResponse(
      statusCode: 500,
      requestOptions: requestOptions,
      response: response,
    );
  }

  // استجابة حذف ناجحة
  if (statusCode == ResponseCode.noContent) {
    return 'تمت عملية الحذف بنجاح';
  }

  // محاولة فك تشفير JSON
  if (data != null) {
    try {
      return data is String ? jsonDecode(data) : data;
    } catch (_) {
      return data;
    }
  }

  return {};
}

DioExceptionType _getDioExceptionType(int statusCode) {
  switch (statusCode) {
    case ResponseCode.badRequest:
    case ResponseCode.notFound:
    case ResponseCode.conflict:
      return DioExceptionType.badResponse;
    case ResponseCode.unauthorized:
    case ResponseCode.forbidden:
      return DioExceptionType.badCertificate;
    default:
      return DioExceptionType.unknown;
  }
}
