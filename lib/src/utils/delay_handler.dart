import 'dart:async';
import 'dart:ui';

/// معالج التأخير (Debounce)
/// يُستخدم لتأخير تنفيذ الدوال المتكررة
class DelayHandler {
  Timer? _timer;
  final int defaultDelayMs;

  /// راية التخلّص: [dispose] إنهاءٌ للكائن لا مجرّد إلغاءٍ للمؤقّت.
  bool _disposed = false;

  DelayHandler({this.defaultDelayMs = 800});

  /// تنفيذ الدالة بعد تأخير
  /// إذا تم استدعاء run مرة أخرى قبل انتهاء التأخير، يتم إلغاء المؤقت السابق
  ///
  /// بعد [dispose] لا يجدول شيئاً ويعود بهدوء: الاستدعاء المتأخّر يأتي غالباً
  /// من مستمعٍ (ScrollController أو TextField) لم يُفكَّ بعد إغلاق الشاشة،
  /// فجدولةُ إجراءٍ حينها تُطلقه على State/Bloc مُتخلَّصٍ منه.
  void run(VoidCallback action, {int? delayMs}) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: delayMs ?? defaultDelayMs),
      action,
    );
  }

  /// إلغاء المؤقت وتنظيف الموارد — نهائيّ، فلا [run] بعده
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
