import 'dart:async';
import 'dart:ui';

/// معالج التأخير (Debounce)
/// يُستخدم لتأخير تنفيذ الدوال المتكررة
class DelayHandler {
  Timer? _timer;
  final int defaultDelayMs;

  DelayHandler({this.defaultDelayMs = 800});

  /// تنفيذ الدالة بعد تأخير
  /// إذا تم استدعاء run مرة أخرى قبل انتهاء التأخير، يتم إلغاء المؤقت السابق
  void run(VoidCallback action, {int? delayMs}) {
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: delayMs ?? defaultDelayMs),
      action,
    );
  }

  /// إلغاء المؤقت وتنظيف الموارد
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
