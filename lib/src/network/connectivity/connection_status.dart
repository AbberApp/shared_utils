import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';

/// حالات الاتصال بالإنترنت
///
/// - [waiting]: الحالة الأولية قبل اكتمال أول فحص للاتصال.
/// - [connected] / [disconnected]: نتيجة فحص فعلي لحالة الشبكة.
/// - [none]: تعذّر معرفة الحالة — فشل في قناة المنصّة لا انقطاع للشبكة.
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

  /// آخر حالة صدرت — يحتفظ بها لأن البثّ broadcast لا يحمل تاريخاً،
  /// فكل مشترك جديد كان يبقى بلا قيمة حتى أول تغيّر في الشبكة
  InternetConnectionState _last = InternetConnectionState.waiting;

  InternetConnectionStatus({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _streamController = StreamController<InternetConnectionState>.broadcast();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onStatusChanged,
      // خطأ قناة المنصّة ليس انقطاعاً للشبكة؛ ومن دون معالج يُعاد رميه في الـ zone
      // فيُسقط التطبيق، ومن دون cancelOnError: false يموت البثّ بعد أول خطأ
      onError: (Object e, StackTrace s) {
        log(
          'connectivity stream error',
          error: e,
          stackTrace: s,
          name: 'ConnectionStatus',
        );
        _emit(InternetConnectionState.none);
      },
      cancelOnError: false,
    );

    // فحص أولي عند الإقلاع: البثّ لا يُصدر شيئاً حتى تتغيّر الشبكة فعلياً،
    // فمن يفتح التطبيق وهو بلا إنترنت لا يصله أي حدث إطلاقاً
    unawaited(_emitInitialState());
  }

  @override
  Future<bool> get isConnected async {
    try {
      return _checkConnected(await _connectivity.checkConnectivity());
    } on Object catch (e, s) {
      // فشل استدعاء المنصّة (MissingPluginException بعد hot-restart، أو سحب
      // صلاحية الشبكة) ليس انقطاعاً؛ واعتباره كذلك يحجب كل طلبات كل DataSource
      // بلا سبب — نمرّر الطلب وندع طبقة Dio تُرجع الخطأ الحقيقي
      log(
        'checkConnectivity failed',
        error: e,
        stackTrace: s,
        name: 'ConnectionStatus',
      );
      return true;
    }
  }

  @override
  Future<bool> get isNotConnected async => !(await isConnected);

  /// بثّ حالة الاتصال — يُصدر الحالة الحالية فور الاشتراك ثم كل تغيّر بعدها
  @override
  Stream<InternetConnectionState> get connectionStream => _seededStream;

  /// بثّ يُعيد آخر حالة لكل مشترك جديد. مُخزَّن في حقل لا مُنشأ في الـ getter
  /// كي تبقى هوية الـ Stream ثابتة، فلا يُعيد StreamBuilder الاشتراك كل بناء
  late final Stream<InternetConnectionState> _seededStream =
      Stream<InternetConnectionState>.multi(_onSubscribe, isBroadcast: true);

  void _onSubscribe(MultiStreamController<InternetConnectionState> controller) {
    controller.add(_last);
    final subscription = _streamController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = () => subscription.cancel();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _streamController.close();
  }

  Future<void> _emitInitialState() async {
    InternetConnectionState state;
    try {
      state = _checkConnected(await _connectivity.checkConnectivity())
          ? InternetConnectionState.connected
          : InternetConnectionState.disconnected;
    } on Object catch (e, s) {
      log(
        'initial checkConnectivity failed',
        error: e,
        stackTrace: s,
        name: 'ConnectionStatus',
      );
      state = InternetConnectionState.none;
    }
    // وصل حدث حقيقي قبل نتيجة الفحص الأول؟ فهو الأحدث ولا يُداس عليه
    if (_last != InternetConnectionState.waiting) return;
    _emit(state);
  }

  void _onStatusChanged(List<ConnectivityResult> result) {
    _emit(
      _checkConnected(result)
          ? InternetConnectionState.connected
          : InternetConnectionState.disconnected,
    );
  }

  /// الفحص الأولي غير متزامن وقد يعود بعد dispose، فالحارس ضروري
  void _emit(InternetConnectionState state) {
    if (_streamController.isClosed) return;
    _last = state;
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
