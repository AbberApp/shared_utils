import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

/// رمز دولة المستخدم من عنوان اتّصاله — لاختيار الدولة الافتراضية في حقل الهاتف.
///
/// بديلٌ محلّيّ لحزمة `ip_country_lookup` 1.1.0: أربعمئة وثلاثة وخمسون سطراً لم
/// تستعمل التطبيقات منها إلّا رمز الدولة، في `custom_phone_field.dart`:
///
/// ```dart
/// final data = await IpCountryLookup().getIpLocationData();
/// final countryCode = data.countryCode?.toUpperCase();
/// if (countryCode != null && mounted && ...) { ... }
/// ```
///
/// **الأسماء مطابقةٌ للحزمة** — `IpCountryLookup()` و[getIpLocationData]
/// و[IpCountryData.countryCode] ومعه `country_code` المهجور — فلا يُمسّ سطرٌ في
/// التطبيقات. وما لم يُستعمل سقط: `getUserIpAddress`، وسائر حقول النتيجة (الاسم
/// والعنوان ومزوّد الخدمة ورمز الاستجابة)، وتحويلاتها إلى JSON.
///
/// **والفارق مقصود: الفشل `null` لا `'N/A'`.** كانت الحزمة تُرجع عند تعذّر البحث
/// — بلا إنترنت، أو تأخّرت الخدمات — رمزاً هو النصّ `'N/A'`. فيراه التطبيق مختلفاً
/// عن دولة المستخدم ويمرّره إلى `IntlPhoneUtils.getCountryByCode`، وهذه لا تعرفه
/// فتُرجع السعودية، ثمّ يحفظها التطبيق: فيجد مستخدمٌ إماراتيّ حقلَ هاتفه سعودياً،
/// ويبقى كذلك. والآن الرمز حرفان لاتينيّان أو `null`، والتطبيقات تتحقّق من `null`.
///
/// والخدمات هي خدمات الحزمة نفسها، فلا يرى عنوانَ المستخدم طرفٌ خارجيّ جديد. تُجرَّب
/// بالترتيب، وكلٌّ تُجرَّب إن فشلت سابقتها:
///
/// 1. `ipwho.is` — طلبٌ واحد، إذ تعرف عنوان المتّصل بنفسها. وكانت الحزمة تسأل
///    خدمةً أخرى عن العنوان أوّلاً، فتجري طلبين دائماً.
/// 2. `ipapi.co` — محجوبةٌ خلف تحقّق Cloudflare من بعض الشبكات، وفشلها سريع.
/// 3. `ipify` للعنوان، ثمّ `iplocation.net` بالعنوان.
///
/// والطلبات بعميل `Dio` مستقلّ بلا معترِضات، فلا يصل رمزُ دخول التطبيق ولا ترويساته
/// إلى خدمةٍ خارجية. ولكلّ طلبٍ خمس ثوانٍ، ولا تخزين — كلاهما كما في الحزمة.
class IpCountryLookup {
  /// النسخة المشتركة، كما في الحزمة.
  factory IpCountryLookup() => _shared;

  /// بمُرسِلٍ بديل يتلقّى العنوان ويُرجع جسم الردّ — نصّاً أو خريطة — ويرمي
  /// [DioException] حين يمثّل فشل الشبكة.
  @visibleForTesting
  IpCountryLookup.withRequest(this._request);

  static final IpCountryLookup _shared = IpCountryLookup.withRequest(_dioGet);

  final Future<Object?> Function(Uri uri) _request;

  static const Duration _timeout = Duration(seconds: 5);

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      responseType: ResponseType.plain,
    ),
  );

  static final Uri _ipWhoIs = Uri.https('ipwho.is', '/');
  static final Uri _ipApi = Uri.https('ipapi.co', '/json/');
  static final Uri _ipify = Uri.https('api64.ipify.org', '/', <String, String>{
    'format': 'json',
  });
  static Uri _ipLocation(String ip) =>
      Uri.https('api.iplocation.net', '/', <String, String>{'ip': ip});

  /// رمز ISO للدولة: حرفان لاتينيّان، لا `N/A` ولا رمزٌ من ثلاثة.
  static final RegExp _isoCode = RegExp(r'^[A-Za-z]{2}$');

  /// دولة الاتّصال الحاليّ. **لا ترمي أبداً**: إن فشلت الخدمات كلّها فالنتيجة
  /// [IpCountryData.countryCode] بقيمة `null`.
  Future<IpCountryData> getIpLocationData() async {
    final String? code =
        await _attempt(() async {
          final Map<String, Object?>? body = await _getJson(_ipWhoIs);
          // تردّ بـ200 حتى حين تفشل، و`success: false` هو علامة الفشل.
          return body?['success'] == true ? body!['country_code'] : null;
        }) ??
        await _attempt(() async => (await _getJson(_ipApi))?['country_code']) ??
        await _attempt(() async {
          final Object? ip = (await _getJson(_ipify))?['ip'];
          if (ip is! String || ip.isEmpty) return null;
          return (await _getJson(_ipLocation(ip)))?['country_code2'];
        });
    return IpCountryData(countryCode: code);
  }

  /// رمزٌ صالح من [lookup] بحروفٍ كبيرة، أو `null` إن فشلت الشبكة أو لم يكن
  /// الردّ JSON أو لم يكن الرمز صالحاً.
  ///
  /// الالتقاط على النوعين المتوقّعين وحدهما: كلّ خللٍ في الشبكة يصل [DioException]،
  /// وكلّ ردٍّ ليس JSON — كصفحة Cloudflare — يصل [FormatException]. وما سواهما
  /// عطبٌ في هذا الملفّ يجب أن يظهر.
  static Future<String?> _attempt(Future<Object?> Function() lookup) async {
    try {
      final Object? code = await lookup();
      return code is String && _isoCode.hasMatch(code) ? code.toUpperCase() : null;
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// الردّ خريطةً، أو `null` إن كان JSON صالحاً من شكلٍ آخر.
  Future<Map<String, Object?>?> _getJson(Uri uri) async {
    final Object? body = await _request(uri);
    final Object? decoded = body is String ? jsonDecode(body) : body;
    return decoded is Map<String, Object?> ? decoded : null;
  }

  static Future<Object?> _dioGet(Uri uri) async =>
      (await _dio.getUri<String>(uri)).data;
}

/// نتيجة [IpCountryLookup.getIpLocationData]: رمز الدولة وحده — ما تقرؤه التطبيقات.
@immutable
class IpCountryData {
  const IpCountryData({this.countryCode});

  /// رمز ISO بحرفين كبيرين (`SA`)، أو `null` إن تعذّر البحث.
  final String? countryCode;

  /// اسم الحزمة القديم، مهجورٌ فيها أيضاً. ما زالت ثلاثة تطبيقات تقرؤه.
  @Deprecated('Use countryCode instead.')
  // ignore: non_constant_identifier_names
  String? get country_code => countryCode;
}
