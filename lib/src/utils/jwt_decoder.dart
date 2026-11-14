import 'dart:convert';

/// يقرأ حمولة رمز JWT وتواريخه — بلا تحقّقٍ من التوقيع.
///
/// بديلٌ محلّيّ لحزمة `jwt_decoder` 2.0.1: ستّةٌ وثمانون سطراً بلا تبعية، لم
/// تُحدَّث منذ خمس سنوات، وقيدُها `sdk: <3.0.0` يستثني Dart 3 على الورق فلا
/// تعمل إلّا بتسامح `pub` مع الحزم القديمة. ولم تستعمل التطبيقات منها إلّا
/// [isExpired].
///
/// **التواقيع مطابقةٌ للحزمة** — الاسم نفسه والدوالّ الساكنة الستّ بأنواعها —
/// فلا يُمسّ سطرٌ في التطبيقات.
///
/// **والفارق مقصودٌ في [isExpired] وحدها:** كانت **ترمي** على رمزٍ معطوب
/// (`FormatException`) أو بلا `exp` (`NoSuchMethodError` — وهو `Error` لا
/// `Exception`، فلا يلتقطه `on Exception`). وتُستدعى في `onRequest` للمعترِض
/// على كلّ طلب، وفي إقلاع التطبيق — فرمزٌ تالفٌ في التخزين كان يُسقط كلّ طلبٍ
/// شبكيّ أو يُعلّق شاشة الإقلاع. وصارت تُجيب ولا ترمي أبداً:
///
/// * رمزٌ معطوب ← `true`: لا يُوثق به، فيُسجَّل الخروج ويُعاد إلى الدخول.
/// * رمزٌ بلا `exp` ← `false`: الحقل اختياريّ في RFC 7519، وغيابه يعني أنّ
///   الرمز لا ينتهي.
///
/// ```dart
/// if (JwtDecoder.isExpired(refreshToken)) {
///   storageRepository.logout();
///   return;
/// }
/// ```
///
/// وما سواها يرمي `FormatException` وحدها — لا `Error` — فيكفيه `on Exception`.
abstract final class JwtDecoder {
  /// أبعدُ ثانيةٍ يحملها `DateTime` عن 1970 في الاتّجاهين: مئة مليون يوم.
  /// وما جاوزها يرمي `RangeError` — وهو `Error` — فيُعامَل الحقل معطوباً.
  static const int _maxEpochSeconds = 100000000 * Duration.secondsPerDay;

  /// حمولة [token] — الجزء الأوسط مفكوكاً — خريطةً.
  ///
  /// يرمي [FormatException] إن لم يكن الرمز ثلاثة أجزاء، أو لم تكن حمولته
  /// base64url لنصّ JSON يمثّل كائناً.
  static Map<String, dynamic> decode(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid token');
    }
    final Object? payload;
    try {
      payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } on FormatException {
      throw const FormatException('Invalid payload');
    }
    // حمولةٌ صحيحة الترميز لكنّها مصفوفةٌ أو نصّ ليست حمولة JWT.
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid payload');
    }
    return payload;
  }

  /// مثل [decode]، لكنّها تُرجع `null` بدل أن ترمي.
  static Map<String, dynamic>? tryDecode(String token) {
    try {
      return decode(token);
    } on FormatException {
      return null;
    }
  }

  /// هل انتهت صلاحية [token]؟ **لا ترمي أبداً.**
  ///
  /// `true` إن مضى `exp` أو كان الرمز معطوباً، و`false` إن لم يحمل `exp`.
  static bool isExpired(String token) {
    final Map<String, dynamic>? payload = tryDecode(token);
    if (payload == null) return true;

    final Object? exp = payload['exp'];
    if (exp == null) return false;

    final DateTime? expiration = _fromEpochSeconds(exp);
    if (expiration == null) return true;

    return DateTime.now().isAfter(expiration);
  }

  /// تاريخ انتهاء [token] من حقل `exp`، بالتوقيت المحلّيّ كما في الحزمة.
  ///
  /// يرمي [FormatException] إن كان الرمز معطوباً، أو غاب `exp`، أو لم يكن
  /// عدداً من الثواني.
  static DateTime getExpirationDate(String token) =>
      _requireDate(decode(token), 'exp');

  /// المدّة المتبقّية حتى انتهاء [token] — سالبةٌ إن كان قد انتهى.
  ///
  /// يرمي [FormatException] كما [getExpirationDate].
  static Duration getRemainingTime(String token) =>
      getExpirationDate(token).difference(DateTime.now());

  /// المدّة المنقضية منذ إصدار [token] (حقل `iat`).
  ///
  /// يرمي [FormatException] إن كان الرمز معطوباً، أو غاب `iat`، أو لم يكن
  /// عدداً من الثواني.
  static Duration getTokenTime(String token) =>
      DateTime.now().difference(_requireDate(decode(token), 'iat'));

  static DateTime _requireDate(Map<String, dynamic> payload, String claim) {
    final DateTime? date = _fromEpochSeconds(payload[claim]);
    if (date == null) {
      throw FormatException('Missing or invalid "$claim" claim');
    }
    return date;
  }

  /// قيمة NumericDate — ثوانٍ منذ 1970 UTC، وقد تكون كسريّة — تاريخاً محلّياً،
  /// أو `null` إن لم تكن عدداً منتهياً في مدى `DateTime`.
  ///
  /// `isFinite` قبل المدى لا بعده: `NaN` تُفشل كلّ مقارنة فتعبر حارسَ المدى،
  /// ثمّ يرمي `toInt()` عليها `UnsupportedError`.
  static DateTime? _fromEpochSeconds(Object? value) {
    if (value is! num || !value.isFinite || value.abs() > _maxEpochSeconds) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
  }
}
