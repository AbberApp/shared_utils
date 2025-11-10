import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import 'failure.dart';
import 'response_code.dart';
import 'response_message.dart';

// تعريف مجموعة الأخطاء الممكنة
enum ErrorSource {
  // قائمة بجميع أنواع الأخطاء المحتملة
  successWithData,
  successWithNoData,
  badResponse,
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
  unknown,
  connectTimeout,
  cancel,
  receiveTimeout,
  sendTimeout,
  cacheError,
  noInternetConnection,
  wrongPassword,
  socketException,
  sellerAccountNotFound,
}

// امتداد يضمن توفير فشل (Failure) مناسب لكل نوع من ErrorSource
extension DataSourceExtension on ErrorSource {
  NewFailure getFailure() {
    // استخدام الـ switch لإرجاع فشل (Failure) المناسب بناءً على النوع (ErrorSource)
    switch (this) {
      case ErrorSource.sellerAccountNotFound:
        return NewFailure(
          code: ResponseCode.sellerAccountNotFound,
          message: ResponseMessage.sellerAccountNotFound,
        );
      case ErrorSource.successWithData:
        return NewFailure(
          code: ResponseCode.successWithData,
          message: ResponseMessage.successWithData,
        );
      case ErrorSource.successWithNoData:
        return NewFailure(
          code: ResponseCode.successWithNoData,
          message: ResponseMessage.successWithNoData,
        );
      case ErrorSource.badResponse:
        return NewFailure(
          code: ResponseCode.badRequest,
          message: ResponseMessage.badResponse,
        );
      case ErrorSource.unauthorized:
        return NewFailure(
          code: ResponseCode.unAuthorized,
          message: ResponseMessage.unAuthorized,
        );
      case ErrorSource.forbidden:
        return NewFailure(
          code: ResponseCode.forbidden,
          message: ResponseMessage.forbidden,
        );
      case ErrorSource.notFound:
        return NewFailure(
          code: ResponseCode.notFound,
          message: ResponseMessage.notFound,
        );
      case ErrorSource.conflict:
        return NewFailure(
          code: ResponseCode.conflict,
          message: ResponseMessage.conflict,
        );
      case ErrorSource.internalServerError:
        return NewFailure(
          code: ResponseCode.internalServerError,
          message: ResponseMessage.internalServerError,
        );
      case ErrorSource.notImplemented:
        return NewFailure(
          code: ResponseCode.notImplemented,
          message: ResponseMessage.notImplemented,
        );
      case ErrorSource.badGateway:
        return NewFailure(
          code: ResponseCode.badGateway,
          message: ResponseMessage.badGateway,
        );
      case ErrorSource.serviceUnavailable:
        return NewFailure(
          code: ResponseCode.serviceUnavailable,
          message: ResponseMessage.serviceUnavailable,
        );
      case ErrorSource.connectionError:
        return NewFailure(
          code: ResponseCode.gatewayTimeout,
          message: ResponseMessage.connectionError,
        );
      case ErrorSource.gatewayTimeout:
        return NewFailure(
          code: ResponseCode.gatewayTimeout,
          message: ResponseMessage.gatewayTimeout,
        );
      case ErrorSource.unknown:
        return NewFailure(
          code: ResponseCode.unknown,
          message: ResponseMessage.unknownError,
        );
      case ErrorSource.connectTimeout:
        return NewFailure(
          code: ResponseCode.connectTimeout,
          message: ResponseMessage.connectTimeout,
        );
      case ErrorSource.cancel:
        return NewFailure(
          code: ResponseCode.cancel,
          message: ResponseMessage.cancel,
        );
      case ErrorSource.receiveTimeout:
        return NewFailure(
          code: ResponseCode.receiveTimeout,
          message: ResponseMessage.receiveTimeout,
        );
      case ErrorSource.sendTimeout:
        return NewFailure(
          code: ResponseCode.sendTimeout,
          message: ResponseMessage.sendTimeout,
        );
      case ErrorSource.cacheError:
        return NewFailure(
          code: ResponseCode.cacheError,
          message: ResponseMessage.cacheError,
        );
      case ErrorSource.noInternetConnection:
        return NewFailure(
          code: ResponseCode.noInternetConnection,
          message: ResponseMessage.noInternetConnection,
        );
      case ErrorSource.wrongPassword:
        return NewFailure(
          code: ResponseCode.wrongPassword,
          message: ResponseMessage.wrongPassword,
        );
      // أضف الحالة للاستثناء SocketException هنا
      case ErrorSource.socketException:
        return NewFailure(
          code: ResponseCode.socketException, // اختر رمز استجابة مناسب
          message: ResponseMessage.socketException, // اختر رسالة خطأ مناسبة
        );
    }
  }
}

// معالج الأخطاء
class ErrorHandler implements Exception {
  late final NewFailure failure;

  ErrorHandler();

  ErrorHandler.handle(dynamic error) {
    if (error is DioException) {
      failure = _handleDioError(error);
    } else if (error is SocketException) {
      // أضف هذا الجزء لمعالجة استثناء SocketException
      failure = _handleSocketError(error);
    } else {
      failure = _handleUnknownError(error);
    }
  }

  NewFailure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return ErrorSource.forbidden.getFailure();
      case DioExceptionType.connectionTimeout:
        return ErrorSource.connectTimeout.getFailure();
      case DioExceptionType.connectionError:
        return ErrorSource.connectionError.getFailure();
      case DioExceptionType.receiveTimeout:
        return ErrorSource.receiveTimeout.getFailure();
      case DioExceptionType.sendTimeout:
        return ErrorSource.sendTimeout.getFailure();
      case DioExceptionType.cancel:
        return ErrorSource.cancel.getFailure();
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == ResponseCode.notFound) {
          return ErrorSource.notFound.getFailure();
        }
        if (error.response?.statusCode == ResponseCode.unAuthorized) {
          return ErrorSource.unauthorized.getFailure();
        }
        if (ResponseCode.isClientError(error.response?.statusCode ?? 0)) {
          return NewFailure(
            code: error.response?.statusCode ?? 0,
            message: extraData(error.response?.data)['message'],
            fields:
                (extraData(error.response?.data['errors']) as List<dynamic>?)
                    ?.map(
                      (e) => FieldFailure.fromJson(e as Map<String, dynamic>),
                    )
                    .toList() ??
                [],
          );
        }
        return NewFailure(
          code: error.response?.statusCode ?? 0,
          message: extraData(error.response?.data)['message'],
        );
      default:
        return ErrorSource.unknown.getFailure();
    }
  }

  Map<String, dynamic> extraData(String data) {
    try {
      final Map<String, dynamic> extraData = jsonDecode(data);

      return extraData;
    } catch (e) {
      return {};
    }
  }

  NewFailure _handleSocketError(SocketException error) {
    return ErrorSource.socketException.getFailure();
  }

  NewFailure _handleUnknownError(dynamic error) {
    if (error != null) {
      return NewFailure(
        code: ResponseCode.unknown,
        message: error.toString().replaceAll('Exception:', ''),
      );
    }
    return ErrorSource.unknown.getFailure();
  }
}
