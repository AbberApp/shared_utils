import 'dart:async';
import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

abstract class AgoraLiveService {
  Stream<bool> get isMutedStream;
  bool get isMuted;

  Stream<bool> get isCameraOnStream;
  bool get isCameraOn;

  /// Emits the Agora UID of a remote user publishing video, or null when stopped.
  Stream<int?> get remoteVideoUidStream;
  int? get remoteVideoUid;

  /// Emits (uid, isMuted) when a remote user mutes/unmutes their audio.
  Stream<({int uid, bool isMuted})> get remoteAudioMuteStream;

  /// Called when the token is about to expire (30 seconds before expiration).
  /// The BLoC should fetch a new token and call [renewToken].
  void Function(String channel)? onTokenPrivilegeWillExpire;

  Future<void> initialize(String appId);
  Future<void> joinAsHost({required String token, required String channel, required int uid});
  Future<void> joinAsAudience({required String token, required String channel, required int uid});
  Future<void> promoteToSpeaker();
  Future<void> demoteToAudience();
  Future<void> renewToken(String token);
  Future<void> toggleMic();
  Future<void> toggleCamera();
  Future<void> muteRemoteAudio(int uid);
  Future<void> unmuteRemoteAudio(int uid);
  Widget buildLocalVideoView();
  Widget buildRemoteVideoView(int uid);
  Future<void> leave();
  Future<void> dispose();

  static AgoraLiveService get instance => AgoraLiveServiceImpl._instance;
}

/// الـ Service تُدير دورة حياتها بنفسها عبر [WidgetsBindingObserver].
/// تُسجّل نفسها تلقائياً في [initialize] وتُلغي التسجيل في [dispose].
class AgoraLiveServiceImpl with WidgetsBindingObserver implements AgoraLiveService {
  AgoraLiveServiceImpl._();

  static final AgoraLiveServiceImpl _instance = AgoraLiveServiceImpl._();

  RtcEngine? _engine;
  StreamController<bool>? _isMutedController;
  StreamController<bool>? _isCameraOnController;
  StreamController<int?>? _remoteVideoUidController;
  StreamController<({int uid, bool isMuted})>? _remoteAudioMuteController;
  bool _isMuted = false;
  bool _isCameraOn = false;
  bool _isHost = false;
  int? _remoteVideoUid;
  String? _channelId;

  void Function(int uid)? onUserJoined;
  void Function(int uid)? onUserOffline;
  void Function(String message)? onError;

  @override
  void Function(String channel)? onTokenPrivilegeWillExpire;

  @override
  Stream<bool> get isMutedStream => _isMutedController?.stream ?? const Stream.empty();

  @override
  bool get isMuted => _isMuted;

  @override
  Stream<bool> get isCameraOnStream => _isCameraOnController?.stream ?? const Stream.empty();

  @override
  bool get isCameraOn => _isCameraOn;

  @override
  Stream<int?> get remoteVideoUidStream =>
      _remoteVideoUidController?.stream ?? const Stream.empty();

  @override
  int? get remoteVideoUid => _remoteVideoUid;

  @override
  Stream<({int uid, bool isMuted})> get remoteAudioMuteStream =>
      _remoteAudioMuteController?.stream ?? const Stream.empty();

  // ─── WidgetsBindingObserver ───────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseForBackground();
      case AppLifecycleState.resumed:
        _resumeFromBackground();
      default:
        break;
    }
  }

  Future<void> _pauseForBackground() async {
    if (_engine == null) return;
    // نكتم الصوت قبل أن يُجمّده iOS لمنع قطع مفاجئ في جلسة Agora
    // ينطبق على الـ Host والمشارك المرفوع (viewer with mic) على حدٍّ سواء
    await _engine!.muteLocalAudioStream(true);
    log('AgoraLiveService paused for background', name: 'AgoraLiveService');
  }

  Future<void> _resumeFromBackground() async {
    if (_engine == null) return;
    // نُعيد تفعيل الـ audio engine ثم نُعيد حالة الكتم الأصلية بدقة
    await _engine!.enableAudio();
    await _engine!.muteLocalAudioStream(_isMuted);
    log('AgoraLiveService resumed from background — isMuted: $_isMuted', name: 'AgoraLiveService');
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  Future<void> initialize(String appId) async {
    // تحقق من وجود engine سابق وأطلقه أولاً لتجنب memory leak
    if (_engine != null) {
      await dispose();
    }

    if (_isMutedController == null || _isMutedController!.isClosed) {
      _isMutedController = StreamController<bool>.broadcast();
    }
    if (_isCameraOnController == null || _isCameraOnController!.isClosed) {
      _isCameraOnController = StreamController<bool>.broadcast();
    }
    if (_remoteVideoUidController == null || _remoteVideoUidController!.isClosed) {
      _remoteVideoUidController = StreamController<int?>.broadcast();
    }
    if (_remoteAudioMuteController == null || _remoteAudioMuteController!.isClosed) {
      _remoteAudioMuteController = StreamController<({int uid, bool isMuted})>.broadcast();
    }

    _isMuted = false;
    _isCameraOn = false;
    _isHost = false;
    _remoteVideoUid = null;

    // تسجيل الـ service كـ observer لدورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    // audioScenarioMeeting يوفر أفضل جودة صوت للبث المباشر مع تقليل الصدى
    await _engine!.setAudioScenario(AudioScenarioType.audioScenarioMeeting);
    await _engine!.enableAudio();
    await _engine!.disableVideo();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, uid, elapsed) {
          log('User joined: $uid', name: 'AgoraLiveService');
          onUserJoined?.call(uid);
        },
        onUserOffline: (connection, uid, reason) {
          log('User offline: $uid', name: 'AgoraLiveService');
          onUserOffline?.call(uid);
        },
        onError: (err, msg) {
          log('Agora error: $err - $msg', name: 'AgoraLiveService');
          onError?.call(msg);
        },
        onJoinChannelSuccess: (connection, elapsed) {
          log('Joined channel: ${connection.channelId}', name: 'AgoraLiveService');
        },
        onLeaveChannel: (connection, stats) {
          log('Left channel', name: 'AgoraLiveService');
        },
        onRemoteAudioStateChanged: (connection, remoteUid, state, reason, elapsed) {
          // نعتمد على السبب (reason) فقط لتحديد حالة الكتم — أدق من الحالة (state)
          final isMuted = reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted;
          final isUnmuted = reason == RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted;
          if (isMuted || isUnmuted) {
            log(
              isMuted ? 'Remote audio muted: $remoteUid' : 'Remote audio unmuted: $remoteUid',
              name: 'AgoraLiveService',
            );
            _remoteAudioMuteController?.add((uid: remoteUid, isMuted: isMuted));
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          if (state == RemoteVideoState.remoteVideoStateStopped) {
            if (_remoteVideoUid == remoteUid) {
              _remoteVideoUid = null;
              _remoteVideoUidController?.add(null);
              log('Remote video stopped: $remoteUid', name: 'AgoraLiveService');
            }
          } else if (state == RemoteVideoState.remoteVideoStateStarting ||
              state == RemoteVideoState.remoteVideoStateDecoding) {
            if (_remoteVideoUid != remoteUid) {
              _remoteVideoUid = remoteUid;
              _remoteVideoUidController?.add(remoteUid);
              log('Remote video started: $remoteUid', name: 'AgoraLiveService');
            }
          }
          // frozen: لا نغير _remoteVideoUid - البث مستمر لكن متجمد مؤقتاً
        },
        onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
          if (_remoteVideoUid != remoteUid) {
            _remoteVideoUid = remoteUid;
            _remoteVideoUidController?.add(remoteUid);
            log('First remote video frame: $remoteUid', name: 'AgoraLiveService');
          }
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          log(
            'Token privilege will expire — channel: ${connection.channelId}',
            name: 'AgoraLiveService',
          );
          onTokenPrivilegeWillExpire?.call(connection.channelId ?? '');
        },
      ),
    );

    log('AgoraLiveService initialized', name: 'AgoraLiveService');
  }

  @override
  Future<void> joinAsHost({
    required String token,
    required String channel,
    required int uid,
  }) async {
    _channelId = channel;
    _isHost = true;
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
      ),
    );
  }

  @override
  Future<void> joinAsAudience({
    required String token,
    required String channel,
    required int uid,
  }) async {
    _channelId = channel;
    _isHost = false;
    // تفعيل pipeline الفيديو لاستقبال بث المضيف مع كتم الكاميرا المحلية
    await _engine!.enableVideo();
    await _engine!.muteLocalVideoStream(true);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  @override
  Future<void> promoteToSpeaker() async {
    // المشارك المرفوع يحصل على الميكروفون فقط — الكاميرا ممنوعة منعاً باتاً
    _isHost = false;
    await _engine!.muteLocalVideoStream(true);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
      ),
    );
  }

  @override
  Future<void> demoteToAudience() async {
    // إيقاف الكاميرا صراحةً عند التخفيض حتى لو كانت شغّالة
    _isCameraOn = false;
    _isCameraOnController?.add(false);
    await _engine!.muteLocalVideoStream(true);
    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: false,
        publishCameraTrack: false,
      ),
    );
  }

  @override
  Future<void> renewToken(String token) async {
    await _engine?.renewToken(token);
    log('Token renewed', name: 'AgoraLiveService');
  }

  @override
  Future<void> toggleMic() async {
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    _isMutedController?.add(_isMuted);
    log(_isMuted ? 'Mic muted' : 'Mic unmuted', name: 'AgoraLiveService');
  }

  @override
  Future<void> toggleCamera() async {
    // الكاميرا حق حصري للمضيف — المشارك المرفوع لا يملك هذا الحق
    if (!_isHost) {
      log('toggleCamera ignored — caller is not the host', name: 'AgoraLiveService');
      return;
    }
    _isCameraOn = !_isCameraOn;
    if (_isCameraOn) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.stopPreview();
      await _engine!.disableVideo();
    }
    await _engine!.updateChannelMediaOptions(ChannelMediaOptions(publishCameraTrack: _isCameraOn));
    _isCameraOnController?.add(_isCameraOn);
    log(_isCameraOn ? 'Camera on' : 'Camera off', name: 'AgoraLiveService');
  }

  @override
  Widget buildLocalVideoView() {
    return AgoraVideoView(
      controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)),
    );
  }

  @override
  Widget buildRemoteVideoView(int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _channelId ?? ''),
      ),
    );
  }

  @override
  Future<void> muteRemoteAudio(int uid) async {
    await _engine?.muteRemoteAudioStream(uid: uid, mute: true);
    log('Remote audio muted: $uid', name: 'AgoraLiveService');
  }

  @override
  Future<void> unmuteRemoteAudio(int uid) async {
    await _engine?.muteRemoteAudioStream(uid: uid, mute: false);
    log('Remote audio unmuted: $uid', name: 'AgoraLiveService');
  }

  @override
  Future<void> leave() async {
    await _engine?.leaveChannel();
  }

  @override
  Future<void> dispose() async {
    // إلغاء تسجيل الـ observer أولاً لمنع أي أحداث lifecycle بعد بدء التنظيف
    WidgetsBinding.instance.removeObserver(this);

    // نضمن مغادرة الـ channel قبل تحرير الـ engine في جميع الأحوال
    await _engine?.leaveChannel();

    await _isMutedController?.close();
    _isMutedController = null;
    await _isCameraOnController?.close();
    _isCameraOnController = null;
    await _remoteVideoUidController?.close();
    _remoteVideoUidController = null;
    await _remoteAudioMuteController?.close();
    _remoteAudioMuteController = null;
    await _engine?.release();
    _engine = null;
    _isMuted = false;
    _isCameraOn = false;
    _isHost = false;
    _remoteVideoUid = null;
    _channelId = null;
    onTokenPrivilegeWillExpire = null;
    onUserJoined = null;
    onUserOffline = null;
    onError = null;
    log('AgoraLiveService disposed', name: 'AgoraLiveService');
  }
}
