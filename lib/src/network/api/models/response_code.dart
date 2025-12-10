/// أكواد استجابة HTTP والأخطاء المخصصة
class ResponseCode {
  const ResponseCode._();

  // Success codes (2xx)
  static const int success = 200;
  static const int created = 201;
  static const int noContent = 204;

  // Client error codes (4xx)
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;

  // Server error codes (5xx)
  static const int internalServerError = 500;
  static const int notImplemented = 501;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeout = 504;

  // Custom error codes
  static const int unknown = 301;
  static const int connectTimeout = -11;
  static const int cancel = -12;
  static const int receiveTimeout = -13;
  static const int sendTimeout = -14;
  static const int cacheError = -15;
  static const int noInternetConnection = 0;
  static const int wrongPassword = -17;
  static const int socketException = -1;
  static const int sellerAccountNotFound = -18;

  /// التحقق من نجاح الاستجابة
  static bool isSuccessful(int code) => code >= 200 && code < 300;

  /// التحقق من خطأ العميل
  static bool isClientError(int code) => code >= 400 && code < 500;

  /// التحقق من خطأ الخادم
  static bool isServerError(int code) => code >= 500 && code < 600;

  /// التحقق من استجابة HTML خاطئة
  static bool isBadHtmlResponse(String data) {
    return data.contains('<!DOCTYPE html><html lang="en" dir="rtl"><head><title>خطأ');
  }
}
