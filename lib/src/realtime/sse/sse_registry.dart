import 'dart:developer';

import 'sse_manager.dart';

/// سجل مركزي لجميع اتصالات SSE النشطة.
/// يُستخدم لقطع جميع الاتصالات دفعةً واحدة عند تسجيل الخروج.
class SseRegistry {
  SseRegistry._();

  static final SseRegistry instance = SseRegistry._();

  final Set<SseManager> _connections = {};

  void register(SseManager sse) {
    _connections.add(sse);
    log('registered (total: ${_connections.length})', name: 'SseRegistry');
  }

  void unregister(SseManager sse) {
    _connections.remove(sse);
    log('unregistered (total: ${_connections.length})', name: 'SseRegistry');
  }

  void disconnectAll() {
    log('disconnecting all (${_connections.length} connections)',
        name: 'SseRegistry');
    for (final sse in _connections.toList()) {
      sse.disconnect();
    }
    _connections.clear();
  }
}
