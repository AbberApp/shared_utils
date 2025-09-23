class ResponseMessage {
  const ResponseMessage._();

  static const String successWithData = 'تم بنجاح مع البيانات';
  static const String successWithNoData = 'تم بنجاح بدون بيانات';
  static const String badResponse = 'طلب غير صالح';
  static const String unAuthorized = 'غير مصرح بالدخول';
  static const String forbidden = 'الحساب غير مفعل';
  static const String notFound = 'غير موجود';
  static const String conflict = 'تعارض';
  static const String internalServerError = 'خطأ داخلي في الخادم';
  static const String notImplemented = 'غير مفعل';
  static const String badGateway = 'بوابة خاطئة';
  static const String serviceUnavailable = 'الخدمة غير متاحة';
  static const String gatewayTimeout = 'انتهت مهلة البوابة';
  static const String unknown = 'غير معروف';
  static const String connectTimeout = 'انتهت مهلة الاتصال';
  static const String connectionError =
      'حدث خطأ أثناء محاولة الاتصال بالخادم. الرجاء التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى في وقت لاحق.';

  static const String cancel = 'تم الإلغاء';
  static const String receiveTimeout = 'انتهت مهلة الاستقبال';
  static const String sendTimeout = 'انتهت مهلة الإرسال';
  static const String cacheError = 'خطأ في التخزين المؤقت';
  static const String noInternetConnection = 'لا يوجد اتصال بالإنترنت';
  static const String wrongPassword = 'كلمة مرور خاطئة';

  // رسالة خطأ لخطأ غير معروف
  static const String unknownError =
      'حدث خطأ غير معروف. يرجى المحاولة مرة أخرى.';

  static const String socketException =
      'حدث خطأ في الاتصال بالخادم. الرجاء التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.';

  static const String sellerAccountNotFound =
      'لا يمكن تسجيل الدخول لحساب المعبر';
}
