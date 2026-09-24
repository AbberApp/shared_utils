import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'api_consumer.dart';

class DioConsumer implements ApiConsumer {
  final Dio client;

  /// [clearInterceptors]: افتراضه `true` حفاظاً على السلوك القائم — يمسح كلّ
  /// معترِضات `client` قبل تركيب `appInterceptors`. مرِّر `false` إن كان
  /// التطبيق قد أضاف معترِضاته (Sentry، إعادة المحاولة، الكاش) قبل الحقن
  /// وأراد بقاءها حيّة.
  DioConsumer({
    required this.client,
    required Interceptor appInterceptors,
    required String baseUrl,
    required int internalServerErrorCode,
    bool clearInterceptors = true,
    bool allowBadCertificates = true,
  }) {
    // [allowBadCertificates]: افتراضه `true` حفاظاً على سلوك المشاريع القائمة — تُقبل كلّ
    // شهادة TLS بلا تحقّق، وهو قرارٌ قائمٌ بطلب مالك المكتبة. تمريرُ `false` يترك تحقّقَ
    // dart:io الافتراضيّ كما هو، فتُرفَض الشهادة المزوّرة أو المنتهية أو التي لاسمِ نطاقٍ
    // آخر — وهو ما يحفظ حمايةَ MITM لمشروعٍ يحمل رموزَ دخولٍ أو بياناتٍ خاصّة.
    // المحوِّل لا يُمَسّ إلّا عند `true`، فالتحويل إلى `IOHttpClientAdapter` (الذي يرمي على
    // الويب) لا يقع على من اختار التحقّق.
    if (allowBadCertificates) {
      (client.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final HttpClient client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }

    client.options
      ..baseUrl = baseUrl
      ..responseType = ResponseType.plain
      // نتّبع التحويلات: `validateStatus` يمرّر كلّ ما دون 500، فكان ردّ
      // 3xx يعود «استجابةً» لا معالِج لها في `handleResponse` فينتهي خطأً
      // مجهولاً (`Failure(code: 301)`)؛ ويعود التنزيل من رابطٍ موقَّت
      // (302 إلى CDN) بلا محتوى. الاتّباع التلقائيّ في dart:io مقصورٌ على
      // GET/HEAD فلا يُعاد إرسال أيّ جسم طلبٍ، وسقف 5 يمنع حلقات التحويل.
      ..followRedirects = true
      ..maxRedirects = 5
      ..validateStatus = (status) {
        return status! < internalServerErrorCode;
      };

    // المسح يمحو أيضاً ما سجّله التطبيق على النسخة قبل حقنها (Sentry،
    // إعادة المحاولة، الكاش). أُبقي عليه افتراضاً كي لا يتغيّر سلوك
    // المشاريع القائمة، وأُتيح تعطيله لمن يحتاج إبقاء معترِضاته.
    if (clearInterceptors) {
      client.interceptors.clear();
    } else {
      // بلا مسح: نُزيل نسخةً سابقة من المعترِض نفسه فقط، كي لا يُضاف مرّتين
      // إن أُعيد بناء `DioConsumer` فوق نسخة `Dio` ذاتها.
      client.interceptors.removeWhere(
        (Interceptor i) => i.runtimeType == appInterceptors.runtimeType,
      );
    }

    client.interceptors.add(appInterceptors);
    // الشرط الثاني لا أثر له بعد المسح (القائمة فارغة)، وإنّما يمنع تكرار
    // سجلّ الطلبات حين يُطلب إبقاء معترِضات التطبيق.
    if (kDebugMode &&
        !client.interceptors.any((Interceptor i) => i is LogInterceptor)) {
      client.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    // تعيين قيم timeout هنا
    // 15 ثانية للاتصال
    client.options.connectTimeout = const Duration(seconds: 15);
    // 30 ثانية لاستقبال البيانات
    client.options.receiveTimeout = const Duration(seconds: 30);
    // 30 ثانية لإرسال البيانات
    client.options.sendTimeout = const Duration(seconds: 30);
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    // ترويسة المصادقة شأن `appInterceptors` وحده — المكتبة لا تملك التوكن
    // ولا تملك تعطيله. لا تُعِد وسيطاً من جنس `useToken` هنا: كان مُعلَناً
    // بلا أثر، فمن كتب `useToken: false` ظنّ أنّه منع الترويسة والطلب
    // يُرسَل بالتوكن كما هو. من أراد طلباً بلا مصادقة فليبنِ ذلك في معترِضه.
    return await client.get(path, queryParameters: queryParameters);
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool formDataIsEnabled = false,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) async {
    return await client.post(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled
          ? FormData.fromMap(body ?? const <String, dynamic>{})
          : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool formDataIsEnabled = false,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) async {
    return await client.put(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled
          ? FormData.fromMap(body ?? const <String, dynamic>{})
          : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response<dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
    Duration? timeout,
  }) async {
    return await client.patch(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled
          ? FormData.fromMap(body ?? const <String, dynamic>{})
          : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response> download(
    String url, {
    Function(int, int)? onReceiveProgress,
    Duration receiveTimeout = const Duration(minutes: 5),
  }) async {
    // لا نلفّ الخطأ في `Exception` عامّ: ذلك يمحو نوع `DioException` فيسقط
    // في فرع الخطأ المجهول عند `ErrorHandler`، ويضيع تمييز انقطاع الاتصال
    // عن انتهاء المهلة عن 404. ندعه يصعد كما في بقيّة الدوال.
    final options = Options(
      responseType: ResponseType.bytes,
      receiveTimeout: receiveTimeout,
    );

    return await client.get(
      url,
      options: options,
      onReceiveProgress: onReceiveProgress,
    );
  }

  @override
  Future<Response<dynamic>> upload(
    String path, {
    required Map<String, dynamic> body,
    Map<String, dynamic>? queryParameters,
    Function(int, int)? onSendProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    return await client.post(
      path,
      queryParameters: queryParameters,
      data: FormData.fromMap(body),
      onSendProgress: onSendProgress,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await client.delete(
      path,
      queryParameters: queryParameters,
      data: body,
    );
  }
}
