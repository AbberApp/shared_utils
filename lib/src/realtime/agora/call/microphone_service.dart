import 'dart:async';
import 'dart:developer';

/// Callback يُرسل حالة الكتم عبر WebSocket
typedef OnMuteStateChanged = void Function(bool isMuted);

/// دالة الكتم الفعلية — تستدعي Agora muteLocalAudioStream
typedef MuteAction = Future<void> Function(bool muted);

abstract class MicrophoneService {
  Stream<bool> get isMutedStream;
  bool get isMuted;

  Future<void> initialize();
  Future<void> mute();
  Future<void> unmute();
  Future<void> toggleMute();
  Future<void> setMute(bool muted);
  Future<void> dispose();

  /// يُعيّن callback يُشغَّل عند تغيّر الحالة (لإرسال mute/unmute عبر WebSocket)
  void setOnMuteStateChanged(OnMuteStateChanged? callback);

  /// يُعيّن الدالة التي تنفّذ الكتم الفعلي على Agora
  void setMuteAction(MuteAction? action);

  static MicrophoneService get instance => MicrophoneServiceImpl._instance;
}

class MicrophoneServiceImpl implements MicrophoneService {
  MicrophoneServiceImpl._();

  static final MicrophoneServiceImpl _instance = MicrophoneServiceImpl._();

  StreamController<bool>? _isMutedController;
  OnMuteStateChanged? _onMuteStateChanged;
  MuteAction? _muteAction;
  bool _isMuted = false;

  @override
  Stream<bool> get isMutedStream => _isMutedController?.stream ?? const Stream.empty();

  @override
  bool get isMuted => _isMuted;

  @override
  Future<void> initialize() async {
    if (_isMutedController == null || _isMutedController!.isClosed) {
      _isMutedController = StreamController<bool>.broadcast();
    }
    _isMuted = false;
    log('MicrophoneService initialized', name: 'Microphone');
  }

  @override
  Future<void> mute() async {
    try {
      await _muteAction?.call(true);
      _isMuted = true;
      _notifyListeners();
      log('Microphone muted', name: 'Microphone');
    } catch (e) {
      log('Error muting microphone: $e', name: 'Microphone');
    }
  }

  @override
  Future<void> unmute() async {
    try {
      await _muteAction?.call(false);
      _isMuted = false;
      _notifyListeners();
      log('Microphone unmuted', name: 'Microphone');
    } catch (e) {
      log('Error unmuting microphone: $e', name: 'Microphone');
    }
  }

  @override
  Future<void> toggleMute() async {
    if (_isMuted) {
      await unmute();
    } else {
      await mute();
    }
  }

  @override
  Future<void> setMute(bool muted) async {
    if (muted) {
      await mute();
    } else {
      await unmute();
    }
  }

  void _notifyListeners() {
    if (_isMutedController != null && !_isMutedController!.isClosed) {
      _isMutedController!.add(_isMuted);
    }
    _onMuteStateChanged?.call(_isMuted);
  }

  @override
  void setOnMuteStateChanged(OnMuteStateChanged? callback) {
    _onMuteStateChanged = callback;
  }

  @override
  void setMuteAction(MuteAction? action) {
    _muteAction = action;
  }

  @override
  Future<void> dispose() async {
    await _isMutedController?.close();
    _isMutedController = null;
    _onMuteStateChanged = null;
    _muteAction = null;
    _isMuted = false;
    log('MicrophoneService disposed', name: 'Microphone');
  }
}
