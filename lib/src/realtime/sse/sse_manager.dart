import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'sse_registry.dart';

export 'sse_registry.dart';

enum SseConnectionState { connected, disconnected, none }

/// مدير اتصال SSE.
///
/// عند [connect] يسجّل المدير نفسه مراقباً في [WidgetsBinding] وفي
/// [SseRegistry]، وكلاهما مرجعٌ عالميّ قويّ لا يُزيله إلا [disconnect].
/// لذلك **يجب** على المستهلك استدعاء [disconnect] في `close()`/`dispose()`،
/// وإلّا بقي الكائن حيّاً إلى الأبد مع callbacks تحتجز الـ bloc بعد إغلاقه.
class SseManager with WidgetsBindingObserver {
  /// الرابط الكامل لاتصال SSE
  final String url;

  /// دالة تُستدعى عند كل محاولة اتصال لبناء الـ headers (Authorization وغيرها)
  final Map<String, dynamic> Function()? headersBuilder;

  /// دالة تُستدعى عند كل محاولة اتصال لبناء الـ query parameters
  final Map<String, dynamic> Function()? queryParametersBuilder;

  /// callback يُستدعى عند استقبال 401 — يعيد true إذا تم تجديد التوكن بنجاح
  /// (SseManager سيعيد الاتصال تلقائياً)، أو false إذا فشل (SseManager سيقطع)
  final Future<bool> Function()? onUnauthorized;

  /// نسخة Dio واحدة للمدير كلّه: إنشاء نسخةٍ لكلّ محاولة كان يخلّف عميل HTTP
  /// جديداً بلا إغلاق مع كلّ إعادة اتصال.
  final Dio _dio = Dio();

  CancelToken? _cancelToken;
  StreamSubscription<String>? _subscription;
  SseConnectionState _state = SseConnectionState.none;
  bool _shouldReconnect = false;
  bool _isConnecting = false;
  bool _isRefreshingToken = false;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  int _connectionGeneration = 0;

  int _refreshAttempts = 0;

  static const int _maxRetryCount = 10;
  static const int _baseDelaySeconds = 5;
  static const int _maxDelaySeconds = 120;

  /// سقف محاولات تجديد التوكن بين اتّصالين ناجحين. نجاح نداء التجديد وحده
  /// لا يكفي دليلاً على أنّ التوكن صار مقبولاً: خادمٌ يُصرّ على 401 رغم
  /// توكنٍ «مجدَّد» (حسابٌ موقوف، أو توكن بلا صلاحيةٍ على مسار SSE، أو ساعةٌ
  /// مزاحة) كان يدور بلا نهايةٍ ولا تأخير: 401 ← تجديد ← 401، فيقصف نقطة
  /// التجديد وخادم SSE معاً. ولذلك لا يُصفَّر العدّاد إلّا عند اتّصالٍ نجح فعلاً.
  static const int _maxRefreshAttempts = 2;

  /// سقف ما يُحتفظ به بانتظار فاصل الأحداث — حمايةً من نموٍّ بلا حدّ
  /// إن أرسل الخادم تدفّقاً مشوّهاً بلا فاصل.
  static const int _maxBufferLength = 1024 * 1024;

  Function(String)? _messageCallback;
  Function(dynamic)? _errorCallback;
  Function()? _doneCallback;

  SseManager(
    this.url, {
    this.headersBuilder,
    this.queryParametersBuilder,
    this.onUnauthorized,
  });

  Future<void> connect() async {
    _shouldReconnect = true;
    _retryCount = 0;
    _isRefreshingToken = false;
    _refreshAttempts = 0;
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    SseRegistry.instance.register(this);

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (!_shouldReconnect) return;
    if (_isConnecting) return;

    _isConnecting = true;
    final int generation = ++_connectionGeneration;

    // إغلاق أثر الاتصال السابق قبل فتح آخر: استبدال الـ CancelToken وإهمال
    // الاشتراك كانا يتركان سوكيتاً مفتوحاً يتراكم مع كلّ إعادة اتصال.
    _cancelToken?.cancel();
    _cancelSubscription();
    final token = CancelToken();
    _cancelToken = token;

    try {
      final params = queryParametersBuilder?.call().map(
            (k, v) => MapEntry(k, v.toString()),
          );

      final uri = Uri.parse(url).replace(queryParameters: params);

      final headers = {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...?headersBuilder?.call(),
      };

      final response = await _dio.get<ResponseBody>(
        uri.toString(),
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          sendTimeout: null,
          receiveTimeout: null,
        ),
      );

      if (generation != _connectionGeneration) {
        // اتصالٌ فات أوانه (تغيّر الجيل أثناء الانتظار): يُغلَق بدل تركه مفتوحاً
        token.cancel();
        return;
      }

      _state = SseConnectionState.connected;
      _retryCount = 0;
      // الموضع الوحيد الذي يُصفَّر فيه عدّاد التجديد: اتّصالٌ قبله الخادم فعلاً
      // هو وحده البرهان على أنّ التوكن صالح.
      _refreshAttempts = 0;
      _isConnecting = false;
      log('connected', name: 'sse: $url');

      final buffer = StringBuffer();

      // utf8.decoder مفكّكٌ ذو حالة: يجمع تتابع البايتات المقسّم بين chunkين
      // بدل أن يرمي FormatException — يحدث كثيراً مع الحروف العربية.
      _subscription = utf8.decoder.bind(response.data!.stream).listen(
        (text) {
          if (generation != _connectionGeneration) return;
          if (!_shouldReconnect) return;
          buffer.write(text);

          // مواصفة SSE تجيز فواصل CRLF، وبعض الوسطاء (proxy/Nginx) يرسلونها
          // كذلك؛ التقسيم على '\n\n' وحده كان لا يجد فاصلاً فلا يُسلَّم أيّ حدث
          // ويكبر الـ buffer بلا سقف.
          final raw = buffer.toString().replaceAll('\r\n', '\n');
          final events = raw.split('\n\n');

          final remainder = events.last;
          buffer.clear();
          if (remainder.length > _maxBufferLength) {
            log('buffer exceeded $_maxBufferLength chars — dropped',
                name: 'sse: $url');
          } else {
            buffer.write(remainder);
          }

          for (var i = 0; i < events.length - 1; i++) {
            final event = events[i].trim();
            if (event.isEmpty) continue;

            final lines = event.split('\n');
            final dataLines = lines
                .where((l) => l.startsWith('data:'))
                .map((l) => l.substring(5).trim())
                .join('\n');

            if (dataLines.isNotEmpty) {
              log(dataLines, name: 'sse: $url');
              _safeCall('message', () => _messageCallback?.call(dataLines));
            }
          }
        },
        onError: (error) {
          if (generation != _connectionGeneration) return;
          if (error is DioException && CancelToken.isCancel(error)) return;
          if (!_shouldReconnect) return;
          log('onError', error: error, name: 'sse: $url');
          _state = SseConnectionState.disconnected;
          _safeCall('error', () => _errorCallback?.call(error));
          _scheduleReconnect();
        },
        onDone: () {
          if (generation != _connectionGeneration) return;
          if (!_shouldReconnect) return;
          log('onDone', name: 'sse: $url');
          _state = SseConnectionState.disconnected;
          _safeCall('done', () => _doneCallback?.call());
          _scheduleReconnect();
        },
      );
    } on DioException catch (e) {
      if (generation != _connectionGeneration) return;
      _isConnecting = false;
      if (CancelToken.isCancel(e)) return;
      if (e.response?.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }
      log('catchError $e', error: e, name: 'sse: $url');
      _state = SseConnectionState.disconnected;
      _safeCall('error', () => _errorCallback?.call(e));
      _scheduleReconnect();
    } on Object catch (e) {
      if (generation != _connectionGeneration) return;
      _isConnecting = false;
      log('catchError $e', error: e, name: 'sse: $url');
      _state = SseConnectionState.disconnected;
      _safeCall('error', () => _errorCallback?.call(e));
      _scheduleReconnect();
    }
  }

  Future<void> _handleUnauthorized() async {
    if (onUnauthorized == null) {
      disconnect();
      return;
    }
    if (_isRefreshingToken) {
      // تجديدٌ جارٍ بالفعل من 401 سابق — لا يُطلق ثانٍ بالتوازي
      log('token refresh already in flight — disconnecting', name: 'sse: $url');
      disconnect();
      return;
    }
    if (_refreshAttempts >= _maxRefreshAttempts) {
      log('401 after $_maxRefreshAttempts token refreshes — disconnecting',
          name: 'sse: $url');
      disconnect();
      return;
    }
    _refreshAttempts++;
    _isRefreshingToken = true;
    log('401 unauthorized — calling onUnauthorized', name: 'sse: $url');
    bool refreshed = false;
    try {
      refreshed = await onUnauthorized!();
    } on Object catch (e, st) {
      // رفض onUnauthorized كان يهرب إلى الـ Zone ويُجمّد SSE نهائياً
      log('onUnauthorized threw', error: e, stackTrace: st, name: 'sse: $url');
    }
    if (refreshed && _shouldReconnect) {
      log('token refreshed — reconnecting', name: 'sse: $url');
      _retryCount = 0;
      // العلم يُصفَّر ليُسمح بتجديدٍ لاحق في الجلسة (وإلّا عُدّ أيّ 401 لاحق
      // «تجديداً جارياً» فقُطع الاتصال). وحارسُ الحلقة اللانهائية هو
      // _refreshAttempts أعلاه لا هذا العلم.
      _isRefreshingToken = false;
      await _doConnect();
    } else {
      log('onUnauthorized returned false — disconnecting', name: 'sse: $url');
      disconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    // زيادة الجيل هنا تُسقط النداء الثاني لنفس الانقطاع: التدفّق يُصدر onError
    // ثمّ onDone، فكان العدّاد يتضاعف ويقفز التأخير وتُستنفد المحاولات مبكراً.
    _connectionGeneration++;

    _retryCount++;
    if (_retryCount > _maxRetryCount) {
      log('max retries reached ($_maxRetryCount), stopping', name: 'sse: $url');
      _state = SseConnectionState.disconnected;
      // إعلام المستهلك عند استنفاد المحاولات: كان المدير يموت بصمت فتبقى
      // الواجهة تنتظر أحداثاً لا تأتي ولا تعرض زرّ إعادة محاولة.
      _safeCall(
        'error',
        () => _errorCallback?.call(
          StateError('sse: max retries reached ($_maxRetryCount)'),
        ),
      );
      return;
    }

    final delay = (_baseDelaySeconds * (1 << (_retryCount - 1)))
        .clamp(0, _maxDelaySeconds);
    log('reconnecting in ${delay}s... (attempt $_retryCount/$_maxRetryCount)',
        name: 'sse: $url');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), _connectGuarded);
  }

  void disconnect() {
    _shouldReconnect = false;
    _isConnecting = false;
    _reconnectTimer?.cancel();
    // زيادة الجيل قبل الإلغاء: اتصالٌ اكتمل فعلاً قبل تنفيذ الإلغاء كان يمرّ
    // من فحص الجيل فيضبط الحالة connected ويسلّم رسائل بعد تسجيل الخروج.
    _connectionGeneration++;
    _cancelToken?.cancel();
    _cancelToken = null;
    _cancelSubscription();
    _state = SseConnectionState.disconnected;
    WidgetsBinding.instance.removeObserver(this);
    SseRegistry.instance.unregister(this);
  }

  /// إلغاء اشتراك التدفّق بلا انتظار: انتظار إلغاءٍ متعلّق كان قد يُبقي
  /// `_isConnecting` مرفوعاً فيُجمّد كلّ محاولةٍ لاحقة.
  void _cancelSubscription() {
    final previous = _subscription;
    _subscription = null;
    if (previous == null) return;
    unawaited(previous.cancel().catchError((Object _) {}));
  }

  /// استدعاء محميّ لـ callbacks المستهلك: المكتبة مشتركة بين عدّة تطبيقات،
  /// واستثناءٌ في أحدها كان يهرب إلى الـ Zone بلا معالجة.
  void _safeCall(String label, void Function() body) {
    try {
      body();
    } on Object catch (e, st) {
      log('$label callback threw', error: e, stackTrace: st, name: 'sse: $url');
    }
  }

  /// _doConnect يُستدعى من سياقات void (Timer ودورة حياة التطبيق)، فأيّ
  /// استثناء يهرب منه كان يصير unhandled Future rejection.
  void _connectGuarded() {
    unawaited(
      _doConnect().catchError(
        (Object e, StackTrace st) =>
            log('connect failed', error: e, stackTrace: st, name: 'sse: $url'),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      log('app detached — stopping sse', name: 'sse: $url');
      disconnect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      log('app backgrounded — pausing sse', name: 'sse: $url');
      _reconnectTimer?.cancel();
      _isConnecting = false;
      _connectionGeneration++;
      _cancelToken?.cancel();
      _cancelToken = null;
      _cancelSubscription();
      _state = SseConnectionState.disconnected;
    } else if (state == AppLifecycleState.resumed &&
        _shouldReconnect &&
        _state == SseConnectionState.disconnected) {
      log('app resumed — reconnecting sse', name: 'sse: $url');
      _retryCount = 0;
      _connectGuarded();
    }
  }

  void onMessage(Function(String) callback) => _messageCallback = callback;
  void onError(Function(dynamic) callback) => _errorCallback = callback;
  void onDone(Function() callback) => _doneCallback = callback;

  SseConnectionState get state => _state;
  bool get isConnected => _state == SseConnectionState.connected;
}
