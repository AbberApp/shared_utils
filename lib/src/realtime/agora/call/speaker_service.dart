import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart';

/// دالة تحويل السماعة الفعلية — تستدعي Agora setEnableSpeakerphone
typedef SpeakerphoneAction = Future<void> Function(bool enabled);

enum SpeakerType { speaker, earpiece, bluetooth, headphones }

abstract class SpeakerService {
  Stream<SpeakerType> get speakerTypeStream;
  SpeakerType get currentType;

  Future<void> initialize();
  Future<void> changeSpeaker(SpeakerType type);
  Future<void> toggleSpeaker();
  Future<void> dispose();

  /// يُعيّن الدالة التي تنفّذ تحويل السماعة على Agora
  void setSpeakerphoneAction(SpeakerphoneAction? action);

  static SpeakerService get instance => SpeakerServiceImpl._instance;
}

class SpeakerServiceImpl implements SpeakerService {
  SpeakerServiceImpl._();

  static final SpeakerServiceImpl _instance = SpeakerServiceImpl._();

  AVAudioSession? _iosSession;
  StreamController<SpeakerType>? _speakerTypeController;
  SpeakerphoneAction? _speakerphoneAction;

  @override
  Stream<SpeakerType> get speakerTypeStream =>
      _speakerTypeController?.stream ?? const Stream.empty();

  SpeakerType _currentType = SpeakerType.earpiece;

  @override
  SpeakerType get currentType => _currentType;

  bool _isInitialized = false;
  StreamSubscription? _routeChangeSubscription;

  @override
  Future<void> initialize() async {
    if (_speakerTypeController == null || _speakerTypeController!.isClosed) {
      _speakerTypeController = StreamController<SpeakerType>.broadcast();
    }

    if (_isInitialized) return;

    try {
      if (Platform.isIOS) {
        _iosSession = AVAudioSession();
        _routeChangeSubscription = _iosSession!.routeChangeStream.listen(_onIOSRouteChange);
        await _detectCurrentDeviceIOS();
      } else if (Platform.isAndroid) {
        _currentType = SpeakerType.earpiece;
        _notifyListeners();
      }

      _isInitialized = true;
      log('SpeakerService initialized', name: 'Speaker');
    } catch (e) {
      log('Error initializing speaker service: $e', name: 'Speaker');
    }
  }

  void _onIOSRouteChange(AVAudioSessionRouteChange change) {
    log('iOS route change: ${change.reason}', name: 'Speaker');
    _detectCurrentDeviceIOS();
  }

  Future<void> _detectCurrentDeviceIOS() async {
    if (_iosSession == null) return;

    try {
      final route = await _iosSession!.currentRoute;
      final outputs = route.outputs;

      if (outputs.isNotEmpty) {
        final port = outputs.first;
        _currentType = _mapIOSPortToSpeakerType(port.portType);
        _notifyListeners();
        log('Current iOS speaker: ${port.portType} -> $_currentType', name: 'Speaker');
      }
    } catch (e) {
      log('Error detecting iOS device: $e', name: 'Speaker');
    }
  }

  SpeakerType _mapIOSPortToSpeakerType(AVAudioSessionPort portType) {
    switch (portType) {
      case AVAudioSessionPort.builtInSpeaker:
        return SpeakerType.speaker;
      case AVAudioSessionPort.builtInReceiver:
        return SpeakerType.earpiece;
      case AVAudioSessionPort.bluetoothA2dp:
      case AVAudioSessionPort.bluetoothHfp:
      case AVAudioSessionPort.bluetoothLe:
        return SpeakerType.bluetooth;
      case AVAudioSessionPort.headphones:
      case AVAudioSessionPort.headsetMic:
        return SpeakerType.headphones;
      default:
        return SpeakerType.earpiece;
    }
  }

  @override
  Future<void> changeSpeaker(SpeakerType type) async {
    if (!_isInitialized) await initialize();

    try {
      if (Platform.isIOS) {
        await _changeSpeakerIOS(type);
      } else if (Platform.isAndroid) {
        await _changeSpeakerAndroid(type);
      }

      _currentType = type;
      _notifyListeners();
      log('Speaker changed to: $type', name: 'Speaker');
    } catch (e) {
      log('Error changing speaker: $e', name: 'Speaker');
    }
  }

  Future<void> _changeSpeakerIOS(SpeakerType type) async {
    if (_iosSession == null) return;

    switch (type) {
      case SpeakerType.speaker:
        await _iosSession!.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker);
        await _speakerphoneAction?.call(true);
      case SpeakerType.earpiece:
      case SpeakerType.bluetooth:
      case SpeakerType.headphones:
        await _iosSession!.overrideOutputAudioPort(AVAudioSessionPortOverride.none);
        await _speakerphoneAction?.call(false);
    }
  }

  Future<void> _changeSpeakerAndroid(SpeakerType type) async {
    switch (type) {
      case SpeakerType.speaker:
        await _speakerphoneAction?.call(true);
      case SpeakerType.earpiece:
      case SpeakerType.bluetooth:
      case SpeakerType.headphones:
        await _speakerphoneAction?.call(false);
    }
  }

  @override
  Future<void> toggleSpeaker() async {
    if (_currentType == SpeakerType.speaker) {
      await changeSpeaker(SpeakerType.earpiece);
    } else {
      await changeSpeaker(SpeakerType.speaker);
    }
  }

  void _notifyListeners() {
    if (_speakerTypeController != null && !_speakerTypeController!.isClosed) {
      _speakerTypeController!.add(_currentType);
    }
  }

  @override
  void setSpeakerphoneAction(SpeakerphoneAction? action) {
    _speakerphoneAction = action;
  }

  @override
  Future<void> dispose() async {
    await _routeChangeSubscription?.cancel();
    _routeChangeSubscription = null;
    await _speakerTypeController?.close();
    _speakerTypeController = null;
    _isInitialized = false;
    _iosSession = null;
    _speakerphoneAction = null;
    _currentType = SpeakerType.earpiece;
    log('SpeakerService disposed', name: 'Speaker');
  }
}
