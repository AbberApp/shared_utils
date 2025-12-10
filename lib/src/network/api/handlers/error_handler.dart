import 'dart:convert';
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
        return Failure(code: ResponseCode.gatewayTimeout, message: ResponseMessage.connectionError);
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
    if (error.response?.data?.toString().contains('message') == true) {
      return Failure.fromJson(
        error.response?.statusCode ?? 0,
        _parseResponseData(error.response?.data),
      );
    }

    switch (error.type) {
      case DioExceptionType.badCertificate:
        return ErrorType.forbidden.toFailure();
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
      default:
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
      return Failure.fromJson(
        statusCode ?? 0,
        _parseResponseData(error.response?.data),
      );
    }
    return ErrorType.badRequest.toFailure();
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
    } catch (_) {
      return {};
    }
  }

  Failure _handleUnknownError(dynamic error) {
    if (error != null) {
      return Failure(
        code: ResponseCode.unknown,
        message: error.toString().replaceAll('Exception:', ''),
      );
    }
    return ErrorType.unknown.toFailure();
  }
}
