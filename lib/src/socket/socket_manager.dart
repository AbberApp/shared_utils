import 'dart:async' show Future, Timer, unawaited;
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_registry.dart';

export 'socket_registry.dart';

enum SocketConnectionState { connected, disconnected, none }

class SocketManager with WidgetsBindingObserver {
  final String url;

  /// دالة تُستدعى عند كل اتصال لتوفير الـ headers — كل مشروع يمرر headers الخاصة به.
  final Map<String, dynamic> Function()? headersBuilder;

  Map<String, dynamic>? queryParameters;
  WebSocketChannel? _channel;

  SocketConnectionState _state = SocketConnectionState.none;

  bool _intentionalClose = false;
  bool _enableReconnect = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _baseDelaySeconds = 2;
  static const int _maxDelaySeconds = 120;
  Timer? _reconnectTimer;

  // يمنع تداخل callbacks من اتصال قديم مع اتصال جديد
  int _connectionGeneration = 0;

  Function(dynamic)? _messageCallback;
  Function(dynamic)? _errorCallback;
  Function(dynamic)? _doneCallback;
  Function()? _reconnectedCallback;

  SocketManager(
    this.url, {
    this.queryParameters,
    this.headersBuilder,
  });

  /// الاتصال العلني - يُعاد ضبط الحالة ويبدأ اتصال جديد.
  /// [enableReconnect]: إذا كان true يعيد الاتصال تلقائياً عند الانقطاع.
  Future<void> connect({bool enableReconnect = false}) async {
    _intentionalClose = false;
    _enableReconnect = enableReconnect;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    SocketRegistry.instance.register(this);
    await _connect();
  }

  Future<void> _connect({bool isReconnect = false}) async {
    if (_isConnecting) return;

    // أغلق أي اتصال سابق قبل فتح اتصال جديد
    _closeChannel();
    _isConnecting = true;

    // جيل الاتصال الحالي - يمنع callbacks قديمة من التأثير على الاتصال الجديد
    final int generation = ++_connectionGeneration;

    try {
      final headers = headersBuilder?.call() ?? {};

      final wsUrl = Uri.parse(url).replace(queryParameters: queryParameters);

      final channel = IOWebSocketChannel.connect(
        wsUrl,
        headers: headers,
        pingInterval: const Duration(seconds: 10),
      );

      // انتظر تأكيد الاتصال قبل تحديث الحالة
      await channel.ready;

      // تجاهل النتيجة إذا صدر اتصال أحدث في الأثناء
      if (generation != _connectionGeneration) {
        unawaited(channel.sink.close(3000));
        return;
      }

      _channel = channel;
      _state = SocketConnectionState.connected;
      _isConnecting = false;

      if (isReconnect) {
        _reconnectAttempts = 0;
        log('reconnected successfully', name: 'wss: $url');
        _reconnectedCallback?.call();
      } else {
        log('connected', name: 'wss: $url');
      }

      channel.stream.listen(
        (message) {
          if (generation != _connectionGeneration) return;
          log(message, name: 'wss: $url');
          _state = SocketConnectionState.connected;
          _messageCallback?.call(message);
        },
        onError: (error) {
          if (generation != _connectionGeneration) return;
          log('onError', error: error, name: 'wss $url');
          _closeChannel();
          if (!_intentionalClose && _enableReconnect) {
            _scheduleReconnect();
          } else {
            _errorCallback?.call(error);
          }
        },
        onDone: () {
          if (generation != _connectionGeneration) return;
          final int? code = channel.closeCode;
          log('onDone code=$code', name: 'wss $url');
          _closeChannel();
          final bool isNormalClose = code == 1000;
          if (!_intentionalClose && _enableReconnect && !isNormalClose) {
            _scheduleReconnect();
          } else {
            _doneCallback?.call('onDone');
          }
        },
      );
    } catch (e) {
      if (generation != _connectionGeneration) return;
      log('catchError for socket $e', error: e, name: 'wss $url');
      _closeChannel();
      _isConnecting = false;
      _state = SocketConnectionState.disconnected;

      if (!_intentionalClose && _enableReconnect) {
        _scheduleReconnect();
      } else {
        _errorCallback?.call(e);
        if (!isReconnect) rethrow;
      }
    }
  }

  void _closeChannel() {
    try {
      _channel?.sink.close(3000);
    } catch (_) {}
    _channel = null;
    _state = SocketConnectionState.disconnected;
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      log('max reconnect attempts reached', name: 'wss $url');
      _doneCallback?.call('onDone');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      seconds: (_baseDelaySeconds * (1 << (_reconnectAttempts - 1)))
          .clamp(0, _maxDelaySeconds),
    );
    log(
      'reconnecting attempt $_reconnectAttempts in ${delay.inSeconds}s',
      name: 'wss $url',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_intentionalClose) return;
      if (_state == SocketConnectionState.connected) {
        _reconnectAttempts = 0;
        return;
      }
      await _connect(isReconnect: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // التطبيق في الخلفية - أوقف محاولات إعادة الاتصال مؤقتاً
        _reconnectTimer?.cancel();

      case AppLifecycleState.resumed:
        // التطبيق عاد للمقدمة - استأنف إعادة الاتصال إذا كان منقطعاً
        if (!_intentionalClose &&
            _enableReconnect &&
            _state == SocketConnectionState.disconnected) {
          _scheduleReconnect();
        }

      case AppLifecycleState.detached:
        // التطبيق مُغلق نهائياً
        disconnect();

      default:
        break;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_state != SocketConnectionState.connected || _channel == null) {
      log('Cannot send message, socket is not connected', name: 'wss $url');
      return;
    }
    try {
      final encoded = jsonEncode(message);
      _channel!.sink.add(encoded);
      log('sent: $encoded', name: 'wss: $url');
    } catch (e) {
      log('Error sending message: $e', name: 'wss $url', error: e);
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _closeChannel();
    WidgetsBinding.instance.removeObserver(this);
    SocketRegistry.instance.unregister(this);
  }

  void onMessage(Function(dynamic) callback) => _messageCallback = callback;
  void onError(Function(dynamic) callback) => _errorCallback = callback;
  void onDone(Function(dynamic) callback) => _doneCallback = callback;

  /// يُستدعى عند نجاح إعادة الاتصال (لإرسال 'join' أو ما يعادله مجدداً).
  void onReconnected(Function() callback) => _reconnectedCallback = callback;

  SocketConnectionState get state => _state;
  bool get isConnected => _state == SocketConnectionState.connected;
}
