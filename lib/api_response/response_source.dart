import 'dart:convert';
import 'dart:developer';
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
  Failure getFailure() {
    // استخدام الـ switch لإرجاع فشل (Failure) المناسب بناءً على النوع (ErrorSource)
    switch (this) {
      case ErrorSource.sellerAccountNotFound:
        return Failure(
          ResponseCode.sellerAccountNotFound,
          ResponseMessage.sellerAccountNotFound,
        );
      case ErrorSource.successWithData:
        return Failure(
          ResponseCode.successWithData,
          ResponseMessage.successWithData,
        );
      case ErrorSource.successWithNoData:
        return Failure(
          ResponseCode.successWithNoData,
          ResponseMessage.successWithNoData,
        );
      case ErrorSource.badResponse:
        return Failure(ResponseCode.badRequest, ResponseMessage.badResponse);
      case ErrorSource.unauthorized:
        return Failure(ResponseCode.unAuthorized, ResponseMessage.unAuthorized);
      case ErrorSource.forbidden:
        return Failure(ResponseCode.forbidden, ResponseMessage.forbidden);
      case ErrorSource.notFound:
        return Failure(ResponseCode.notFound, ResponseMessage.notFound);
      case ErrorSource.conflict:
        return Failure(ResponseCode.conflict, ResponseMessage.conflict);
      case ErrorSource.internalServerError:
        return Failure(
          ResponseCode.internalServerError,
          ResponseMessage.internalServerError,
        );
      case ErrorSource.notImplemented:
        return Failure(
          ResponseCode.notImplemented,
          ResponseMessage.notImplemented,
        );
      case ErrorSource.badGateway:
        return Failure(ResponseCode.badGateway, ResponseMessage.badGateway);
      case ErrorSource.serviceUnavailable:
        return Failure(
          ResponseCode.serviceUnavailable,
          ResponseMessage.serviceUnavailable,
        );
      case ErrorSource.connectionError:
        return Failure(
          ResponseCode.gatewayTimeout,
          ResponseMessage.connectionError,
        );
      case ErrorSource.gatewayTimeout:
        return Failure(
          ResponseCode.gatewayTimeout,
          ResponseMessage.gatewayTimeout,
        );
      case ErrorSource.unknown:
        return Failure(ResponseCode.unknown, ResponseMessage.unknownError);
      case ErrorSource.connectTimeout:
        return Failure(
          ResponseCode.connectTimeout,
          ResponseMessage.connectTimeout,
        );
      case ErrorSource.cancel:
        return Failure(ResponseCode.cancel, ResponseMessage.cancel);
      case ErrorSource.receiveTimeout:
        return Failure(
          ResponseCode.receiveTimeout,
          ResponseMessage.receiveTimeout,
        );
      case ErrorSource.sendTimeout:
        return Failure(ResponseCode.sendTimeout, ResponseMessage.sendTimeout);
      case ErrorSource.cacheError:
        return Failure(ResponseCode.cacheError, ResponseMessage.cacheError);
      case ErrorSource.noInternetConnection:
        return Failure(
          ResponseCode.noInternetConnection,
          ResponseMessage.noInternetConnection,
        );
      case ErrorSource.wrongPassword:
        return Failure(
          ResponseCode.wrongPassword,
          ResponseMessage.wrongPassword,
        );
      // أضف الحالة للاستثناء SocketException هنا
      case ErrorSource.socketException:
        return Failure(
          ResponseCode.socketException, // اختر رمز استجابة مناسب
          ResponseMessage.socketException, // اختر رسالة خطأ مناسبة
        );
    }
  }
}

// معالج الأخطاء
class ErrorHandler implements Exception {
  late final Failure failure;

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

  Failure _handleDioError(DioException error) {
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
        return Failure(
          error.response?.statusCode ?? 0,
          extractTextFromData(error.response?.statusCode ?? 0, error.response?.data),
          data: extractKeys(error.response?.data),
          extraData: extraData(error.response?.data.toString() ?? ''),
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

  Failure _handleSocketError(SocketException error) {
    return ErrorSource.socketException.getFailure();
  }

  Failure _handleUnknownError(dynamic error) {
    if (error != null) {
      return Failure(
        ResponseCode.unknown,
        error.toString().replaceAll('Exception:', ''),
      );
    }
    return ErrorSource.unknown.getFailure();
  }
}

List<Map<String, dynamic>> extractKeys(String data) {
  try {
    final dynamic jsonData = jsonDecode(data);
    final List<Map<String, dynamic>> extractedKeys = [];

    void extractData(dynamic value) {
      if (value is Map<String, dynamic>) {
        value.forEach((key, value) {
          if (key != 'message') {
            extractedKeys.add({key: value});
            extractData(value);
          }
        });
      } else if (value is List<dynamic>) {
        for (var item in value) {
          extractData(item);
        }
      }
    }

    extractData(jsonData);
    return extractedKeys;
  } catch (e) {
    // يمكنك تخصيص معالجة الخطأ هنا
    log('حدث خطأ أثناء معالجة البيانات: $e');
    return []; // إرجاع قائمة فارغة في حالة حدوث خطأ
  }
}

String extractTextFromData(int statsCode, String data) {
  if (statsCode >= 500) {
    return 'حدث خطا غير متوقع. حاول لاحقاً';
  }

  try {
    final dynamic jsonData = jsonDecode(data);
    final List<String> extractedText = [];

    void extractData(dynamic value) {
      if (value is Map<String, dynamic>) {
        value.forEach((key, value) {
          extractData(value);
        });
      } else if (value is List<dynamic>) {
        for (var item in value) {
          extractData(item);
        }
      } else if (value is String) {
        extractedText.add(value.toString());
      }
    }

    extractData(jsonData);

    return extractedText.join('\n');
  } catch (e) {
    return 'حدث خطأ غير متوقع في تنسيق البيانات';
  }
}
