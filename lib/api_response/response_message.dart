class ResponseMessage {
  const ResponseMessage._();

  static const String successWithData =
      'تم تنفيذ العملية بنجاح وتم إرفاق البيانات اللازمة.';
  static const String successWithNoData =
      'تم تنفيذ العملية بنجاح، دون وجود بيانات إضافية.';
  static const String badResponse =
      'الطلب غير صالح. يُرجى التحقق من صحة البيانات المُدخلة.';
  static const String unAuthorized =
      'غير مصرح لك بالوصول. يُرجى تسجيل الدخول أولاً.';
  static const String forbidden =
      'لا يمكن تنفيذ الطلب، الحساب غير مُفعّل.';
  static const String notFound =
      'عذراً، لم نتمكن من العثور على العنصر المطلوب.';
  static const String conflict =
      'لا يمكن إتمام العملية بسبب وجود تعارض.';
  static const String internalServerError =
      'حدث خطأ داخلي في الخادم. يُرجى المحاولة لاحقاً.';
  static const String notImplemented =
      'هذه الوظيفة غير متاحة حالياً.';
  static const String badGateway =
      'استجابة غير صحيحة من الخادم.';
  static const String serviceUnavailable =
      'الخدمة غير متاحة في الوقت الحالي. يُرجى المحاولة لاحقاً.';
  static const String gatewayTimeout =
      'انتهت مهلة الاستجابة من الخادم.';
  static const String unknown =
      'حدث خطأ غير متوقع.';
  static const String connectTimeout =
      'انتهت مهلة الاتصال بالخادم.';
  static const String connectionError =
      'تعذّر الاتصال بالخادم. يُرجى التحقق من اتصالك بالإنترنت والمحاولة لاحقاً.';
  static const String cancel =
      'تم إلغاء العملية.';
  static const String receiveTimeout =
      'انتهت مهلة استلام البيانات.';
  static const String sendTimeout =
      'انتهت مهلة إرسال البيانات.';
  static const String cacheError =
      'حدث خطأ أثناء الوصول إلى البيانات المخزّنة.';
  static const String noInternetConnection =
      'لا يوجد اتصال بالإنترنت. يُرجى التحقق من الشبكة.';
  static const String wrongPassword =
      'كلمة المرور غير صحيحة.';
  static const String unknownError =
      'حدث خطأ غير معروف. يُرجى المحاولة مرة أخرى.';
  static const String socketException =
      'حدث خلل في الاتصال بالخادم. يُرجى التحقق من الاتصال بالإنترنت والمحاولة لاحقاً.';
  static const String sellerAccountNotFound =
      'لا يمكن تسجيل الدخول إلى حساب المُعَبِّر.';
}
