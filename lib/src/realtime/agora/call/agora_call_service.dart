import 'dart:async';
import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

/// خدمة Agora للمكالمات الصوتية ثنائية الاتجاه.
///
/// ## كود Native مرتبط بهذه الخدمة:
///
/// ### Android — `call/CallForegroundService.kt`
/// Foreground Service يُشغَّل عبر `MethodChannel('abber/call_foreground')`.
/// يضمن بقاء العملية حية في الخلفية ويعرض إشعار "مكالمة جارية".
/// يُسجَّل في `AndroidManifest.xml` بـ `foregroundServiceType="phoneCall"`.
/// يُستدعى من `MainActivity.kt` عبر channel `abber/call_foreground`.
///
/// ### iOS — `VoIPCallService/CallAudioSessionManager.swift`
/// يراقب `AVAudioSession` ويُعيد تفعيلها بعد انقطاعات خارجية
/// (مكالمة هاتفية واردة، Siri...) لضمان استمرار Agora.
/// يُستدعى عبر `MethodChannel('abber/audio_session')` المُعرَّف في `AppDelegate.swift`.
///
/// ### ملاحظة:
/// تشغيل وإيقاف الخدمة الأصلية يتم من `CallBloc._startNativeCallService()`
/// و`CallBloc._stopNativeCallService()`.
abstract class AgoraCallService {
  /// ينبعث عند كل تغيير في حالة كتم الميكروفون المحلي.
  Stream<bool> get isMutedStream;
  bool get isMuted;

  void onRemoteUserJoined(void Function(int uid) callback);
  void onRemoteUserOffline(void Function(int uid) callback);
  void onJoinSuccess(void Function(int uid) callback);
  void onConnectionError(void Function(String error) callback);

  /// تهيئة محرك Agora بدون الانضمام للقناة.
  /// يُستدعى مرة واحدة قبل [join].
  Future<void> initialize(String appId);

  /// الانضمام للقناة الصوتية بعد [initialize].
  Future<void> join({
    required String token,
    required String channelId,
    required int uid,
  });

  Future<void> muteLocalAudio({required bool muted});
  Future<void> setSpeakerphone({required bool enabled});
  Future<void> dispose();

  static AgoraCallService get instance => _AgoraCallServiceImpl._instance;
}

class _AgoraCallServiceImpl
    with WidgetsBindingObserver
    implements AgoraCallService {
  _AgoraCallServiceImpl._();

  static final _AgoraCallServiceImpl _instance = _AgoraCallServiceImpl._();

  RtcEngine? _engine;
  StreamController<bool>? _isMutedController;

  bool _isMuted = false;
  bool _speakerEnabled = false;

  void Function(int)? _onRemoteUserJoined;
  void Function(int)? _onRemoteUserOffline;
  void Function(int)? _onJoinSuccess;
  void Function(String)? _onConnectionError;

  // ─── AgoraCallService ─────────────────────────────────────────────────────

  @override
  Stream<bool> get isMutedStream =>
      _isMutedController?.stream ?? const Stream.empty();

  @override
  bool get isMuted => _isMuted;

  @override
  void onRemoteUserJoined(void Function(int uid) callback) {
    _onRemoteUserJoined = callback;
  }

  @override
  void onRemoteUserOffline(void Function(int uid) callback) {
    _onRemoteUserOffline = callback;
  }

  @override
  void onJoinSuccess(void Function(int uid) callback) {
    _onJoinSuccess = callback;
  }

  @override
  void onConnectionError(void Function(String error) callback) {
    _onConnectionError = callback;
  }

  // ─── WidgetsBindingObserver ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreAudioRoute();
    }
    // paused: لا نتدخل — Agora يستمر في الخلفية بفضل Foreground Service (Android)
    //         وـ UIBackgroundModes audio+voip (iOS)
  }

  /// يُعيد تطبيق إعداد السماعة بعد عودة التطبيق للمقدمة.
  /// يُحتاج لأن نظام iOS أحياناً يُعيد توجيه الصوت لسماعة الأذن عند الاستئناف.
  Future<void> _restoreAudioRoute() async {
    if (_engine == null) return;
    await _engine!.setEnableSpeakerphone(_speakerEnabled);
    log(
      'AgoraCallService resumed — restored speakerphone: $_speakerEnabled',
      name: 'AgoraCallService',
    );
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> initialize(String appId) async {
    if (_engine != null) await dispose();

    _isMutedController = StreamController<bool>.broadcast();
    _isMuted = false;
    _speakerEnabled = false;

    WidgetsBinding.instance.addObserver(this);

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          log(
            'Agora: joined channel=${connection.channelId} uid=${connection.localUid}',
            name: 'AgoraCallService',
          );
          _onJoinSuccess?.call(connection.localUid ?? 0);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          log('Agora: remote user joined uid=$remoteUid', name: 'AgoraCallService');
          _onRemoteUserJoined?.call(remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          log(
            'Agora: remote user offline uid=$remoteUid reason=$reason',
            name: 'AgoraCallService',
          );
          _onRemoteUserOffline?.call(remoteUid);
        },
        onError: (code, msg) {
          log('Agora: error code=$code msg=$msg', name: 'AgoraCallService');
          _onConnectionError?.call('agora_error_${code.index}');
        },
      ),
    );

    await _engine!.enableAudio();
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );
    await _engine!.setDefaultAudioRouteToSpeakerphone(false);

    log('AgoraCallService initialized', name: 'AgoraCallService');
  }

  @override
  Future<void> join({
    required String token,
    required String channelId,
    required int uid,
  }) async {
    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    log('AgoraCallService: joining channel=$channelId', name: 'AgoraCallService');
  }

  @override
  Future<void> muteLocalAudio({required bool muted}) async {
    await _engine?.muteLocalAudioStream(muted);
    _isMuted = muted;
    _isMutedController?.add(_isMuted);
    log('AgoraCallService: muteLocalAudio muted=$muted', name: 'AgoraCallService');
  }

  @override
  Future<void> setSpeakerphone({required bool enabled}) async {
    await _engine?.setEnableSpeakerphone(enabled);
    _speakerEnabled = enabled;
    log('AgoraCallService: setSpeakerphone enabled=$enabled', name: 'AgoraCallService');
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);

    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      log('AgoraCallService: error during dispose: $e', name: 'AgoraCallService');
    } finally {
      _engine = null;
      await _isMutedController?.close();
      _isMutedController = null;
      _isMuted = false;
      _speakerEnabled = false;
      _onRemoteUserJoined = null;
      _onRemoteUserOffline = null;
      _onJoinSuccess = null;
      _onConnectionError = null;
    }

    log('AgoraCallService disposed', name: 'AgoraCallService');
  }
}
