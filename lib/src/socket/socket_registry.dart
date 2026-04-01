import 'dart:developer';

import 'socket_manager.dart';

/// سجل مركزي لجميع اتصالات WebSocket النشطة.
/// يُستخدم لقطع جميع الاتصالات دفعةً واحدة عند تسجيل الخروج.
class SocketRegistry {
  SocketRegistry._();

  static final SocketRegistry instance = SocketRegistry._();

  final Set<SocketManager> _sockets = {};

  void register(SocketManager socket) {
    _sockets.add(socket);
    log('registered (total: ${_sockets.length})', name: 'SocketRegistry');
  }

  void unregister(SocketManager socket) {
    _sockets.remove(socket);
    log('unregistered (total: ${_sockets.length})', name: 'SocketRegistry');
  }

  void disconnectAll() {
    log('disconnecting all (${_sockets.length} sockets)', name: 'SocketRegistry');
    for (final socket in _sockets.toList()) {
      socket.disconnect();
    }
    _sockets.clear();
  }
}
