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
  static const int tooManyRequests = 429;

  // Server error codes (5xx)
  static const int internalServerError = 500;
  static const int notImplemented = 501;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;
  static const int gatewayTimeout = 504;

  // Custom error codes — كلّها خارج مجال HTTP (‎≤ 0) كي لا تلتبس بكودٍ حقيقيّ
  /// خطأ غير معروف. كانت 301 فتلتبس بـ HTTP 301 (Moved Permanently):
  /// `Failure(code: 301)` لا يُميَّز أهو خطؤنا أم إعادة توجيهٍ من الخادم.
  static const int unknown = -19;
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

  /// التحقق من تجاوز حد المعدّل (throttling)
  static bool isTooManyRequests(int code) => code == tooManyRequests;

  /// التحقق من خطأ الخادم
  static bool isServerError(int code) => code >= 500 && code < 600;

  /// بادئتا وثيقة HTML. صفحات nginx و502 من الوسطاء تبدأ بـ`<html>` بلا
  /// DOCTYPE، وكان الاكتفاء بالأولى يجعلها تعبر إلى `Model.fromJson` فتنفجر
  /// هناك بـ«String is not a subtype of Map» بلا دلالةٍ على السبب.
  static const List<String> _htmlPrefixes = <String>['<!doctype html', '<html'];

  /// التحقق من أنّ جسم الاستجابة وثيقةُ HTML لا بيانات
  ///
  /// السؤال المطروح: «هل **يبدأ** الجسم بوثيقة HTML؟» لا «هل يذكرها في
  /// موضعٍ ما؟». والفرق ليس تجميلاً: البحث في أيّ موضع يتّهم جسم JSON
  /// سليماً يقتبس صفحة الخطأ في إحدى قيمه، فيُرمى 500 مكان رسالة الخادم
  /// الحقيقية ويضيع سببُ الرفض على المستخدم.
  ///
  /// ويُشذَّب الفراغ البادئ أوّلاً — خوادم كثيرة تسبق الوثيقة بسطرٍ فارغ —
  /// وتُقارَن البادئة بلا حساسيةٍ لحالة الأحرف، فـ`<!doctype html>` و
  /// `<!DOCTYPE html>` سواءٌ في HTML.
  ///
  /// حدُّها المعروف: صفحةٌ تبدأ بـ`<html>` بلا `<!DOCTYPE>` — صفحاتُ nginx
  /// لـ502 و504 مثلاً — لا تُكتشف هنا.
  static bool isBadHtmlResponse(String data) {
    final String head = data.trimLeft();
    if (head.isEmpty) return false;
    // المقارنة على بادئةٍ بطول القالب وحدها: صفحة الخطأ قد تبلغ مئات آلاف
    // المحارف، ولا داعي لنسخها كلّها بـ`toLowerCase`.
    for (final String prefix in _htmlPrefixes) {
      if (head.length < prefix.length) continue;
      if (head.substring(0, prefix.length).toLowerCase() == prefix) return true;
    }
    return false;
  }
}
