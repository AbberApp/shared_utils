import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// حالات الاتصال بالإنترنت
enum InternetConnectionState { waiting, disconnected, connected, none }

/// واجهة للتحقق من حالة الاتصال
abstract class ConnectionStatus {
  Future<bool> get isConnected;
  Future<bool> get isNotConnected;
  Stream<InternetConnectionState> get connectionStream;
  void dispose();
}

/// تنفيذ للتحقق من حالة الاتصال بالإنترنت
class InternetConnectionStatus implements ConnectionStatus {
  final Connectivity _connectivity;

  late StreamSubscription<List<ConnectivityResult>> _subscription;
  late StreamController<InternetConnectionState> _streamController;

  InternetConnectionStatus({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _streamController = StreamController<InternetConnectionState>.broadcast();
    _subscription = _connectivity.onConnectivityChanged.listen(_onStatusChanged);
  }

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _checkConnected(result);
  }

  @override
  Future<bool> get isNotConnected async => !(await isConnected);

  @override
  Stream<InternetConnectionState> get connectionStream => _streamController.stream;

  @override
  void dispose() {
    _subscription.cancel();
    _streamController.close();
  }

  void _onStatusChanged(List<ConnectivityResult> result) {
    final state = _checkConnected(result)
        ? InternetConnectionState.connected
        : InternetConnectionState.disconnected;
    _streamController.add(state);
  }

  bool _checkConnected(List<ConnectivityResult> result) {
    if (result.isEmpty) return false;
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet) ||
        result.contains(ConnectivityResult.vpn) ||
        result.contains(ConnectivityResult.bluetooth) ||
        result.contains(ConnectivityResult.other);
  }
}
