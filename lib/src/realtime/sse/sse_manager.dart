import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'sse_registry.dart';

export 'sse_registry.dart';

enum SseConnectionState { connected, disconnected, none }

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

  CancelToken? _cancelToken;
  SseConnectionState _state = SseConnectionState.none;
  bool _shouldReconnect = false;
  bool _isConnecting = false;
  bool _isRefreshingToken = false;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  int _connectionGeneration = 0;

  static const int _maxRetryCount = 10;
  static const int _baseDelaySeconds = 5;
  static const int _maxDelaySeconds = 120;

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
    _cancelToken = CancelToken();
    final int generation = ++_connectionGeneration;

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

      final dio = Dio();
      final response = await dio.get<ResponseBody>(
        uri.toString(),
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          sendTimeout: null,
          receiveTimeout: null,
        ),
      );

      if (generation != _connectionGeneration) return;

      _state = SseConnectionState.connected;
      _retryCount = 0;
      _isConnecting = false;
      log('connected', name: 'sse: $url');

      final buffer = StringBuffer();

      response.data!.stream.listen(
        (chunk) {
          if (generation != _connectionGeneration) return;
          final text = utf8.decode(chunk);
          buffer.write(text);

          final raw = buffer.toString();
          final events = raw.split('\n\n');

          buffer
            ..clear()
            ..write(events.last);

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
              _messageCallback?.call(dataLines);
            }
          }
        },
        onError: (error) {
          if (generation != _connectionGeneration) return;
          if (error is DioException && CancelToken.isCancel(error)) return;
          if (!_shouldReconnect) return;
          log('onError', error: error, name: 'sse: $url');
          _state = SseConnectionState.disconnected;
          _errorCallback?.call(error);
          _scheduleReconnect();
        },
        onDone: () {
          if (generation != _connectionGeneration) return;
          if (!_shouldReconnect) return;
          log('onDone', name: 'sse: $url');
          _state = SseConnectionState.disconnected;
          _doneCallback?.call();
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
      _errorCallback?.call(e);
      _scheduleReconnect();
    } catch (e) {
      if (generation != _connectionGeneration) return;
      _isConnecting = false;
      log('catchError $e', error: e, name: 'sse: $url');
      _state = SseConnectionState.disconnected;
      _errorCallback?.call(e);
      _scheduleReconnect();
    }
  }

  Future<void> _handleUnauthorized() async {
    if (onUnauthorized == null) {
      disconnect();
      return;
    }
    if (_isRefreshingToken) {
      log('401 again after token refresh — disconnecting', name: 'sse: $url');
      disconnect();
      return;
    }
    _isRefreshingToken = true;
    log('401 unauthorized — calling onUnauthorized', name: 'sse: $url');
    final refreshed = await onUnauthorized!();
    if (refreshed && _shouldReconnect) {
      log('token refreshed — reconnecting', name: 'sse: $url');
      _retryCount = 0;
      await _doConnect();
    } else {
      log('onUnauthorized returned false — disconnecting', name: 'sse: $url');
      disconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _retryCount++;
    if (_retryCount > _maxRetryCount) {
      log('max retries reached ($_maxRetryCount), stopping', name: 'sse: $url');
      _state = SseConnectionState.disconnected;
      return;
    }

    final delay = (_baseDelaySeconds * (1 << (_retryCount - 1)))
        .clamp(0, _maxDelaySeconds);
    log('reconnecting in ${delay}s... (attempt $_retryCount/$_maxRetryCount)',
        name: 'sse: $url');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  void disconnect() {
    _shouldReconnect = false;
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _cancelToken?.cancel();
    _cancelToken = null;
    _state = SseConnectionState.disconnected;
    WidgetsBinding.instance.removeObserver(this);
    SseRegistry.instance.unregister(this);
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
      _cancelToken?.cancel();
      _cancelToken = null;
      _state = SseConnectionState.disconnected;
      _connectionGeneration++;
    } else if (state == AppLifecycleState.resumed &&
        _shouldReconnect &&
        _state == SseConnectionState.disconnected) {
      log('app resumed — reconnecting sse', name: 'sse: $url');
      _retryCount = 0;
      _doConnect();
    }
  }

  void onMessage(Function(String) callback) => _messageCallback = callback;
  void onError(Function(dynamic) callback) => _errorCallback = callback;
  void onDone(Function() callback) => _doneCallback = callback;

  SseConnectionState get state => _state;
  bool get isConnected => _state == SseConnectionState.connected;
}
