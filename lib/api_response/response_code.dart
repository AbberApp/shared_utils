class ResponseCode {
  ResponseCode._();

  static const int successWithData = 200;
  static const int created = 201;
  static const int successWithNoData = 204;

  static const int badRequest = 400;
  static const int unAuthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;

  static const int internalServerError = 500;
  static const int notImplemented = 501;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeout = 504;

  static const int unknown = 301;

  static const int connectTimeout = -11;
  static const int cancel = -12;
  static const int receiveTimeout = -13;
  static const int sendTimeout = -14;
  static const int cacheError = -15;
  static const int noInternetConnection = 0;
  static const int wrongPassword = -17;

  static const int socketException = -1;

  static int sellerAccountNotFound = -18;

  /// التحقق من نجاح الاستجابة
  static bool isSuccessful(int code) {
    return code >= 200 && code < 300;
  }

  /// التحقق من خطأ العميل
  static bool isClientError(int code) {
    return code >= 400 && code < 500;
  }

  /// التحقق من خطأ الخادم
  static bool isServerError(int code) {
    return code >= 500 && code < 600;
  }

  static bool isBadResponseError(String data) {
    if (data.toString().contains(
      '<!DOCTYPE html><html lang="en" dir="rtl"><head><title>خطأ',
    )) {
      return true;
    }
    return false;
  }
}
