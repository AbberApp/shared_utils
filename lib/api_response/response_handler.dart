import 'dart:convert';
import 'package:dio/dio.dart';

import 'response_code.dart';

dynamic responseHandler(Response<dynamic> response) {
  try {
    final int statusCode = response.statusCode ?? 500;
    final dynamic data = response.data;
    final RequestOptions requestOptions = response.requestOptions;

    if (ResponseCode.isSuccessful(statusCode)) {
      if (data != null && ResponseCode.isBadResponseError(data.toString())) {
        throw DioException.badResponse(
          statusCode: 500,
          requestOptions: requestOptions,
          response: response,
        );
      }
      if (statusCode == ResponseCode.successWithNoData) {
        return 'تمت عملية الحذف بنجاح';
      } else if (data != null) {
        try {
          final dataDecoded = jsonDecode(data);
         
          return dataDecoded;
        } catch (e) {
          return data;
        }
      } else {
        return {};
      }
    } else if (ResponseCode.isClientError(statusCode)) {
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        error: data ?? 'حدث خطأ غير متوقع',
        type: getDioExceptionType(statusCode),
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

DioExceptionType getDioExceptionType(int statusCode) {
  switch (statusCode) {
    case ResponseCode.badRequest:
      return DioExceptionType.badResponse;
    case ResponseCode.unAuthorized:
      return DioExceptionType.badCertificate;
    case ResponseCode.forbidden:
      return DioExceptionType.badCertificate;
    case ResponseCode.notFound:
      return DioExceptionType.badResponse;
    case ResponseCode.conflict:
      return DioExceptionType.badResponse;
    default:
      return DioExceptionType.unknown;
  }
}
